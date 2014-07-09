# Scaling LZW, like Unix compress(1)
#
# The LZW module offers:
# [{LZW::Simple}]       Straightforward compress/decompress calls in one place
# [{LZW::Compressor}]   LZW compressor with more fine-grained controls
# [{LZW::Decompressor}] LZW decompressor in the same vein
# [{LZW::BitBuf}]       An abstraction for modifying a String bitwise and 
#                       with unsigned integers at arbitrary offsets and sizes.
#
# {include:file:README.md}
#
# @see https://github.com/merrilymeredith/rb-compress-lzw
# @see https://en.wikipedia.org/wiki/Lempel–Ziv–Welch
module LZW

  VERSION    = '0.0.1'

  MAGIC      = "\037\235".b
  MASK_BITS  = 0x1f
  MASK_BLOCK = 0x80
  RESET_CODE = 256
  private_constant :MAGIC, :MASK_BITS, :MASK_BLOCK, :RESET_CODE

  # Detect if we're on a big-endian arch
  def self.big_endian?
    [1].pack("I") == [1].pack("N")
  end


  # Simplest-use LZW compressor and decompressor
  class Simple

    # Compress input with defaults
    #
    # @param data [#each_byte] data to be compressed
    # @return [String] LZW compressed data
    def compress ( data )
      LZW::Compressor.new.compress( data )
    end

    # Decompress input with defaults
    #
    # @param data [String] compressed data to be decompressed
    # @return [String] decompressed data
    # @raise [RuntimeException] if there is an error in the compressed stream
    def decompress ( data )
      LZW::Decompressor.new.decompress( data )
    end
  end
  
  # Scaling LZW data compressor with some configurables
  class Compressor

    # (NYI) If true, enables compression in block mode. Default true.
    #
    # After reaching {#max_code_size} bits per code, the compression dictionary
    # and code size may be reset if a drop in compression ratio is observed.
    # @return [Boolean]
    attr_reader :block_mode

    # If true, codes are written in big-endian order. Default
    # detected by LZW::big_endian?.
    #
    # Because codes in this format don't align to byte boundaries, the usual
    # tools for flipping bit order don't work.  You'll just find yourself with
    # a corrupt stream.  Forcing this option should help you work with streams
    # for/from other architectures.
    # @return [Boolean]
    attr_reader :big_endian

    # The maximum code size, in bits, that compression may scale up to.
    # Default 16.
    #
    # Valid values are init_code_size to 24.  Values greater than 16 break
    # compatibility with compress(1).
    # @return [Fixnum]
    attr_reader :max_code_size

    # The initial code size, in bits, used for compression. Default 9.
    #
    # Valid values are 9 to max_code_size.  Anything other than the default
    # breaks compatibility with compress(1) and requires the same attribute
    # to be set on the decompressor.
    # @return [Fixnum]
    attr_reader :init_code_size

    # LZW::Compressors work fine with the default settings.
    # 
    # @param block_mode [Boolean] (see {#block_mode})
    # @param big_endian [Boolean] (see {#big_endian})
    # @param init_code_size [Fixnum] (see {#init_code_size})
    # @param max_code_size [Fixnum] (see {#max_code_size})
    def initialize (
      block_mode:     true,
      big_endian:     LZW::big_endian?,
      init_code_size: 9,
      max_code_size:  16
    )
      if init_code_size > max_code_size 
        raise "init_code_size must be less than or equal to max_code_size"
      end

      if max_code_size > 24
        raise "max_code_size must be 24 or less"
      end

      if init_code_size < 9
        raise "init_code_size must be greater than 8"
      end

      @big_endian     = big_endian
      @block_mode     = block_mode
      @init_code_size = init_code_size
      @max_code_size  = max_code_size

    end

    # Given a String(ish) of data, return the LZW-compressed result as another
    # String.
    #
    # @param data [#each_byte<#chr>] Input data
    # @return [String]
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

    # Reset compressor state.  This is run at the beginning of {#compress},
    # so it's not necessary for repeated compression, but this allows wiping
    # the last code table and buffer from the object instance.
    def reset
      @buf     = LZW::BitBuf.new( big_endian: @big_endian )
      @buf_pos = 0
      
      # Here we make sure even the first actual bytes are in @big_endian order
      # so cross-arch compression should be possible.
      magic().each_byte do |b|
        @buf.set_varint( @buf_pos, 8, b.ord )
        @buf_pos += 8 
      end

      code_reset
    end

    private

    # Re-initialize the code table, code size and next code.
    # This happens at the beginning of compression and whenever
    # RESET_CODE is added to the stream (block mode).
    def code_reset
      @code_table = {}
      ( 0 .. 255 ).each do |i|
        @code_table[i.chr] = i
      end

      @code_size  = @init_code_size
      @next_code  = 257
    end

    # Prepare the header magic bytes for this stream.
    # @return [String]
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

      data = LZW::BitBuf.new( big_endian: @big_endian, field: data )

      read_magic( data )
      @data_pos = 24

      seen = data.get_varint( @data_pos, 9 )
      @data_pos += 9

      @buf << @str_table[ seen ]

      while code = data.get_varint( @data_pos, @code_size )
        @data_pos += @code_size

        if @str_table.fetch( code, nil )
          word = @str_table[ code ]

          @buf << word
          
          @str_table[ @next_code ] = @str_table[ seen ] + word[0,1]
          @next_code += 1
        else
          word = @str_table[ seen ]

          if code != @next_code
            warn "(#{code} != #{@next_code}) output may be corrupt"
          end
          @next_code += 1

          @str_table[ code ] = word + word[0,1]

          @buf << @str_table[ code ]
        end

        seen = code

        if @next_code == ( 2 ** @code_size )
          @code_size += 1 if @code_size < @max_code_size
        end
      end

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
      @str_table = []
      ( 0 .. 255 ).each do |i|
        @str_table[i] = i.chr
      end

      @code_size  = @init_code_size
      @next_code  = 257
    end

    def read_magic ( data )

      magic = ''
      ( 0 .. 2 ).each do |byte|
        magic << data.get_varint( byte * 8, 8 ).chr
      end

      if magic.bytesize != 3 or magic[0,2] != MAGIC
        raise "Invalid compress(1) header"
      end

      bits = magic.getbyte(2)
      @max_code_size = bits & MASK_BITS
      @block_mode    = ( ( bits & MASK_BLOCK ) >> 7 ) == 1

      if @init_code_size > @max_code_size
        raise "Can't decompress stream with init_code_size #{@init_code_size}"
          +"as it's greater than the stream's max_code_size #{@max_code_size}."
      end

    end
  end

  # Wrap up a String, in binary encoding, for single-bit manipulation and
  # working with variable-size integers.  This is necessary because our
  # LZW streams don't align with byte boundaries beyond the 4th byte, they
  # start writing codes 9 bits at a time (by default) and scale up from that
  # later.
  #
  # Derived from Gene Hsu's work at
  # https://github.com/genehsu/bitarray/blob/master/lib/bitarray/string.rb
  # but it wasn't worth inheriting from an unaccepted pull to a gem that's
  # unmaintained.  Mostly, masking out is way smarter than something like
  # vec() which is what I'm doing in the Perl version of this right now.
  #
  # Compared to bitarray:
  # I'm forcing this to default-0 for bits, making a fixed size
  # unnecessary, and supporting both endians.  And changing the
  # interface, so I shouldn't subclass anyway.
  class BitBuf
    include Enumerable

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
    private_constant :AND_BITMASK, :OR_BITMASK

    # If true, {#get_varint} and {#set_varint} work in big-endian order.
    # @return [Boolean]
    attr_reader :big_endian

    # The string, set to binary encoding, wrapped by this BitBuf.  This
    # is essentially the "pack"ed form of the bitfield.
    # @return [String]
    attr_reader :field

    # @param field [String] Optional string to wrap with BitBuf. Will be
    #   copied with binary encoding.
    # @param big_endian [Boolean] Optionally force endianness used when
    #   writing integers to the bitfield. Default detected at runtime.
    def initialize (
      field:      "\000",
      big_endian: LZW::big_endian?
    )

      @field      = field.b
      @big_endian = big_endian
    end

    # Set a specific bit at pos to val. Trying to set a bit beyond the
    # currently defined {#bytesize} will automatically grow the BitBuf
    # to the next whole byte needed to include that bit.
    #
    # @param pos [Numeric] 0-indexed bit position
    # @param val [Numeric] 0 or 1.  2 isn't yet allowed for bits.
    def []= ( pos, val )
      byte, bit = byte_divmod(pos)

      # puts "p:#{pos} B:#{byte} b:#{bit} = #{val}  (#{self[pos]})"

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

    # Read a bit at pos.  Trying to read a bit beyond the currently defined
    # {#bytesize} will automatically grow the BitBuf to the next whole byte
    # needed to include that bit.
    #
    # @param pos [Numeric] 0-indexed bit position
    # @return [Fixnum] the bit value at the requested bit position.
    def [] ( pos )
      byte, bit = byte_divmod(pos)

      (@field.getbyte(byte) >> bit ) & 1
    end

    # Iterate over the BitBuf bitwise.
    def each ( &block )
      ( bytesize * 8 ).times do |pos|
        yield self[pos]
      end
    end

    # Returns the BitBuf as a text string of zeroes and ones.
    def to_s
      @field.unpack('b*').first
    end

    # Returns the current bytesize of the BitBuf
    # @return [Numeric]
    # @!parse attr_reader :bytesize
    def bytesize
      @field.bytesize
    end

    # Store an unsigned integer in {#big_endian} order of "bits" length
    # at "pos" position. This method will grow the BitBuf as necessary,
    # whole bytes.
    #
    # @param pos [Numeric] 0-indexed bit position to write the first bit
    # @param width [Numeric] Default 8. The desired size of the supplied
    #   integer. There is no overflow check.
    # @param val [Numeric] The integer value to be stored in the BitBuf.
    def set_varint ( pos, width = 8, val )
      ( 0 .. width ).each do |bit_offset|
        self[pos + (@big_endian ? (width - bit_offset) : bit_offset)] =
          (val >> bit_offset) & 1
      end
      self
    end

    # Fetch an unsigned integer of "width" size from "pos" in the BitBuf.
    # Unlike other methods, if "pos" is beyond the end of the BitBuf, {nil}
    # is returned.
    #
    # @return [Numeric,nil]
    def get_varint ( pos, width = 8 )
      if ( pos + width ) > bytesize * 8
        return nil
      end

      int = 0
      ( 0 .. (width - 1) ).each do |bit_offset|
        int +=
          self[pos + (@big_endian ? (width - bit_offset) : bit_offset)] *
          ( 2 ** bit_offset )
      end

      int
    end

    private

    # Wraps divmod to always divide by 8 and automatically grow the BitBuf
    # as soon as we start poking beyond the end.
    #
    # @param [Numeric] pos A 0-indexed bit position.
    # @return [Array<Numeric>] byte index, bit offset
    def byte_divmod ( pos )
      byte, bit = pos.divmod(8)

      if byte > ( bytesize - 1 )
        @field <<  "\000" * ( byte - @field.bytesize + 1 ) 
      end

      [ byte, bit ]
    end

  end
end


