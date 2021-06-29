import pixie, pixie/fileformats/svg, strformat

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
  "dashes"
]

for file in files:
  let
    original = readFile(&"tests/images/svg/{file}.svg")
    image = decodeSvg(original)

  image.writeFile(&"tests/images/svg/rendered/{file}.png")
