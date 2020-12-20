import pixie/fileformats/svg, pixie, strformat

const files = [
  "triangle01",
  "quad01",
  "Ghostscript_Tiger"
]

for file in files:
  let
    original = readFile(&"tests/images/svg/{file}.svg")
    image = decodeSvg(original)
    gold = readImage(&"tests/images/svg/{file}.png")

  doAssert image.data == gold.data
  # image.writeFile(&"{file}.png")
