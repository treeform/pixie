import pixie, pixie/fileformats/gif, xrays

block:
  let
    path = "tests/fileformats/gif/3x5.gif"
    image = readImage(path)
    dimensions = decodeGifDimensions(readFile(path))
  image.xray("tests/fileformats/gif/3x5.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height

block:
  let
    path = "tests/fileformats/gif/audrey.gif"
    image = readImage(path)
    dimensions = decodeGifDimensions(readFile(path))
  image.xray("tests/fileformats/gif/audrey.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height

block:
  let
    path = "tests/fileformats/gif/sunflower.gif"
    image = readImage(path)
    dimensions = decodeGifDimensions(readFile(path))
  image.xray("tests/fileformats/gif/sunflower.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height

block:
  let
    path = "tests/fileformats/gif/sunflower.gif"
    image = readImage(path)
    dimensions = decodeGifDimensions(readFile(path))
  image.xray("tests/fileformats/gif/sunflower.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height

block:
  let img4 = readImage("tests/fileformats/gif/newtons_cradle.gif")
  img4.xray("tests/fileformats/gif/newtons_cradle.png")

  let animatedGif =
    decodeGif(readFile("tests/fileformats/gif/newtons_cradle.gif"))
  doAssert animatedGif.frames.len == 36
  doAssert animatedGif.intervals.len == animatedGif.frames.len
