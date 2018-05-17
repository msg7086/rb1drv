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
    end

    # Create subclass instance by checking the item type
    #
    # @return [OneDriveFile, OneDriveDir] instanciated drive item
    def self.smart_new(od, item_hash)
      item_hash['file'] ? OneDriveFile.new(od, item_hash) : OneDriveDir.new(od, item_hash)
    end

    # @return [String] absolute path of current item
    def absolute_path
      if @parent_path
        File.join(@parent_path, @name)
      else
        @name
      end
    end
  end
end
