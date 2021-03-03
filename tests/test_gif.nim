import pixie, pixie/fileformats/gif

var img = decodeGIF(readFile("tests/images/gif/3x5.gif"))
img.writeFile("tests/images/gif/3x5.png")

var img2 = decodeGIF(readFile("tests/images/gif/audrey.gif"))
img2.writeFile("tests/images/gif/audrey.png")

var img3 = decodeGIF(readFile("tests/images/gif/sunflower.gif"))
img3.writeFile("tests/images/gif/sunflower.png")

var img4 = readImage("tests/images/gif/sunflower.gif")
doAssert img3.data == img4.data
