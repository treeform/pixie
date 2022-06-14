import benchy, pixie/fileformats/svg

let
  data = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")
  parsed = parseSvg(data)

timeIt "svg render":
  discard newImage(parsed)
