import pixie, pixie/fileformats/gif

block:
  let
    path = "tests/fileformats/gif/3x5.gif"
    image = decodeGIF(readFile(path))
    dimensions = decodeGifDimensions(readFile(path))
  image.writeFile("tests/fileformats/gif/3x5.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height

block:
  let
    path = "tests/fileformats/gif/audrey.gif"
    image = decodeGIF(readFile(path))
    dimensions = decodeGifDimensions(readFile(path))
  image.writeFile("tests/fileformats/gif/audrey.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height

block:
  let
    path = "tests/fileformats/gif/sunflower.gif"
    image = decodeGIF(readFile(path))
    dimensions = decodeGifDimensions(readFile(path))
  image.writeFile("tests/fileformats/gif/sunflower.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height

block:
  let
    path = "tests/fileformats/gif/sunflower.gif"
    image = decodeGIF(readFile(path))
    dimensions = decodeGifDimensions(readFile(path))
  image.writeFile("tests/fileformats/gif/sunflower.png")
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height
