import pixie/fileformats/gif, pixie/fileformats/png, pixie

var img = decodeGIF(readFile("tests/images/gif/3x5.gif"))
writeFile("tests/images/gif/3x5.png", img.encodePng())

var img2 = decodeGIF(readFile("tests/images/gif/audrey.gif"))
writeFile("tests/images/gif/audrey.png", img2.encodePng())

var img3 = decodeGIF(readFile("tests/images/gif/sunflower.gif"))
writeFile("tests/images/gif/sunflower.png", img3.encodePng())

var img4 = readImage("tests/images/gif/sunflower.gif")
doAssert img3.data == img4.data
