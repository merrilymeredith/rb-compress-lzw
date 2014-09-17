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

  # compress-lzw gem version
  VERSION         = '0.0.1'

  MAGIC           = "\037\235".b      # static magic bytes
  MASK_BITS       = 0x1f              # mask for 3rd byte for max_code_size
  MASK_BLOCK      = 0x80              # mask for 3rd byte for block_mode
  RESET_CODE      = 256               # block mode code to reset code table
  BL_INIT_CODE    = 257               # block mode first available code
  NR_INIT_CODE    = 256               # normal mode first available code
  INIT_CODE_SIZE  = 9                 # initial code size beyond the header
  CHECKPOINT_BITS = 10_000            # block mode check for falling compression

  private_constant :MAGIC, :MASK_BITS, :MASK_BLOCK
  private_constant :RESET_CODE, :BL_INIT_CODE, :NR_INIT_CODE
  private_constant :INIT_CODE_SIZE, :CHECKPOINT_BITS


  # Simplest-use LZW compressor and decompressor
  class Simple

    # Compress input with defaults
    #
    # @param data [#each_byte] data to be compressed
    # @return [String] LZW compressed data
    def compress (data)
      LZW::Compressor.new.compress(data)
    end

    # Decompress input with defaults
    #
    # @param data [String] compressed data to be decompressed
    # @return [String] decompressed data
    # @raise [RuntimeException] if there is an error in the compressed stream
    def decompress (data)
      LZW::Decompressor.new.decompress(data)
    end
  end
  
  # Scaling LZW data compressor with some configurables
  class Compressor

    # If true, enables compression in block mode. Default true.
    #
    # After reaching {#max_code_size} bits per code, the compression dictionary
    # and code size may be reset if a drop in compression ratio is observed.
    # @return [Boolean]
    attr_reader :block_mode

    # The maximum code size, in bits, that compression may scale up to.
    # Default 16.
    #
    # Valid values are init_code_size(9) to 31.  Values greater than 16 break
    # compatibility with compress(1).
    # @return [Fixnum]
    attr_reader :max_code_size

    # LZW::Compressors work fine with the default settings.
    # 
    # @param block_mode [Boolean] (see {#block_mode})
    # @param max_code_size [Fixnum] (see {#max_code_size})
    def initialize (
      block_mode:     true,
      max_code_size:  16
    )
      if max_code_size > 31 || max_code_size < INIT_CODE_SIZE
        fail "max_code_size must be between #{INIT_CODE_SIZE} and 31"
      end

      @block_mode     = block_mode
      @max_code_size  = max_code_size
    end

    # Given a String(ish) of data, return the LZW-compressed result as another
    # String.
    #
    # @param data [#each_byte<#chr>] Input data
    # @return [String]
    def compress(data)
      reset

      # In block mode, we track compression ratio
      @checkpoint    = nil
      @last_ratio    = nil
      @bytes_in      = 0

      seen           = ''
      @next_increase = 2**@code_size

      data.each_byte do |byte|
        char       = byte.chr
        @bytes_in += 1

        if @code_table.has_key?(seen + char)
          seen << char
        else
          write_code(@code_table[seen])

          new_code(seen + char)

          check_ratio_at_cap

          seen = char
        end
      end

      write_code(@code_table[seen])

      @buf.field
    end

    # Reset compressor state.  This is run at the beginning of {#compress}, so
    # it's not necessary for repeated compression, but this allows wiping the
    # last code table and buffer from the object instance.
    def reset
      @buf     = LZW::BitBuf.new
      @buf_pos = 0
      
      # begin with the magic bytes
      magic().each_byte do |b|
        @buf.set_varint(@buf_pos, 8, b.ord)
        @buf_pos += 8 
      end

      code_reset
    end

    private

    # Re-initialize the code table, code size and next code.  This happens at
    # the beginning of compression and whenever RESET_CODE is added to the
    # stream (block mode).
    def code_reset
      @code_table = {}
      (0 .. 255).each do |i|
        @code_table[i.chr] = i
      end

      @at_max_code   = 0
      @code_size     = INIT_CODE_SIZE
      @next_code     = @block_mode ? BL_INIT_CODE : NR_INIT_CODE
      @next_increase = 2**@code_size
    end

    # Prepare the header magic bytes for this stream.
    # @return [String]
    def magic
      MAGIC + (
        (@max_code_size & MASK_BITS) |
        (@block_mode ? MASK_BLOCK : 0)
      ).chr
    end

    # Store a new code in our table and bump code sizes if necessary.
    def new_code (word)
      if @next_code >= @next_increase
        if @code_size < @max_code_size
          @code_size     += 1
          @next_increase *= 2

          # warn "encode up to #{@code_size} for next_code #{@next_code} at #{@buf_pos}"
        else
          @at_max_code = 1
        end
      end

      if @at_max_code == 0
        @code_table[word] = @next_code
        @next_code += 1
      end
    end

    # Write a code at the current code size and bump the position pointer.
    def write_code (code)
      @buf.set_varint(@buf_pos, @code_size, code)
      @buf_pos += @code_size
    end

    # Once we've reached the max_code_size, if in block mode, issue a code
    # reset if the compression ratio falls.
    def check_ratio_at_cap
      return if !@block_mode
      return if !@at_max_code

      if @checkpoint.nil?
        @checkpoint = @buf_pos + CHECKPOINT_BITS
      elsif @buf_pos > @checkpoint
        @ratio      = @bytes_in / (@buf_pos / 8)
        @last_ratio = @ratio if @last_ratio.nil?

        if @ratio >= @last_ratio
          @last_ratio = @ratio
          @checkpoint = @buf_pos + CHECKPOINT_BITS
        elsif @ratio < @last_ratio
          # warn "writing reset at #{@buf_pos} #{@buf_pos.divmod(8).join(',')}"
          write_code(RESET_CODE)

          code_reset

          @checkpoint, @last_ratio = [nil, nil]
        end
      end
    end

  end


  # Scaling LZW decompressor
  class Decompressor

    # Given a String(ish) of LZW-compressed data, return the decompressed data
    # as a String left in "ASCII-8BIT" encoding.
    #
    # @param data [String] Compressed input data
    # @return [String]
    def decompress (data)
      reset

      @data     = LZW::BitBuf.new(field: data)
      @data_pos = 0

      read_magic(@data)
      @data_pos = 24

      # we've read @block_mode from the header now, so make sure our init_code
      # is set properly
      str_reset

      next_increase = 2**@code_size

      seen = read_code
      @buf << @str_table[ seen ]

      while (code = read_code)

        if @block_mode and code == RESET_CODE
          str_reset

          seen = read_code
          # warn "reset at #{data_pos} initial code #{@str_table[seen]}"
          next
        end

        if (word = @str_table.fetch(code, nil))
          @buf << word
          
          @str_table[@next_code] = @str_table[seen] + word[0,1]

        elsif code == @next_code
          word = @str_table[seen]
          @str_table[code] = word + word[0,1]

          @buf << @str_table[code]

        else
          fail "(#{code} != #{@next_code}) input may be corrupt at bit #{data_pos - @code_size}"
        end

        seen = code
        @next_code += 1

        if @next_code >= next_increase
          if @code_size < @max_code_size
            @code_size    += 1
            next_increase *= 2
            # warn "decode up to #{@code_size} for next #{@next_code} max #{@max_code_size} at #{data_pos}"
          end
        end

      end

      @buf
    end

    # Reset the state of the decompressor. This is run at the beginning of
    # {#decompress}, so it's not necessary for reuse of an instance, but this
    # allows wiping the string code table and buffer from the object instance.
    def reset
      @max_code_size = 16
      @buf           = ''.b

      str_reset
    end

    private

    # Build up the initial string table, reset code size and next code.
    def str_reset
      @str_table = []
      (0 .. 255).each do |i|
        @str_table[i] = i.chr
      end

      @code_size = INIT_CODE_SIZE
      @next_code = @block_mode ? BL_INIT_CODE : NR_INIT_CODE
    end

    # Verify the two magic bytes at the beginning of the stream and read bit
    # and block data from the third.
    def read_magic (data)
      magic = ''
      (0 .. 2).each do |byte|
        magic << data.get_varint(byte * 8, 8).chr
      end

      if magic.bytesize != 3 || magic[0,2] != MAGIC
        fail "Invalid compress(1) header " +
          "(expected #{MAGIC.unpack('h*')}, got #{magic[0,2].unpack('h*')})"
      end

      bits           = magic.getbyte(2)
      @max_code_size = bits & MASK_BITS
      @block_mode    = ( ( bits & MASK_BLOCK ) >> 7 ) == 1
    end

    def read_code
      code       = @data.get_varint(@data_pos, @code_size)
      @data_pos += @code_size
      code
    end
  end

  # Wrap up a String, in binary encoding, for single-bit manipulation and
  # working with variable-size integers.  This is necessary because our LZW
  # streams don't align with byte boundaries beyond the 4th byte, they start
  # writing codes 9 bits at a time (by default) and scale up from that later.
  #
  # Derived from Gene Hsu's work at
  # https://github.com/genehsu/bitarray/blob/master/lib/bitarray/string.rb but
  # it wasn't worth inheriting from an unaccepted pull to a gem that's
  # unmaintained.  Mostly, masking out is way smarter than something like vec()
  # which is what I'm doing in the Perl version of this right now.
  #
  # Compared to bitarray:
  # I'm forcing this to default-0 for bits, making a fixed size unnecessary,
  # and supporting both bit orders. And changing the interface, so I shouldn't
  # subclass anyway.
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
    ].map{|w| [w].pack('b8').getbyte(0) }.freeze

    OR_BITMASK = %w[
      10000000
      01000000
      00100000
      00010000
      00001000
      00000100
      00000010
      00000001
    ].map{|w| [w].pack('b8').getbyte(0) }.freeze
    private_constant :AND_BITMASK, :OR_BITMASK

    # If true, {#get_varint} and {#set_varint} work in MSB-first order.
    # @return [Boolean]
    attr_reader :msb_first

    # The string, set to binary encoding, wrapped by this BitBuf.  This is
    # essentially the "pack"ed form of the bitfield.
    # @return [String]
    attr_reader :field

    # @param field [String] Optional string to wrap with BitBuf. Will be
    #   copied with binary encoding.
    # @param msb_first [Boolean] Optionally force bit order used when
    #   writing integers to the bitfield. Default false.
    def initialize (
      field:      "\000",
      msb_first:  false
    )

      @field      = field.b
      @msb_first  = msb_first
    end

    # Set a specific bit at pos to val. Trying to set a bit beyond the
    # currently defined {#bytesize} will automatically grow the BitBuf to the
    # next whole byte needed to include that bit.
    #
    # @param pos [Numeric] 0-indexed bit position
    # @param val [Numeric] 0 or 1.  2 isn't yet allowed for bits.
    def []= (pos, val)
      byte, bit = byte_divmod(pos)

      # puts "p:#{pos} B:#{byte} b:#{bit} = #{val}  (#{self[pos]})"

      case val
      when 0
        @field.setbyte(
          byte,
          @field.getbyte(byte) & AND_BITMASK[bit]
        )
      when 1
        @field.setbyte(
          byte,
          @field.getbyte(byte) | OR_BITMASK[bit]
        )
      else
        fail "Only 0 and 1 are valid for a bit field"
      end
    end

    # Read a bit at pos.  Trying to read a bit beyond the currently defined
    # {#bytesize} will automatically grow the BitBuf to the next whole byte
    # needed to include that bit.
    #
    # @param pos [Numeric] 0-indexed bit position
    # @return [Fixnum] the bit value at the requested bit position.
    def [] (pos)
      byte, bit = byte_divmod(pos)

      (@field.getbyte(byte) >> bit) & 1
    end

    # Iterate over the BitBuf bitwise.
    def each
      (bytesize * 8).times do |pos|
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

    # Store an unsigned integer in of "bits" length, at "pos" position, and in
    # LSB-first order unless {#msb_first} is true. This method will grow the
    # BitBuf as necessary, in whole bytes.
    #
    # @param pos [Numeric] 0-indexed bit position to write the first bit
    # @param width [Numeric] Default 8. The desired size of the supplied
    #   integer. There is no overflow check.
    # @param val [Numeric] The integer value to be stored in the BitBuf.
    def set_varint (pos, width = 8, val)
      fail "integer overflow for #{width} bits: #{val}" \
        if val > 2**width

      width.times do |bit_offset|
        self[pos + (@msb_first ? (width - bit_offset) : bit_offset)] =
          (val >> bit_offset) & 1
      end
      self
    end

    # Fetch an unsigned integer of "width" size from "pos" in the BitBuf.
    # Unlike other methods, if "pos" is beyond the end of the BitBuf, {nil} is
    # returned.
    #
    # @return [Numeric, nil]
    def get_varint (pos, width = 8)
      return nil if (pos + width) > bytesize * 8

      int = 0
      width.times do |bit_offset|
        int += 2**bit_offset *
          self[pos + (@msb_first ? (width - bit_offset) : bit_offset)]
      end

      int
    end

    private

    # Wraps divmod to always divide by 8 and automatically grow the BitBuf as
    # soon as we start poking beyond the end. Side-effecty.
    #
    # @param [Numeric] pos A 0-indexed bit position.
    # @return [Array<Numeric>] byte index, bit offset
    def byte_divmod (pos)
      byte, bit = pos.divmod(8)

      if byte > (bytesize - 1)
        @field <<  "\000" * (byte - @field.bytesize + 1) 
      end

      [byte, bit]
    end

  end
end


