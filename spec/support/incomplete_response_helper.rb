# frozen_string_literal: true

class StringChunksWrapper
  def initialize(string, chunk_size = 1024)
    @string = string
    @chunk_size = chunk_size
  end

  def each_chunk
    return enum_for(:each_chunk) unless block_given?

    start_index = 0
    while start_index < @string.length
      yield @string.byteslice(start_index, @chunk_size)
      start_index += @chunk_size
    end
  end
end
