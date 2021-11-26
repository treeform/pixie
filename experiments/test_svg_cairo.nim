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
  "Ghostscript_Tiger",
  "scale",
  "miterlimit",
  "dashes"
]

proc doDiff(rendered: Image, name: string) =
  rendered.writeFile(&"tests/fileformats/svg/rendered/{name}.png")
  let
    master = readImage(&"tests/fileformats/svg/masters/{name}.png")
    (diffScore, diffImage) = diff(master, rendered)
  echo &"{name} score: {diffScore}"
  diffImage.writeFile(&"tests/fileformats/svg/diffs/{name}.png")

for file in files:
  doDiff(decodeSvg(readFile(&"tests/fileformats/svg/{file}.svg")), file)
