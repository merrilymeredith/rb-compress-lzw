require "minitest/autorun"

require "lzw"
 
describe LZW::BitBuf do
  it "can be created with no arguments" do
    LZW::BitBuf.new.must_be_instance_of LZW::BitBuf
  end

  it "can be created with an existing buffer" do
    LZW::BitBuf.new( field: "\xff" ).must_be_instance_of LZW::BitBuf
  end

  it "can be created with a forced MSB0 bit order" do
    LZW::BitBuf.new( msb_first: true ).must_be_instance_of LZW::BitBuf
  end

  it "exposes the string buffer as 'field'" do
    LZW::BitBuf.new( field: 'foobar' ).field.must_be_instance_of String 
  end

  it "responds to [], []=, each, to_s, set_varint, and get_varint" do
    b = LZW::BitBuf.new
    %w(
      [] []= each to_s set_varint get_varint
    ).each { |m| b.must_respond_to m }
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
  
  it "can fetch bit positions beyond the current size as 0" do
    # only extend one "byte"
    LZW::BitBuf.new[9].must_equal 0
    # now skip a few
    LZW::BitBuf.new[32].must_equal 0
  end

  it "is enumerable (bitwise)" do
    LZW::BitBuf.new( field: "\xff" )
      .inject('') { |acc, bitval| acc << bitval.to_s }
      .must_equal '11111111'
  end

  it "can be stringified to ascii 0 and 1" do
    LZW::BitBuf.new( field: "\xff" )
      .to_s
      .must_equal '11111111'
  end

  it "stores and fetches variable-sized integers" do
    b = LZW::BitBuf.new.set_varint( 0, 12, 2**12 - 1)
    b.to_s.must_equal '1111111111110000'

    b.get_varint( 0, 12 ).must_equal( 2**12 - 1 )
  end

  it "returns nil when trying to get_varint beyond the defined length" do
    LZW::BitBuf.new.get_varint(32).must_be_nil
  end

  it "always treats subscript as LSB0" do
    l = LZW::BitBuf.new( msb_first: false )
    l[4] = 1

    b = LZW::BitBuf.new( msb_first: true )
    b[4] = 1

    l.field.must_equal b.field
  end

  it "handles bit order when writing integers" do
    l = LZW::BitBuf.new( msb_first: false )
    l.set_varint( 0, 8, 15 )
    l.to_s.must_equal '11110000'

    b = LZW::BitBuf.new( msb_first: true )
    b.set_varint( 0, 8, 15 )
    b.to_s.must_equal '00001111'

    l.field.wont_equal b.field
  end

end
