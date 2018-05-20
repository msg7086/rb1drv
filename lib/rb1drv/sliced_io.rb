# SlicedIO slices a large File into a small portion.
class SlicedIO
  def initialize(io, from, to, &block)
    @io = io
    @from = from
    @to = to
    @block = block
    rewind
  end

  def rewind
    @io.seek(@from)
    @current = 0
  end

  def size
    @size ||= @to - @from + 1
  end

  def read(len)
    return nil if @current >= size
    len = [len, size - @current].min
    # Notify before we read
    @block.call(@current, size)
    failed_count = 0
    begin
      @io.read(len)
    rescue Errno::EIO
      @io.seek(@from + @current)
      sleep 1
      failed_count += 1
      retry unless failed_count > 5
      raise
    end
  ensure
    @current += len
  end
end
