
This gem is a ruby implementation of the Lempel-Ziv-Welch compression
algorithm created in 1984.  As of 2004, all patents on it had expired.

This implementation is compatible with the classic unix compress tool, and
*not* compatible with the LZW compression used within GIF streams.

LZW is notable in two ways:  it is dictionary-based compression but does not
need to pass that dictionary within its files, instead decompression relies
on progressively building a dictionary in the same way as the compressor. It
also works outside the boundaries of bytes, writing its dictionary codes 9
bits at a time and scaling up as the codes increase to 16 bits.

**TODO**: non-block mode should have a first code of 256 rather than 257.
Missing a byte at the end of big decompress test.  Code isn't the most
efficient, but get impl right first.  everything should be lsb-first it
seems? (remove feature but add an echo of header bits to bad header err
so it's easy to see if someone encounters an msb0 one.)

To get right to work, check out the LZW::Simple class.

