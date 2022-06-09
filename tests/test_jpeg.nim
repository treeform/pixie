import jpegsuite, pixie, pixie/fileformats/jpeg

for file in jpegSuiteFiles:
  let
    image = readImage(file)
    dimensions = decodeJpegDimensions(readFile(file))
  doAssert image.width == dimensions.width
  doAssert image.height == dimensions.height
