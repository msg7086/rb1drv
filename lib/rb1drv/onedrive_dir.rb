require 'rb1drv/sliced_io'

module Rb1drv
  class OneDriveDir < OneDriveItem
    attr_reader :child_count
    def initialize(od, api_hash)
      super
      @child_count = api_hash.dig('folder', 'childCount')
    end

    # Lists contents of current directory.
    #
    # @return [Array<OneDriveDir,OneDriveFile>] directories and files whose parent is current directory
    def children
      return [] if child_count <= 0
      @od.request("drive/items/#{@id}/children")['value'].map do |child|
        OneDriveItem.smart_new(@od, child)
      end
    end

    # Get an object by an arbitary path related to current directory.
    #
    # To get an absolute path, make use of OneDrive#get and not this.
    #
    # @param path [String] path relative to current directory
    #
    # @return [OneDriveDir,OneDriveFile] the drive item you asked
    def get(path)
      path = "/#{path}" unless path[0] == '/'
      OneDriveItem.smart_new(@od, @od.request("drive/items/#{@id}:#{path}"))
    end

    # Yes
    def dir?
      true
    end

    # No
    def file?
      false
    end

    # @return [String] absolute path of current item
    def absolute_path
      if @parent_path
        File.join(@parent_path, @name)
      else
        '/'
      end
    end

    # Recursively creates empty directories.
    #
    # @param name [String] directories you'd like to create
    # @return [OneDriveDir] the directory you created
    def mkdir(name)
      newdir, *remainder = name.split('/')
      subdir = @od.request("drive/items/#{@id}:/#{newdir}") rescue nil
      unless subdir
        subdir = @od.request("drive/items/#{@id}/children",
          name: newdir,
          folder: {},
          '@microsoft.graph.conflictBehavior': 'rename'
        )
      end
      subdir = OneDriveDir.new(@od, subdir)
      remainder.any? ? subdir.mkdir(remainder.join('/')) : subdir
    end

    # Uploads a local file into current remote directory using large file uploading mode.
    #
    # Unfinished download is stored as +target_name.incomplete+ and renamed upon completion.
    #
    # @param filename [String] local filename you'd like to upload
    # @param overwrite [Boolean] whether to overwrite remote file, or rename this
    # @param fragment_size [Integer] fragment size for each upload session, recommended to be multiple of 320KiB
    # @param chunk_size [Integer] IO size for each disk read request and progress notification
    # @param target_name [String] desired remote filename, a relative path to current directory
    #
    # @yield [event, status] for receive progress notification
    # @yieldparam event [Symbol] event of this notification
    # @yieldparam status [{Symbol => String,Integer}] details
    def upload(filename, overwrite: false, fragment_size: 41_943_040, chunk_size: 1_048_576, target_name: nil, &block)
      raise ArgumentError.new('File not found') unless File.exist?(filename)
      file_size = File.size(filename)
      resume_file = "#{filename}.1drv_upload"
      resume_session = JSON.parse(File.read(resume_file)) rescue nil if File.exist?(resume_file)

      if resume_session && resume_session['session_url']
        conn = Excon.new(resume_session['session_url'])
        result = JSON.parse(conn.get.body)
        resume_position = result.dig('nextExpectedRanges', 0)&.split('-')&.first&.to_i or resume_session = nil
      end

      resume_position ||= 0

      if resume_session
        file_size == resume_session['source_size'] or resume_session = nil
      end

      unless resume_session
        target_name ||= File.basename(filename)
        result = @od.request("drive/items/#{@id}:/#{target_name}:/createUploadSession", item: {'@microsoft.graph.conflictBehavior': overwrite ? 'replace' : 'rename'})
        resume_session = {
          'session_url' => result['uploadUrl'],
          'source_size' => File.size(filename),
          'fragment_size' => fragment_size
        }
        File.write(resume_file, JSON.pretty_generate(resume_session))
      end

      new_file = nil
      File.open(filename, mode: 'rb', external_encoding: Encoding::BINARY) do |f|
        resume_position.step(file_size, resume_session['fragment_size']) do |from|
          to = [from + resume_session['fragment_size'], file_size].min - 1
          len = to - from + 1
          headers = {
            'Content-Length': len.to_s,
            'Content-Range': "bytes #{from}-#{to}/#{file_size}"
          }
          @od.logger.info "Uploading #{from}-#{to}/#{file_size}"
          yield :new_segment, file: filename, from: from, to: to if block_given?
          sliced_io = SlicedIO.new(f, from, to) do |progress, total|
            yield :progress, file: filename, from: from, to: to, progress: progress, total: total if block_given?
          end
          result = conn.put headers: headers, chunk_size: chunk_size, body: sliced_io
          yield :finish_segment, file: filename, from: from, to: to if block_given?
          result = JSON.parse(result.body)
          new_file = OneDriveFile.new(@od, result) if result.dig('file')
        end
        File.unlink(resume_file)
      end
      new_file
    end
  end
end
