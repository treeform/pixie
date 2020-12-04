import pixie/fileformats/svg, pixie

let
  original = readFile("tests/images/svg/Ghostscript_Tiger.svg")
  image = decodeSvg(original)
image.writeFile("tests/images/svg/Ghostscript_Tiger.png")
