require "minitest/autorun"

require "lzw"
 
require_relative 'testdata'

describe LZW::Simple do
  before do
    @s = LZW::Simple.new
  end

  it "can be created with no arguments" do
    @s.must_be_instance_of LZW::Simple
  end

  it "responds to compress and decompress" do
    %w( compress decompress ).each { |m| @s.must_respond_to m }
  end

  it "compresses simple data" do
    @s.compress( LOREM ).bytesize.must_be :<, LOREM.bytesize
  end

  it "decompresses that simple data exactly" do
    @s.decompress(
      @s.compress( LOREM )
    ).must_be :==, LOREM
  end

  it "raises errors for bad input" do
    proc {
      @s.decompress( "foo" )
    }.must_raise RuntimeError
  end

  it "decompresses big data exactly, bytewise" do
    @s.decompress(
      @s.compress( BIG )
    ).must_equal BIG.b
  end
end
