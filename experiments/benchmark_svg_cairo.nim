import benchy, svg_cairo

let data = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")

timeIt "svg decode":
  discard decodeSvg(data)
