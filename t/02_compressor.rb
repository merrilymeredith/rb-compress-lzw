require "minitest/autorun"

require "lzw"
 
require_relative 'testdata'

describe LZW::Compressor do
  it "can be created with no arguments" do
    LZW::Compressor.new.must_be_instance_of LZW::Compressor
  end

  it "can be created with all arguments" do
    LZW::Compressor.new(
      big_endian:     true,
      block_mode:     0,
      max_code_size:  14,
    ).must_be_instance_of LZW::Compressor
  end

  it "rejects invalid arguments" do
    proc {
      LZW::Compressor.new(
        max_code_size: 25,
      )
    }.must_raise RuntimeError

    proc {
      LZW::Compressor.new(
        max_code_size: 8,
      )
    }.must_raise RuntimeError
  end

  it "responds to compress and reset" do
    c = LZW::Compressor.new
    %w( compress reset ).each { |m| c.must_respond_to m }
  end

  it "has accessors" do
    c = LZW::Compressor.new
    %w(
      big_endian block_mode max_code_size
    ).each { |m| c.must_respond_to m }
  end

  it "compresses simple data" do
    LZW::Compressor.new.compress( LOREM ).length.must_be :<, LOREM.length
  end

  it "compresses big data" do
    LZW::Compressor.new.compress( BIG ).length.must_be :<, BIG.length
  end

  it "compresses at a limited code size" do
    LZW::Compressor.new(
      max_code_size: 9
    ).compress( LOREM ).must_be_instance_of String
  end
end
