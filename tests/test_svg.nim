import pixie/fileformats/svg, pixie

let
  original = readFile("tests/images/svg/Ghostscript_Tiger.svg")
  image = decodeSvg(original)
  gold = readImage("tests/images/svg/Ghostscript_Tiger.png")

doAssert image.data == gold.data
# image.writeFile("tests/images/svg/Ghostscript_Tiger.png")
