import pixie/fileformats/svg, benchy

let data = readFile("tests/images/svg/Ghostscript_Tiger.svg")

timeIt "svg decode":
  discard decodeSvg(data)
