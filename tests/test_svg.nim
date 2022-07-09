import pixie, pixie/fileformats/svg, strformat, xrays

const files = [
  "line01",
  "polyline01",
  "polygon01",
  "rect01",
  "rect02",
  "circle01",
  "ellipse01",
  "triangle01",
  "quad01",
  "Ghostscript_Tiger",
  "scale",
  "miterlimit",
  "dashes",
  "dragon2"
]

for file in files:
  let image = readImage(&"tests/fileformats/svg/{file}.svg")
  image.xray(&"tests/fileformats/svg/masters/{file}.png")

block:
  let
    svg = parseSvg(
      readFile("tests/fileformats/svg/accessibility-outline.svg"),
      512, 512
    )
    image = newImage(svg)
  image.xray(&"tests/fileformats/svg/masters/accessibility-outline.png")
