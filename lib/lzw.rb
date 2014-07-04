module LZW

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
      @block_mode = block_mode
      
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

      @init_code_size = init_code_size
      @max_code_size  = max_code_size
    end

    def compress( data )
      self.reset()

    end

    def reset
      @code_table = {}
      @code_size  = @init_code_size
      @next_code  = 257
    end

  end

  class Decompressor
    def decompress ( data )
      
    end
  end


  def self.big_endian
    [1].pack("I") == [1].pack("N")
  end

end


