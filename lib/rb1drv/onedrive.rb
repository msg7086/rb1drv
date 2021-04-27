module Rb1drv
  class OneDrive
    # Get root directory object.
    #
    # @return [OneDriveDir] your root
    def root
      @_root_dir ||= OneDriveDir.new(self, request('drive/root'))
    end

    # Get an object by an arbitary path.
    #
    # TODO: API endpoint does not play well with remote files
    #
    # @return [OneDriveDir,OneDriveFile] the drive item you asked
    def get(path)
      path = "/#{path}" unless path[0] == '/'
      OneDriveItem.smart_new(self, request("drive/root:/#{url_path_encode(path[1..-1])}"))
    end

    def skip_cache?
      @skip_cache || false
    end

    def skip_cache=(val)
      @skip_cache = val
    end
  end
end
