module Rb1drv
  class OneDriveFile < OneDriveItem
    attr_reader :download_url
    def initialize(od, api_hash)
      super
      @download_url = api_hash.dig('@microsoft.graph.downloadUrl')
    end

    # No
    def dir?
      false
    end

    # Yes
    def file?
      true
    end

    # Saves current remote file as local file.
    #
    # Unfinished download is stored as +target_name.incomplete+ and renamed upon completion.
    #
    # @param target_name [String] desired local filename, a relative path to current directory or an absolute path
    # @param overwrite [Boolean] whether to overwrite local file, or skip this
    # @param resume [Boolean] whether to resume an unfinished download, or start over anyway
    #
    # @yield [event, status] for receive progress notification
    # @yieldparam event [Symbol] event of this notification
    # @yieldparam status [{Symbol => String,Integer}] details
    def save_as(target_name=nil, overwrite: false, resume: true, &block)
      target_name ||= @name
      tmpfile = "#{target_name}.incomplete"

      return if !overwrite && File.exist?(target_name)

      if resume && File.size(tmpfile) > 0
        from = File.size(tmpfile)
        len = @size - from
        fmode = 'ab'
        headers = {
          'Range': "bytes=#{from}-"
        }
      else
        from = 0
        len = @size
        fmode = 'wb'
        headers = {}
      end

      yield :new_segment, file: target_name, from: from if block_given?
      File.open(tmpfile, mode: fmode, external_encoding: Encoding::BINARY) do |f|
        Excon.get download_url, headers: headers, response_block: ->(chunk, remaining_bytes, total_bytes) do
          f.write(chunk)
          yield :progress, file: target_name, from: from, progress: total_bytes - remaining_bytes, total: total_bytes if block_given?
        end
      end
      yield :finish_segment, file: target_name if block_given?
      FileUtils.mv(tmpfile, filename)
    end

    # Change last modified time for a remote file.
    #
    # NOTICE: OneDrive by default keeps multiple history version for this operation.
    # NOTICE: You must turn off versioning to prevent multiple counts on disk quota.
    #
    # 3 attempts will be made due to delay after a file upload.
    #
    # @param time [Time] desired last modified time
    # @return [OneDriveFile] new file object returned by API
    def set_mtime(time)
      attempt = 0
      begin
        OneDriveFile.new(@od, @od.request(api_path, {fileSystemInfo: {lastModifiedDateTime: time.utc.iso8601}}, :patch))
      rescue
        sleep 10
        attempt += 1
        retry if attempt <= 3
      end
    end
  end
end
