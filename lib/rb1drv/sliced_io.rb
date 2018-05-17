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
    @io.read(len)
  ensure
    @current += len
  end
end
