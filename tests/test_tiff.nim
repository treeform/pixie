import pixie, pixie/fileformats/tiff

let
  t = decodeTiff(readFile("tests/fileformats/tiff/pc260001.tif"))
  image = newImage(t)
# image.writeFile("tests/fileformats/tiff/pc260001.png")
