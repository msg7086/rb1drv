module Rb1drv
  class OneDrive404 < OneDriveItem
    def initialize(*_)
    end

    def id
      '_FILE_NOT_FOUND_'
    end

    # No
    def dir?
      false
    end

    # No
    def file?
      false
    end
  end
end
