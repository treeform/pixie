import benchy, svg_cairo

let data = readFile("tests/images/svg/Ghostscript_Tiger.svg")

timeIt "svg decode":
  keep decodeSvg(data)
