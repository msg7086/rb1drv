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
    # @return [OneDriveDir,OneDriveFile] the drive item you asked
    def get(path)
      path = "/#{path}" unless path[0] == '/'
      OneDriveItem.smart_new(self, request("drive/root:#{path}"))
    end
  end
end
