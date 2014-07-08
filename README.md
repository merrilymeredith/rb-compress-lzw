
This gem is a ruby implementation of the Lempel-Ziv-Welch compression
algorithm created in 1984.  As of 2004, all patents on it had expired.

This implementation is compatible with the classic unix compress tool, and
*not* compatible with the LZW compression used within GIF streams.

LZW is notable in two ways:  it is dictionary-based compression but does not
need to pass that dictionary within its files, instead decompression relies
on progressively building a dictionary in the same way as the compressor. It
also works outside the boundaries of bytes, writing its dictionary codes 9
bits at a time and scaling up as the codes increase to 16 bits.

**TODO**: compress(1) also uses a feature called block mode, where a code in the
stream trigers a dictionary reset and beginning at 9 bits again.  This is not
yet implemented, but the lack of it only hinders compatibility with this
gem reading .Z files which use the feature.  Other combinations of input and 
output sources are fine.  The lack of block mode theoretically only limits
compression ratio after the maximum dictionary size is reached, if the stream
data is no longer suited to the existing dictionary.


