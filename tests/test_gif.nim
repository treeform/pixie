import pixie, pixie/fileformats/gif

let img = readImage("tests/fileformats/gif/3x5.gif")
img.writeFile("tests/fileformats/gif/3x5.png")

let img2 = readImage("tests/fileformats/gif/audrey.gif")
img2.writeFile("tests/fileformats/gif/audrey.png")

let img3 = readImage("tests/fileformats/gif/sunflower.gif")
img3.writeFile("tests/fileformats/gif/sunflower.png")

let img4 = readImage("tests/fileformats/gif/newtons_cradle.gif")
img4.writeFile("tests/fileformats/gif/newtons_cradle.png")

let animatedGif =
  decodeGif(readFile("tests/fileformats/gif/newtons_cradle.gif"))
doAssert animatedGif.frames.len == 36
doAssert animatedGif.intervals.len == animatedGif.frames.len
