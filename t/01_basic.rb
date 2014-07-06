require "minitest/autorun"

require "lzw"
 
LOREM = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."


describe LZW::Simple do
  it "can be created with no arguments" do
    LZW::Simple.new.must_be_instance_of LZW::Simple
  end

  it "responds to compress and decompress" do
    s = LZW::Simple.new
    %w( compress decompress ).each { |m| s.must_respond_to m }
  end

  it "compresses simple data" do
    LZW::Simple.new.compress( LOREM ).length.must_be :<, LOREM.length
  end

  it "decompresses that simple data exactly" do
    LZW::Simple.new.decompress(
      LZW::Simple.new.compress( LOREM )
    ).must_be :==, LOREM
  end

  it "raises errors for bad input" do
    proc {
      LZW::Simple.new.decompress( "foo" )
    }.must_raise RuntimeError
  end
end
