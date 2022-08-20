import os, pixie, pixie/fileformats/bmp

# block:
#   var image = newImage(4, 2)

#   image[0, 0] = rgba(0, 0, 255, 255)
#   image[1, 0] = rgba(0, 255, 0, 255)
#   image[2, 0] = rgba(255, 0, 0, 255)
#   image[3, 0] = rgba(255, 255, 255, 255)

#   image[0, 1] = rgba(0, 0, 255, 127)
#   image[1, 1] = rgba(0, 255, 0, 127)
#   image[2, 1] = rgba(255, 0, 0, 127)
#   image[3, 1] = rgba(255, 255, 255, 127)

#   writeFile("tests/fileformats/bmp/test4x2.bmp", encodeBmp(image))

#   var image2 = decodeBmp(encodeBmp(image))
#   doAssert image2.width == image.width
#   doAssert image2.height == image.height
#   doAssert image2.data == image.data

# block:
#   var image = newImage(16, 16)
#   image.fill(rgba(255, 0, 0, 127))
#   writeFile("tests/fileformats/bmp/test16x16.bmp", encodeBmp(image))

#   var image2 = decodeBmp(encodeBmp(image))
#   doAssert image2.width == image.width
#   doAssert image2.height == image.height
#   doAssert image2.data == image.data

block:
  for bits in [32, 24]:
    let
      path = "tests/fileformats/bmp/knight." & $bits & ".master.bmp"
      image = decodeBmp(readFile(path))
    writeFile("tests/fileformats/bmp/knight." & $bits & ".bmp", encodeBmp(image))

block:
  let image = decodeBmp(readFile(
    "tests/fileformats/bmp/rgb.24.master.bmp"
  ))
  writeFile("tests/fileformats/bmp/rgb.24.bmp", encodeBmp(image))

block:
  for file in walkFiles("tests/fileformats/bmp/bmpsuite/*"):
    # echo file
    let
      image = decodeBmp(readFile(file))
      dimensions = decodeBmpDimensions(readFile(file))
    #image.writeFile(file.replace("bmpsuite", "output") & ".png")
    doAssert image.width == dimensions.width
    doAssert image.height == dimensions.height

block:
  let image = newImage(100, 100)
  image.fill(color(1, 0, 0, 1))

  let
    encoded = encodeDib(image)
    decoded = decodeDib(encoded.cstring, encoded.len, true)

  doAssert image.data == decoded.data
