import pixie, pixie/fileformats/png, strformat

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "fill", rgba(0, 0, 0, 255))
  image.writeFile("tests/fonts/image_fill.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.strokeText(font, "stroke", rgba(0, 0, 0, 255))
  image.writeFile("tests/fonts/image_stroke.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let mask = newMask(200, 100)
  mask.fillText(font, "fill")
  writeFile("tests/fonts/mask_fill.png", mask.encodePng())

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let mask = newMask(200, 100)
  mask.strokeText(font, "stroke")
  writeFile("tests/fonts/mask_stroke.png", mask.encodePng())

block:
  var font = readFont("tests/fonts/Changa-Bold.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Changa")
  writeFile("tests/fonts/svg_changa.png", mask.encodePng())

block:
  var font = readFont("tests/fonts/DejaVuSans.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Deja vu ")
  writeFile("tests/fonts/svg_dejavu.png", mask.encodePng())

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "IBM ")
  writeFile("tests/fonts/svg_ibm.png", mask.encodePng())

block:
  var font = readFont("tests/fonts/Moon-Bold.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Moon ")
  writeFile("tests/fonts/svg_moon.png", mask.encodePng())

block:
  var font = readFont("tests/fonts/Ubuntu.svg")
  font.size = 48
  let mask = newMask(200, 100)
  mask.fillText(font, "Ubuntu ")
  writeFile("tests/fonts/svg_ubuntu.png", mask.encodePng())

proc doDiff(rendered: Image, name: string) =
  rendered.writeFile(&"tests/fonts/rendered/{name}.png")
  let
    master = readImage(&"tests/fonts/masters/{name}.png")
    (diffScore, diffImage) = diff(master, rendered)
  echo &"{name} score: {diffScore}"
  diffImage.writeFile(&"tests/fonts/diffs/{name}.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "asdf", rgba(0, 0, 0, 255))

  doDiff(image, "basic1")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A cow", rgba(0, 0, 0, 255))

  doDiff(image, "basic2")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A bit of text HERE", rgba(0, 0, 0, 255))

  doDiff(image, "basic3")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.lineHeight = 100

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Line height", rgba(0, 0, 0, 255))

  doDiff(image, "basic4")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Another font", rgba(0, 0, 0, 255))

  doDiff(image, "basic5")

block:
  var font = readFont("tests/fonts/Aclonica-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Different font", rgba(0, 0, 0, 255))

  doDiff(image, "basic6")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
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
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
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
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
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

const
  paragraph = "ShehadcometotheconclusionthatyoucouldtellalotaboutapersonbytheirearsThewaytheystuckoutandthesizeoftheearlobescouldgiveyou"
  paragraph_2 = "She had come to the conclusion that you could tell a lot about a person by their ears The way they stuck out and the size of the earlobes could give you wonderful insights into the person Of course she couldnt scientifically prove any of this but that didnt matter to her Before anything else she would size up the ears of the person she was talking to Shes asked the question so many times that she barely listened to the answers anymore The answers were always the same Well not exactly the same but the same in a general sense A more accurate description was the answers never surprised her"
  paragraph_3 = "She had come to the conclusion that you could tell a lot about a person by their ears The way they stuck out and the size of the earlobes could give you wonderful insights into the person. Of course, she couldn't scientifically prove any of this, but that didn't matter to her. Before anything else, she would size up the ears of the person she was talking to. She's asked the question so many times that she barely listened to the answers anymore. The answers were always the same. Well, not exactly the same, but the same in a general sense. A more accurate description was the answers never surprised her."
  paragraphs = [paragraph, paragraph_2, paragraph_3]

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph1_{i + 1}" else: "paragraph1"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh,
      kerning = false
    )

    let name = if i > 0: &"paragraph1_nokern_{i + 1}" else: "paragraph1_nokern"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph2_{i + 1}" else: "paragraph2"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh,
      kerning = false
    )

    let name = if i > 0: &"paragraph2_nokern_{i + 1}" else: "paragraph2_nokern"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph3_{i + 1}" else: "paragraph3"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh,
      kerning = false
    )

    let name = if i > 0: &"paragraph3_nokern_{i + 1}" else: "paragraph3_nokern"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/NotoSans-Regular_4.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph4_{i + 1}" else: "paragraph4"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/NotoSans-Regular_4.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh,
      kerning = false
    )

    let name = if i > 0: &"paragraph4_nokern_{i + 1}" else: "paragraph4_nokern"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Pacifico-Regular_4.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph5_{i + 1}" else: "paragraph5"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Pacifico-Regular_4.ttf")
  font.size = 16

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      rgba(0, 0, 0, 255),
      bounds = image.wh,
      kerning = false
    )

    let name = if i > 0: &"paragraph5_nokern_{i + 1}" else: "paragraph5_nokern"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 200

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    rgba(0, 0, 0, 255),
    bounds = image.wh
  )

  doDiff(image, "huge1")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 200

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    rgba(0, 0, 0, 255),
    bounds = image.wh,
    kerning = false
  )

  doDiff(image, "huge1_nokern")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 200

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    rgba(0, 0, 0, 255),
    bounds = image.wh
  )

  doDiff(image, "huge2")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 200

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    rgba(0, 0, 0, 255),
    bounds = image.wh,
    kerning = false
  )

  doDiff(image, "huge2_nokern")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 200

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to the next line",
    rgba(0, 0, 0, 255),
    bounds = image.wh
  )

  doDiff(image, "huge3")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 200

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to the next line",
    rgba(0, 0, 0, 255),
    bounds = image.wh,
    kerning = false
  )

  doDiff(image, "huge3_nokern")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 100

  let image = newImage(2800, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "HA HT HX HY IA IT IX IY MA MT MX MY NA NT NX NY",
    rgba(0, 0, 0, 255),
    bounds = image.wh
  )

  doDiff(image, "pairs1")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 100

  let image = newImage(2800, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "V( V) V- V/ V: v; v? v@ VT VV VW VX VY V] Vu Vz V{",
    rgba(0, 0, 0, 255),
    bounds = image.wh
  )

  doDiff(image, "pairs2")

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
  font.size = 100

  let image = newImage(2800, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "B, B. BA BJ BT BW BY Bf Bg Bt bw By",
    rgba(0, 0, 0, 255),
    bounds = image.wh
  )

  doDiff(image, "pairs3")
