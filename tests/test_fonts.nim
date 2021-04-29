import pixie, pixie/fileformats/png, strformat

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "fill", rgba(0, 0, 0, 255))
  image.writeFile("tests/fonts/image_fill.png")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.strokeText(font, "stroke", rgba(0, 0, 0, 255))
  image.writeFile("tests/fonts/image_stroke.png")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 64
  let mask = newMask(200, 100)
  mask.fillText(font, "fill")
  writeFile("tests/fonts/mask_fill.png", mask.encodePng())

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 64
  let mask = newMask(200, 100)
  mask.strokeText(font, "stroke")
  writeFile("tests/fonts/mask_stroke.png", mask.encodePng())

block:
  let font = readFont("tests/fonts/Changa-Bold.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Changa")
  writeFile("tests/fonts/svg_changa.png", mask.encodePng())

block:
  let font = readFont("tests/fonts/DejaVuSans.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Deja vu ")
  writeFile("tests/fonts/svg_dejavu.png", mask.encodePng())

block:
  let font = readFont("tests/fonts/IBMPlexSans-Regular.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "IBM ")
  writeFile("tests/fonts/svg_ibm.png", mask.encodePng())

block:
  let font = readFont("tests/fonts/Moon-Bold.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Moon ")
  writeFile("tests/fonts/svg_moon.png", mask.encodePng())

block:
  let font = readFont("tests/fonts/Ubuntu.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Ubuntu ")
  writeFile("tests/fonts/svg_ubuntu.png", mask.encodePng())

proc doDiff(rendered: Image, name: string) =
  let
    master = readImage(&"tests/fonts/masters/{name}.png")
    (_, diffImage) = diff(master, rendered)
  rendered.writeFile(&"tests/fonts/rendered/{name}.png")
  diffImage.writeFile(&"tests/fonts/diffs/{name}.png")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "asdf", rgba(0, 0, 0, 255))

  doDiff(image, "basic1")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A cow", rgba(0, 0, 0, 255))

  doDiff(image, "basic2")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A bit of text HERE", rgba(0, 0, 0, 255))

  doDiff(image, "basic3")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24
  font.lineHeight = 100

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Line height", rgba(0, 0, 0, 255))

  doDiff(image, "basic4")

block:
  let font = readFont("tests/fonts/Ubuntu-Regular.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Another font", rgba(0, 0, 0, 255))

  doDiff(image, "basic5")

block:
  let font = readFont("tests/fonts/Aclonica-Regular.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Different font", rgba(0, 0, 0, 255))

  doDiff(image, "basic6")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "First line",
    rgba(0, 0, 0, 255)
  )
  image.fillText(
    font,
    "Second line",
    rgba(0, 0, 0, 255),
    vec2(0, font.defaultLineHeight)
  )

  doDiff(image, "basic7")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to new line",
    rgba(0, 0, 0, 255),
    bounds = vec2(200, 0)
  )

  doDiff(image, "basic8")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Supercalifragilisticexpialidocious",
    rgba(0, 0, 0, 255),
    bounds = vec2(200, 0)
  )

  doDiff(image, "basic9")

block:
  let font = readFont("tests/fonts/Roboto-Regular.ttf")
  font.size = 16

  let image = newImage(500, 300)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis in quam in nulla bibendum luctus. Integer dui lectus, ultricies commodo enim quis, laoreet lacinia erat. Vivamus ultrices maximus risus, non aliquam quam sagittis quis. Ut nec diam vitae tortor interdum ullamcorper in aliquet velit. Ut sed lobortis mi. Nulla venenatis lectus varius justo lacinia, quis sollicitudin nunc ultrices. Donec a suscipit arcu, id egestas neque. Nullam commodo pharetra est. Nullam gravida nibh eget quam venenatis lacinia. Vestibulum et libero arcu. Sed dignissim enim eros. Nullam eleifend luctus erat sed luctus. Nunc tincidunt, mi nec tincidunt tristique, ex nulla lobortis sem, sit amet finibus purus justo non massa.",
    rgba(0, 0, 0, 255),
    bounds = image.wh
  )

  doDiff(image, "paragraph")
