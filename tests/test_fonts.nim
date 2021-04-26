import pixie, strformat

proc doDiff(rendered: Image, name: string) =
  let
    master = readImage(&"tests/fonts/masters/{name}.png")
    (_, diffImage) = diff(master, rendered)
  rendered.writeFile(&"tests/fonts/rendered/{name}.png")
  diffImage.writeFile(&"tests/fonts/diffs/{name}.png")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 72

  let
    image = newImage(200, 100)
    layout = font.typeset("asdf")

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic1")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 72

  let
    image = newImage(200, 100)
    layout = font.typeset("A cow")

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic2")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let
    image = newImage(200, 100)
    layout = font.typeset("A bit of text HERE")

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic3")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24
  font.lineHeight = 100

  let
    image = newImage(200, 100)
    layout = font.typeset("Line height")

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic4")

block:
  let font = readFont("tests/fonts/Ubuntu-Regular.ttf")
  font.size = 24

  let
    image = newImage(200, 100)
    layout = font.typeset("Another font")

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic5")

block:
  let font = readFont("tests/fonts/Aclonica-Regular.ttf")
  font.size = 24

  let
    image = newImage(200, 100)
    layout = font.typeset("Different font")

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic6")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let
    image = newImage(200, 100)
    layout1 = font.typeset("First line")
    layout2 = font.typeset("Second line")

  image.fill(rgba(255, 255, 255, 255))

  for path in layout1:
    image.fillPath(path, rgba(0, 0, 0, 255))

  for path in layout2:
    image.fillPath(path, rgba(0, 0, 0, 255), vec2(0, font.defaultLineHeight))

  doDiff(image, "basic7")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let
    image = newImage(200, 100)
    layout = font.typeset(
      "Wrapping text to new line",
      bounds = vec2(200, 0)
    )

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic8")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let
    image = newImage(200, 100)
    layout = font.typeset(
      "Supercalifragilisticexpialidocious",
      bounds = vec2(200, 0)
    )

  image.fill(rgba(255, 255, 255, 255))

  for path in layout:
    image.fillPath(path, rgba(0, 0, 0, 255))

  doDiff(image, "basic9")
