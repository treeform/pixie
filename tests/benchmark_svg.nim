import benchy, pixie/fileformats/svg

let data = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")

timeIt "svg parse + render":
  discard newImage(parseSvg(data))
