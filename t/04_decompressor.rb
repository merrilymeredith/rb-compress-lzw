require "minitest/autorun"

require "lzw"
 
require_relative 'testdata'

describe LZW::Decompressor do
  it "can be created with no arguments" do
    LZW::Decompressor.new.must_be_instance_of LZW::Decompressor
  end

  it "can be created with all arguments" do
    LZW::Decompressor.new(
      big_endian:     true,
    ).must_be_instance_of LZW::Decompressor
  end

  it "responds to decompress and reset" do
    d = LZW::Decompressor.new
    %w( decompress reset ).each { |m| d.must_respond_to m }
  end

  it "has accessors" do
    d = LZW::Decompressor.new
    %w(
      big_endian
    ).each { |m| d.must_respond_to m }
  end

  it "decompresses simple data" do
    LZW::Decompressor.new.decompress(
      LZW::Simple.new.compress( LOREM )
    ).must_equal LOREM
  end

  it "decompresses big data with block_mode" do
    LZW::Decompressor.new.decompress(
      LZW::Compressor.new( block_mode: true ).compress( BIG )
    ).bytesize.must_equal BIG.bytesize
  end

  it "decompresses big data without block_mode" do
    LZW::Decompressor.new.decompress(
      LZW::Compressor.new( block_mode: false ).compress( BIG )
    ).bytesize.must_equal BIG.bytesize
  end

  it "decompresses at a limited code size" do
    LZW::Decompressor.new(
    ).decompress(
      LZW::Compressor.new(
        max_code_size:  10
      ).compress( BIG )
    ).bytesize.must_equal BIG.bytesize
  end
end
