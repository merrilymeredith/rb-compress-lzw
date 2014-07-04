require "minitest/autorun"

require "lzw"
 
describe LZW::BitBuf do
  it "can be created with no arguments" do
    LZW::BitBuf.new.must_be_instance_of LZW::BitBuf
  end

  it "can be created with an existing buffer" do
    LZW::BitBuf.new( field: "\xff" ).must_be_instance_of LZW::BitBuf
  end

  it "can be created with a forced endianness" do
    LZW::BitBuf.new( big_endian: true ).must_be_instance_of LZW::BitBuf
  end

  it "exposes the string buffer as 'field'" do
    LZW::BitBuf.new( field: 'foobar' ).field.must_be_instance_of String 
  end

  it "can set bit positions in existing bytes" do
    buf = LZW::BitBuf.new( field: "\x00" )
    buf[5] = 1
    buf.field.must_equal "\x20".b
  end

  it "can set bit positions beyond the current size" do
    buf = LZW::BitBuf.new
    (8 .. 15).each { |p| buf[p] = 1 }
    buf.field.must_equal "\x00\xff".b
  end

  it "is enumerable (bitwise)" do
    LZW::BitBuf.new( field: "\xff" )
      .inject('') { |acc, bitval| acc << bitval.to_s }
      .must_equal "11111111"
  end

  it "abstracts position from endianness" do
    l = LZW::BitBuf.new( big_endian: false )
    l[4] = 1

    b = LZW::BitBuf.new( big_endian: true )
    b[4] = 1

    l.field.wont_equal b.field
  end

end
