import pixie/fileformats/gif, pixie/fileformats/png, print, parseutils, flatty/hexprint, flatty/binlisting

# let binary = decodeBinListing """
#   0:     47 49 46 38 39 61
#   6:     03 00
#   8:     05 00
#   A:     F7
#   B:     00
#   C:     00
#   D:     00 00 00
#   10:    80 00 00
#   85:    00 00 00
#   30A:   FF FF FF
#   30D:   21 F9
#   30F:   04
#   310:   01
#   311:   00 00
#   313:   10 16
#   314:   00
#   315:   2C
#   316:   00 00 00 00
#   31A:   03 00 05 00
#   31E:   00
#   31F:   08
#   320:   0B
#   321:   00 51 FC 1B 28 70 A0 C1 83 01 01
#   32C:   00
#   32D:   3B
# """

# echo hexPrint(binary)
# writeFile("tests/images/gif/3x5.gif", binary)

var img = decodeGIF(readFile("tests/images/gif/3x5.gif"))
writeFile("tests/images/gif/3x5.png", img.encodePng())

var img2 = decodeGIF(readFile("tests/images/gif/audrey.gif"))
writeFile("tests/images/gif/audrey.png", img2.encodePng())

var img3 = decodeGIF(readFile("tests/images/gif/sunflower.gif"))
writeFile("tests/images/gif/sunflower.png", img3.encodePng())
