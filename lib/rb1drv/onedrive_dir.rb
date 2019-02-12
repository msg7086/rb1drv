require 'time'
require 'rb1drv/sliced_io'

module Rb1drv
  class OneDriveDir < OneDriveItem
    attr_reader :child_count
    def initialize(od, api_hash)
      super
      @child_count = api_hash.dig('folder', 'childCount')
      @cache = {}
    end

    # Lists contents of current directory.
    #
    # @return [Array<OneDriveDir,OneDriveFile>] directories and files whose parent is current directory
    def children
      return [] if child_count <= 0
      with_cache(:children) do
        @od.request("#{api_path}/children?$top=1000")['value'].map do |child|
          OneDriveItem.smart_new(@od, child)
        end
      end
    end

    # Get a child object by name inside current directory.
    #
    # @param path [String] name of a child
    #
    # @return [OneDriveDir,OneDriveFile,OneDrive404] the drive item you asked
    def get_child(path)
      children.find { |child| child.name == path } || OneDrive404.new
    end

    # Get an object by an arbitary path related to current directory.
    #
    # To get an absolute path, make use of OneDrive#get and not this.
    #
    # @param path [String] path relative to current directory
    #
    # @return [OneDriveDir,OneDriveFile,OneDrive404] the drive item you asked
    def get(path)
      path = "/#{path}" unless path[0] == '/'
      with_cache(:get, path) do
        OneDriveItem.smart_new(@od, @od.request("#{api_path}:#{path}"))
      end
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
      return self if name == '.'
      name = name[1..-1] if name[0] == '/'
      newdir, *remainder = name.split('/')
      subdir = get(newdir)
      unless subdir.dir?
        result = @od.request("#{api_path}/children",
          name: newdir,
          folder: {},
          '@microsoft.graph.conflictBehavior': 'rename'
        )
        subdir = OneDriveDir.new(@od, result)
      end
      remainder.any? ? subdir.mkdir(remainder.join('/')) : subdir
    end

    # Uploads a local file into current remote directory.
    # For files no larger than 4000KiB, uses simple upload mode.
    # For larger files, uses large file upload mode.
    #
    # Unfinished download is stored as +target_name.incomplete+ and renamed upon completion.
    #
    # @param filename [String] local filename you'd like to upload
    # @param overwrite [Boolean] whether to overwrite remote file, or not
    #   If false:
    #   For larger files, it renames the uploaded file
    #   For small files, it skips the file
    #   Always check existence beforehand if you need consistant behavior
    # @param fragment_size [Integer] fragment size for each upload session, recommended to be multiple of 320KiB
    # @param chunk_size [Integer] IO size for each disk read request and progress notification
    # @param target_name [String] desired remote filename, a relative path to current directory
    # @return [OneDriveFile,nil] uploaded file
    #
    # @yield [event, status] for receive progress notification
    # @yieldparam event [Symbol] event of this notification
    # @yieldparam status [{Symbol => String,Integer}] details
    def upload(filename, overwrite: false, fragment_size: 41_943_040, chunk_size: 1_048_576, target_name: nil, &block)
      raise ArgumentError.new('File not found') unless File.exist?(filename)
      conn = nil
      file_size = File.size(filename)
      target_name ||= File.basename(filename)
      return upload_simple(filename, overwrite: overwrite, target_name: target_name) if file_size <= 4_096_000

      resume_file = "#{filename}.1drv_upload"
      resume_session = JSON.parse(File.read(resume_file)) rescue nil if File.exist?(resume_file)
      old_file = OneDriveItem.smart_new(@od, @od.request("#{api_path}:/#{target_name}"))
      new_file = nil

      result = nil
      loop do
        catch :restart do
          if resume_session && resume_session['session_url']
            conn = Excon.new(resume_session['session_url'], idempotent: true)
            loop do
              result = JSON.parse(conn.get.body)
              break unless result.dig('error', 'code') == 'accessDenied'
              sleep 5
            end
            resume_position = result.dig('nextExpectedRanges', 0)&.split('-')&.first&.to_i or resume_session = nil
          end

          resume_position ||= 0

          if resume_session
            file_size == resume_session['source_size'] or resume_session = nil
          end

          until resume_session && resume_session['session_url'] do
            result = @od.request("#{api_path}:/#{target_name}:/createUploadSession", item: {'@microsoft.graph.conflictBehavior': overwrite ? 'replace' : 'rename'})
            if result['uploadUrl']
              resume_session = {
                'session_url' => result['uploadUrl'],
                'source_size' => File.size(filename),
                'fragment_size' => fragment_size
              }
              File.write(resume_file, JSON.pretty_generate(resume_session))
              conn = Excon.new(resume_session['session_url'], idempotent: true)
              break
            end
            sleep 15
          end

          new_file = nil
          File.open(filename, mode: 'rb', external_encoding: Encoding::BINARY) do |f|
            resume_position.step(file_size - 1, resume_session['fragment_size']) do |from|
              to = [from + resume_session['fragment_size'], file_size].min - 1
              len = to - from + 1
              headers = {
                'Content-Length': len.to_s,
                'Content-Range': "bytes #{from}-#{to}/#{file_size}"
              }
              @od.logger.info "Uploading #{from}-#{to}/#{file_size}" if @od.logger
              yield :new_segment, file: filename, from: from, to: to if block_given?
              sliced_io = SlicedIO.new(f, from, to) do |progress, total|
                yield :progress, file: filename, from: from, to: to, progress: progress, total: total if block_given?
              end
              begin
                result = conn.put headers: headers, chunk_size: chunk_size, body: sliced_io, retry_limit: 2
                raise IOError if result.body.include? 'accessDenied'
              rescue Excon::Error::Socket, IOError
                # Probably server rejected this request
                throw :restart
              rescue Excon::Error::Timeout
                conn = Excon.new(resume_session['session_url'], idempotent: true)
                yield :retry, file: filename, from: from, to: to if block_given?
                retry
              ensure
                yield :finish_segment, file: filename, from: from, to: to if block_given?
              end
              throw :restart if result.body.include?('</html>')
              result = JSON.parse(result.body)
              new_file = OneDriveFile.new(@od, result) if result.dig('file')
            end
          end
          throw :restart unless new_file&.file?
          break
        end
        # catch :restart here
        6.times do
          new_file = OneDriveItem.smart_new(@od, @od.request("#{api_path}:/#{target_name}"))
          break if new_file.file? && new_file.id != old_file.id
          sleep 10 # wait for server to process the previous request
        end
        break if new_file.file? && new_file.id != old_file.id
        # and retry the whole process
      end

      # upload completed
      File.unlink(resume_file)
      return new_file.set_mtime(File.mtime(filename))
    end

    # Uploads a local file into current remote directory using simple upload mode.
    #
    # @return [OneDriveFile,nil] uploaded file
    def upload_simple(filename, overwrite:, target_name:)
      target_file = get(target_name)
      exist = target_file.file?
      return if exist && !overwrite
      path = nil
      if exist
        path = "#{target_file.api_path}/content"
      else
        path = "#{api_path}:/#{target_name}:/content"
      end

      query = {
        path: File.join('v1.0/me/', path),
        headers: {
          'Authorization': "Bearer #{@od.access_token.token}",
          'Content-Type': 'application/octet-stream'
        },
        body: File.read(filename)
      }
      result = @od.conn.put(query)
      result = JSON.parse(result.body)
      file = OneDriveFile.new(@od, result)
      file.set_mtime(File.mtime(filename))
    end

    def skip_cache?
      @skip_cache || false
    end

    def skip_cache=(val)
      @skip_cache = val
    end

    # Clears cache for directory
    def clear_cache!
      @cache = {}
    end

    private

    def with_cache(*keys)
      if skip_cache? || @od.skip_cache?
        yield
      elsif !@cache[keys]
        @cache[keys] = yield
      else
        @cache[keys]
      end
    end

  end
end
