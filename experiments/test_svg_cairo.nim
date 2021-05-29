import pixie, strformat, svg_cairo

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
  "Ghostscript_Tiger"
]

for file in files:
  let image = decodeSvg(readFile(&"tests/images/svg/{file}.svg"))
  image.writeFile(&"tests/images/svg/{file}.png")
