import pixie, pixie/fileformats/gif

var img = decodeGIF(readFile("tests/fileformats/gif/3x5.gif"))
img.writeFile("tests/fileformats/gif/3x5.png")

var img2 = decodeGIF(readFile("tests/fileformats/gif/audrey.gif"))
img2.writeFile("tests/fileformats/gif/audrey.png")

var img3 = decodeGIF(readFile("tests/fileformats/gif/sunflower.gif"))
img3.writeFile("tests/fileformats/gif/sunflower.png")

var img4 = readImage("tests/fileformats/gif/sunflower.gif")
doAssert img3.data == img4.data
