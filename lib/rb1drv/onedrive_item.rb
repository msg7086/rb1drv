module Rb1drv
  class OneDriveItem
    attr_reader :id, :name, :eTag, :size, :mtime, :ctime, :muser, :cuser, :parent_path, :remote_id, :remote_drive_id
    protected
    def initialize(od, api_hash)
      # always raise Errors::ApiError here because if request failed
      # initializer will fail with another non-descriptive error.
      raise Errors::ApiError, api_hash if api_hash['error']

      @od = od
      %w(id name eTag size).each do |key|
        instance_variable_set("@#{key}", api_hash[key])
      end
      @remote_drive_id = api_hash.dig('remoteItem', 'parentReference', 'driveId')
      @remote_id = api_hash.dig('remoteItem', 'id')
      @mtime = Time.iso8601(api_hash.dig('lastModifiedDateTime'))
      @ctime = Time.iso8601(api_hash.dig('createdDateTime'))
      @muser = api_hash.dig('lastModifiedBy', 'user', 'displayName') || 'N/A'
      @cuser = api_hash.dig('createdBy', 'user', 'displayName') || 'N/A'
      @parent_path = api_hash.dig('parentReference', 'path')
      @remote = api_hash.has_key?('remoteItem')
    end

    # Create subclass instance by checking the item type
    #
    # @return [OneDriveFile, OneDriveDir] instanciated drive item
    def self.smart_new(od, item_hash)
      if item_hash['remoteItem']
        item_hash['remoteItem'].each do |key, value|
          item_hash[key] ||= value
        end
      end
      if item_hash['file']
        OneDriveFile.new(od, item_hash)
      elsif item_hash['folder']
        OneDriveDir.new(od, item_hash)
      elsif item_hash.dig('error', 'code') == 'itemNotFound'
        OneDrive404.new
      elsif item_hash['error'] && Rb1drv.raise_on_failed_request
        # optional fail here to determine situation when
        # request was failed but not because item not found
        raise Errors::ApiError, item_hash
      else
        item_hash
      end
    end

    # @return [String] absolute path of current item
    def absolute_path
      if @parent_path
        File.join(@parent_path, @name)
      else
        @name
      end
    end

    # TODO: API endpoint does not play well with remote files
    #
    # @return [String] api reference path of current object
    def api_path
      if remote?
        "drives/#{@remote_drive_id}/items/#{@remote_id}"
      else
        "drive/items/#{@id}"
      end
    end

    # TODO: API endpoint does not play well with remote files
    #
    # @return [Boolean] whether it's shared by others
    def remote?
      @remote
    end
  end
end
