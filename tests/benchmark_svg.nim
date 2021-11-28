import benchy, pixie/fileformats/svg, pixie/fileformats/png

let data = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")

writeFile("tiger.png", decodeSvg(data).encodePng())

timeIt "svg decode":
  discard decodeSvg(data)
