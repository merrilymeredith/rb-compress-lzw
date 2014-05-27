
module LZW

  class Compress
    attr_reader :block_mode, :lsb_first, :max_code_size, :init_code_size

    def initialize (
      block_mode:     true,
      lsb_first:      nil,
      init_code_size: 9,
      max_code_size:  16
    )
      @block_mode = block_mode
      
      if lsb_first.nil?
        @lsb_first = LZW::lsb_first
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
  class Decompress
  end


  def self.lsb_first
    #FINISHME: how to detect in ruby?

  end

end


