module LZW

  MAGIC      = "\037\235".b
  MASK_BITS  = 0x1f
  MASK_BLOCK = 0x80
  RESET_CODE = 256

  def self.big_endian
    [1].pack("I") == [1].pack("N")
  end

  class Simple
    def compress ( data )
      LZW::Compressor.new.compress( data )
    end

    def decompress ( data )
      LZW::Decompressor.new.decompress( data )
    rescue
      nil
    end
  end
  
  class Compressor
    attr_reader :block_mode, :big_endian, :max_code_size, :init_code_size

    def initialize (
      block_mode:     true,
      big_endian:     nil,
      init_code_size: 9,
      max_code_size:  16
    )
      @block_mode     = block_mode
      @init_code_size = init_code_size
      @max_code_size  = max_code_size
      
      if big_endian.nil?
        @big_endian = LZW::big_endian
      end

      if init_code_size > max_code_size 
        raise "init_code_size must be less than or equal to max_code_size"
      end

      if max_code_size > 16
        raise "max_code_size must be 16 or less"
      end

      if init_code_size < 9
        raise "init_code_size must be greater than 8"
      end

      @buf     = magic
      @buf_pos = @buf.size * 8
    end

    def compress( data )
      reset

      @buf << data
    end

    private

    def reset
      @code_table = {}
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
    def decompress ( data )
      
    end
  end


  class BitBuf
    include Enumerable

    # Derived from Gene Hsu's work at
    # https://github.com/genehsu/bitarray/blob/master/lib/bitarray/string.rb
    # but it wasn't worth inheriting from an unaccepted pull to a gem that's
    # unmaintained.

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
      big_endian: LZW::big_endian
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
        throw "Only 0 and 1 are valid for a bit field"
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

    private

    def byte_divmod ( pos )
      byte, bit = pos.divmod(8)

      if byte > @field.bytesize - 1
        # puts "grow to byte #{byte}"
        @field << "\000"
      end

      [ byte, big_endian ? (7 - bit) : bit ]
    end

  end
end


