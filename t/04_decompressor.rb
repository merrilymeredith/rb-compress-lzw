require "minitest/autorun"

require "lzw"
 
require_relative 'testdata'

describe LZW::Decompressor do
  before do
    @d = LZW::Decompressor.new
  end

  it "can be created with no arguments" do
    @d.must_be_instance_of LZW::Decompressor
  end

  it "responds to decompress and reset" do
    %w( decompress reset ).each { |m| @d.must_respond_to m }
  end

  it "decompresses simple data" do
    @d.decompress(
      LZW::Simple.new.compress( LOREM )
    ).must_equal LOREM
  end

  it "decompresses big data with block_mode" do
    @d.decompress(
      LZW::Compressor.new( block_mode: true ).compress( BIG )
    ).bytesize.must_equal BIG.bytesize
  end

  it "decompresses big data without block_mode" do
    @d.decompress(
      LZW::Compressor.new( block_mode: false ).compress( BIG )
    ).bytesize.must_equal BIG.bytesize
  end

  it "decompresses exactly at a limited code size, bytewise" do
    @d.decompress(
      LZW::Compressor.new(
        max_code_size:  10
      ).compress( BIG )
    ).must_equal BIG.b
  end

  it "decompresses exactly at a extended code size, bytewise" do
    @d.decompress(
      LZW::Compressor.new(
        max_code_size:  31
      ).compress( BIG )
    ).must_equal BIG.b
  end
end
