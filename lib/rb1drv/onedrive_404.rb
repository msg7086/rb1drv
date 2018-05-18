module Rb1drv
  class OneDrive404 < OneDriveItem
    def initialize(*_)
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
