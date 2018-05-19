# SlicedIO slices a large File into a small portion.
class SlicedIO
  def initialize(io, from, to, &block)
    @io = io
    @from = from
    @to = to
    @block = block
    @current = 0
  end

  def rewind
    io.seek(from)
    @current = 0
  end

  def size
    @size ||= @to - @from + 1
  end

  def read(len)
    return nil if @current >= size
    len = [len, @to - @current + 1].min
    # Notify before we read
    @block.call(@current, size)
    failed_count = 0
    begin
      @io.read(len)
    rescue Errno::EIO
      @io.seek(@current)
      failed_count += 1
      retry unless failed_count > 5
      raise
    end
  ensure
    @current += len
  end
end
