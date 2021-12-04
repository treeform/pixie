import benchy, pixie/fileformats/svg, pixie/fileformats/png

let data = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")
#let data = readFile("tests/fileformats/svg/rotatedRect.svg")

writeFile("tiger.png", decodeSvg(data).encodePng())

timeIt "svg decode":
  discard decodeSvg(data)
