module Rb1drv
  class OneDriveItem
    attr_reader :id, :name, :eTag, :size, :mtime, :ctime, :muser, :cuser, :parent_path
    protected
    def initialize(od, api_hash)
      @od = od
      %w(id name eTag size).each do |key|
        instance_variable_set("@#{key}", api_hash[key])
      end
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

    # @return [Boolean] whether it's shared by others
    def remote?
      @remote
    end
  end
end
