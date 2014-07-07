module LZW

  MAGIC      = "\037\235".b
  MASK_BITS  = 0x1f
  MASK_BLOCK = 0x80
  RESET_CODE = 256

  # Detect if we're on a big-endian arch
  def self.big_endian?
    [1].pack("I") == [1].pack("N")
  end


  # Simplest-use LZW compressor and decompressor
  class Simple

    # Compress input with defaults
    #
    # @param data [#each_byte] data to be compressed
    #
    # @return [String] LZW compressed data
    def compress ( data )
      LZW::Compressor.new.compress( data )
    end

    # Decompress input with defaults
    #
    # @param data [String] compressed data to be decompressed
    #
    # @return [String] decompressed data
    #
    # @raise [RuntimeException] if there is an error in the compressed stream
    def decompress ( data )
      LZW::Decompressor.new.decompress( data )
    end
  end
  
  class Compressor
    attr_reader :block_mode, :big_endian, :max_code_size, :init_code_size

    def initialize (
      block_mode:     true,
      big_endian:     LZW::big_endian?,
      init_code_size: 9,
      max_code_size:  16
    )
      if init_code_size > max_code_size 
        raise "init_code_size must be less than or equal to max_code_size"
      end

      if max_code_size > 16
        raise "max_code_size must be 16 or less"
      end

      if init_code_size < 9
        raise "init_code_size must be greater than 8"
      end

      @big_endian     = big_endian
      @block_mode     = block_mode
      @init_code_size = init_code_size
      @max_code_size  = max_code_size

    end

    def compress( data )
      reset

      seen = ''
      data.each_byte do |byte|
        char = byte.chr

        if @code_table.has_key?( seen + char )
          seen << char
        else
          @buf.set_varint( @buf_pos, @code_size, @code_table[seen] )
          @buf_pos += @code_size

          @code_table[seen + char] = @next_code
          @next_code += 1

          if @next_code >= ( 2 ** @code_size )
            if @code_size < @max_code_size
              @code_size += 1
            # elsif @block_mode
              # reset_code_table
              # set_varint reset_code
            end
          end

          seen = char
        end
      end

      @buf.set_varint( @buf_pos, @code_size, @code_table[seen] )

      @buf.field
    end

    def reset
      @buf     = LZW::BitBuf.new( field: magic )
      @buf_pos = @buf.field.bytesize * 8

      code_reset
    end

    private

    def code_reset
      @code_table = {}
      ( 0 .. 255 ).each do |i|
        @code_table[i.chr] = i
      end

      @code_size  = @init_code_size
      @next_code  = 257
    end

    def magic
      MAGIC + (
        ( @max_code_size & MASK_BITS ) |
        ( @block_mode ? MASK_BLOCK : 0 )
      ).chr
    end

  end


  class Decompressor
    attr_reader :big_endian, :init_code_size

    def initialize (
      big_endian:     LZW::big_endian?,
      init_code_size: 9
    )
      @big_endian     = big_endian
      @init_code_size = init_code_size
    end

    def decompress ( data )
      reset

      read_magic( data[0,3] )
      @data_pos = 3

      # puts self.inspect
      @buf
    end

    def reset
      @max_code_size = 16
      @buf           = ''

      code_reset
    end

    private

    def code_reset
      @code_table = []
      ( 0 .. 255 ).each do |i|
        @code_table[i] = i.chr
      end

      @code_size  = @init_code_size
      @next_code  = 257
    end

    def read_magic ( magic )
      if magic.bytesize != 3 or magic[0,2] != MAGIC
        raise "Invalid compress(1) header"
      end

      bits = magic.getbyte(2)
      @max_code_size = bits & MASK_BITS
      @block_mode    = ( bits & MASK_BLOCK ) >> 7
      @block_mode    = @block_mode == 1 ? true : false

      if @init_code_size > @max_code_size
        raise "Can't decompress stream with init_code_size #{@init_code_size}"
          +"as it's greater than the stream's max_code_size #{@max_code_size}."
      end

    end
  end


  class BitBuf
    include Enumerable

    # Derived from Gene Hsu's work at
    # https://github.com/genehsu/bitarray/blob/master/lib/bitarray/string.rb
    # but it wasn't worth inheriting from an unaccepted pull to a gem that's
    # unmaintained.  Mostly, masking out is way smarter than vec() which is
    # what I'm doing in perl right now.

    # Compared to bitarray:
    # I'm forcing this to default-0 for bits, making a fixed size
    # unnecessary, and supporting both endians.  And changing the
    # interface, so I shouldn't subclass anyway.

    AND_BITMASK = %w[
      01111111
      10111111
      11011111
      11101111
      11110111
      11111011
      11111101
      11111110
    ].map{|w| [w].pack("b8").getbyte(0) }.freeze

    OR_BITMASK = %w[
      10000000
      01000000
      00100000
      00010000
      00001000
      00000100
      00000010
      00000001
    ].map{|w| [w].pack("b8").getbyte(0) }.freeze

    attr_reader :big_endian, :field

    def initialize (
      field:      "\000",
      big_endian: LZW::big_endian?
    )

      @field      = field.b
      @big_endian = big_endian
    end

    def []= ( pos, val )
      byte, bit = byte_divmod(pos)

      # puts "be:#{@big_endian} p:#{pos} B:#{byte} b:#{bit} = #{val}  (#{self[pos]})"

      case val
      when 0
        @field.setbyte( byte,
                       @field.getbyte(byte) & AND_BITMASK[bit] )
      when 1
        @field.setbyte( byte,
                       @field.getbyte(byte) | OR_BITMASK[bit] )
      else
        raise "Only 0 and 1 are valid for a bit field"
      end
    end

    def [] ( pos )
      byte, bit = byte_divmod(pos)

      (@field.getbyte(byte) >> bit ) & 1
    end

    def each ( &block )
      ( @field.bytesize * 8 ).times do |pos|
        yield self[pos]
      end
    end

    def to_s
      @field.unpack('b*').first
    end

    def set_varint ( pos, width = 8, val )
      ( 0 .. width ).each do |bit_offset|
        self[pos + (big_endian ? (width - bit_offset) : bit_offset)] =
          (val >> bit_offset) & 1
      end
      self
    end

    private

    def byte_divmod ( pos )
      byte, bit = pos.divmod(8)

      if byte > @field.bytesize - 1
        # puts "grow to byte #{byte}"
        @field << "\000"
      end

      [ byte, bit ]
    end

  end
end


