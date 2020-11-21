# http://www.schaik.com/pngsuite/

const
  pngSuiteFiles* = [
    # Basic
    "basn0g01", # black & white
    "basn0g02", # 2 bit (4 level) grayscale
    "basn0g04", # 4 bit (16 level) grayscale
    "basn0g08", # 8 bit (256 level) grayscale
    # "basn0g16", # 16 bit (64k level) grayscale
    "basn2c08", # 3x8 bits rgb color
    # "basn2c16", # 3x16 bits rgb color
    "basn3p01", # 1 bit (2 color) paletted
    "basn3p02", # 2 bit (4 color) paletted
    "basn3p04", # 4 bit (16 color) paletted
    "basn3p08", # 8 bit (256 color) paletted
    "basn4a08", # 8 bit grayscale + 8 bit alpha-channel
    # "basn4a16", # 16 bit grayscale + 16 bit alpha-channel
    "basn6a08", # 3x8 bits rgb color + 8 bit alpha-channel
    # "basn6a16", # 3x16 bits rgb color + 16 bit alpha-channel

    # Interlaced
    # "basi0g01", # black & white
    # "basi0g02", # 2 bit (4 level) grayscale
    # "basi0g04", # 4 bit (16 level) grayscale
    # "basi0g08", # 8 bit (256 level) grayscale
    # "basi0g16", # 16 bit (64k level) grayscale
    # "basi2c08", # 3x8 bits rgb color
    # "basi2c16", # 3x16 bits rgb color
    # "basi3p01", # 1 bit (2 color) paletted
    # "basi3p02", # 2 bit (4 color) paletted
    # "basi3p04", # 4 bit (16 color) paletted
    # "basi3p08", # 8 bit (256 color) paletted
    # "basi4a08", # 8 bit grayscale + 8 bit alpha-channel
    # "basi4a16", # 16 bit grayscale + 16 bit alpha-channel
    # "basi6a08", # 3x8 bits rgb color + 8 bit alpha-channel
    # "basi6a16", # 3x16 bits rgb color + 16 bit alpha-channel

    # Odd sizes
    # "s01i3p01", # 1x1 paletted file, interlaced
    "s01n3p01", # 1x1 paletted file, no interlacing
    # "s02i3p01", # 2x2 paletted file, interlaced
    "s02n3p01", # 2x2 paletted file, no interlacing
    # "s03i3p01", # 3x3 paletted file, interlaced
    "s03n3p01", # 3x3 paletted file, no interlacing
    # "s04i3p01", # 4x4 paletted file, interlaced
    "s04n3p01", # 4x4 paletted file, no interlacing
    # "s05i3p02", # 5x5 paletted file, interlaced
    "s05n3p02", # 5x5 paletted file, no interlacing
    # "s06i3p02", # 6x6 paletted file, interlaced
    "s06n3p02", # 6x6 paletted file, no interlacing
    # "s07i3p02", # 7x7 paletted file, interlaced
    "s07n3p02", # 7x7 paletted file, no interlacing
    # "s08i3p02", # 8x8 paletted file, interlaced
    "s08n3p02", # 8x8 paletted file, no interlacing
    # "s09i3p02", # 9x9 paletted file, interlaced
    "s09n3p02", # 9x9 paletted file, no interlacing
    # "s32i3p04", # 32x32 paletted file, interlaced
    "s32n3p04", # 32x32 paletted file, no interlacing
    # "s33i3p04", # 33x33 paletted file, interlaced
    "s33n3p04", # 33x33 paletted file, no interlacing
    # "s34i3p04", # 34x34 paletted file, interlaced
    "s34n3p04", # 34x34 paletted file, no interlacing
    # "s35i3p04", # 35x35 paletted file, interlaced
    "s35n3p04", # 35x35 paletted file, no interlacing
    # "s36i3p04", # 36x36 paletted file, interlaced
    "s36n3p04", # 36x36 paletted file, no interlacing
    # "s37i3p04", # 37x37 paletted file, interlaced
    "s37n3p04", # 37x37 paletted file, no interlacing
    # "s38i3p04", # 38x38 paletted file, interlaced
    "s38n3p04", # 38x38 paletted file, no interlacing
    # "s39i3p04", # 39x39 paletted file, interlaced
    "s39n3p04", # 39x39 paletted file, no interlacing
    # "s40i3p04", # 40x40 paletted file, interlaced
    "s40n3p04", # 40x40 paletted file, no interlacing
  ]

  pngSuiteCorruptedFiles* = [
    "xs1n0g01", # signature byte 1 MSBit reset to zero
    "xs2n0g01", # signature byte 2 is a 'Q'
    "xs4n0g01", # signature byte 4 lowercase
    "xs7n0g01", # 7th byte a space instead of control-Z
    "xcrn0g04", # added cr bytes
    "xlfn0g04", # added lf bytes
    # "xhdn0g08", # incorrect IHDR checksum
    "xc1n0g08", # color type 1
    "xc9n2c08", # color type 9
    "xd0n2c08", # bit-depth 0
    "xd3n2c08", # bit-depth 3
    "xd9n2c08", # bit-depth 99
    "xdtn0g01", # missing IDAT chunk
    # "xcsn0g01" # incorrect IDAT checksum
  ]
