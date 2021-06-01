import pixie, pixie/fileformats/png, strformat

proc doDiff(rendered: Image, name: string) =
  rendered.writeFile(&"tests/fonts/rendered/{name}.png")
  let
    master = readImage(&"tests/fonts/masters/{name}.png")
    (diffScore, diffImage) = diff(master, rendered)
  echo &"{name} score: {diffScore}"
  diffImage.writeFile(&"tests/fonts/diffs/{name}.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let bounds = font.computeBounds("Word")
  doAssert bounds == vec2(57, 28)

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "fill")
  image.writeFile("tests/fonts/image_fill.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.strokeText(font, "stroke")
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

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "asdf")

  doDiff(image, "basic1")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A cow")

  doDiff(image, "basic2")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A bit of text HERE")

  doDiff(image, "basic3")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.lineHeight = 100

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Line height")

  doDiff(image, "basic4")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Another font")

  doDiff(image, "basic5")

block:
  var font = readFont("tests/fonts/Aclonica-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Different font")

  doDiff(image, "basic6")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "First line")
  image.fillText(font, "Second line", vec2(0, font.defaultLineHeight))

  doDiff(image, "basic7")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to new line",
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
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph1_{i + 1}" else: "paragraph1"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 16
  font.noKerningAdjustments = true

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      bounds = image.wh
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
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph2_{i + 1}" else: "paragraph2"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 16
  font.noKerningAdjustments = true

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      bounds = image.wh
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
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph3_{i + 1}" else: "paragraph3"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
  font.size = 16
  font.noKerningAdjustments = true

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      bounds = image.wh
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
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph4_{i + 1}" else: "paragraph4"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/NotoSans-Regular_4.ttf")
  font.size = 16
  font.noKerningAdjustments = true

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      bounds = image.wh
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
      bounds = image.wh
    )

    let name = if i > 0: &"paragraph5_{i + 1}" else: "paragraph5"
    doDiff(image, name)

block:
  var font = readFont("tests/fonts/Pacifico-Regular_4.ttf")
  font.size = 16
  font.noKerningAdjustments = true

  let image = newImage(1000, 150)

  for i, text in paragraphs:
    image.fill(rgba(255, 255, 255, 255))
    image.fillText(
      font,
      text,
      bounds = image.wh
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
    bounds = image.wh
  )

  doDiff(image, "huge1")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 200
  font.noKerningAdjustments = true

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    bounds = image.wh
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
    bounds = image.wh
  )

  doDiff(image, "huge2")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 200
  font.noKerningAdjustments = true

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    bounds = image.wh
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
    bounds = image.wh
  )

  doDiff(image, "huge3")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 200
  font.noKerningAdjustments = true

  let image = newImage(2800, 400)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to the next line",
    bounds = image.wh
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
    bounds = image.wh
  )

  doDiff(image, "pairs3")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 18

  let image = newImage(200, 150)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    """First line
Second line
Third line
Fourth line
Fifth line
Sixth line
Seventh line""",
    bounds = image.wh
  )

  doDiff(image, "lines1")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 18
  font.lineHeight = 30

  let image = newImage(200, 150)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    """First line
Second line
Third line
Fourth line
Fifth line""",
    bounds = image.wh
  )

  doDiff(image, "lines2")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 36

  let image = newImage(800, 800)
  image.fill(rgba(255, 255, 255, 255))

  image.fillText(
    font,
    "TopLeft",
    bounds = image.wh,
    hAlign = haLeft,
    vAlign = vaTop
  )

  image.fillText(
    font,
    "TopCenter",
    bounds = image.wh,
    hAlign = haCenter,
    vAlign = vaTop
  )

  image.fillText(
    font,
    "TopRight",
    bounds = image.wh,
    hAlign = haRight,
    vAlign = vaTop
  )

  image.fillText(
    font,
    "MiddleLeft",
    bounds = image.wh,
    hAlign = haLeft,
    vAlign = vaMiddle
  )

  image.fillText(
    font,
    "MiddleCenter",
    bounds = image.wh,
    hAlign = haCenter,
    vAlign = vaMiddle
  )

  image.fillText(
    font,
    "MiddleRight",
    bounds = image.wh,
    hAlign = haRight,
    vAlign = vaMiddle
  )

  image.fillText(
    font,
    "BottomLeft",
    bounds = image.wh,
    hAlign = haLeft,
    vAlign = vaBottom
  )

  image.fillText(
    font,
    "BottomCenter",
    bounds = image.wh,
    hAlign = haCenter,
    vAlign = vaBottom
  )

  image.fillText(
    font,
    "BottomRight",
    bounds = image.wh,
    hAlign = haRight,
    vAlign = vaBottom
  )

  doDiff(image, "alignments")

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
  font.size = 48
  font.paint = Paint(
    kind: pkGradientLinear,
    gradientHandlePositions: @[
      vec2(0, 50),
      vec2(100, 50),
    ],
    gradientStops: @[
      ColorStop(color: rgba(255, 0, 0, 255), position: 0),
      ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
    ]
  )

  let image = newImage(100, 100)
  image.fillText(font, "Text")

  image.writeFile("tests/fonts/image_paint_fill.png")

block:
  var font1 = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font1.size = 80

  var font2 = readFont("tests/fonts/Aclonica-Regular_1.ttf")
  font2.size = 100

  var font3 = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font3.size = 48

  let spans = @[
    newSpan("One span ", font1),
    newSpan("Two span", font2),
    newSpan(" Three span", font3)
  ]

  let image = newImage(700, 250)
  image.fill(rgba(255, 255, 255, 255))

  let arrangement = typeset(spans, bounds = image.wh)

  image.fillText(arrangement)

  doDiff(image, "spans1")

  let ctx = newContext(image)
  ctx.fillStyle = rgba(128, 128, 128, 128)
  for i, rect in arrangement.selectionRects:
    ctx.fillRect(rect)

  doDiff(image, "selection_rects1")

block:
  var font1 = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font1.size = 80

  var font2 = readFont("tests/fonts/Aclonica-Regular_1.ttf")
  font2.size = 100

  var font3 = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font3.size = 48

  let spans = @[
    newSpan("One span ", font1),
    newSpan("Two span", font2),
    newSpan(" Three span", font3)
  ]

  let image = newImage(475, 400)
  image.fill(rgba(255, 255, 255, 255))

  let arrangement = typeset(spans, bounds = image.wh)

  image.fillText(arrangement)

  doDiff(image, "spans2")

  let ctx = newContext(image)
  ctx.fillStyle = rgba(128, 128, 128, 128)
  for i, rect in arrangement.selectionRects:
    ctx.fillRect(rect)

  doDiff(image, "selection_rects2")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 16

  let image = newImage(75, 75)
  image.fill(rgba(255, 255, 255, 255))

  let arrangement = typeset(
    font, "Wrapping text to new line", bounds = image.wh
  )

  image.fillText(arrangement)

  let ctx = newContext(image)
  ctx.fillStyle = rgba(128, 128, 128, 128)
  for i, rect in arrangement.selectionRects:
    ctx.fillRect(rect)

  doDiff(image, "selection_rects3")

block:
  let
    roboto = readFont("tests/fonts/Roboto-Regular_1.ttf")
    aclonica = readFont("tests/fonts/Aclonica-Regular_1.ttf")
    ubuntu = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
    ibm = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
    noto = readFont("tests/fonts/NotoSans-Regular_4.ttf")

  var font1 = roboto
  font1.size = 64

  var font2 = aclonica
  font2.size = 80

  var font3 = ibm
  font3.size = 40

  var font4 = ubuntu
  font4.size = 56

  var font5 = noto
  font5.size = 72

  var font6 = roboto
  font6.size = 48

  var font7 = noto
  font7.size = 64

  var font8 = ubuntu
  font8.size = 54
  font8.paint.color = rgba(255, 0, 0, 255)

  var font9 = roboto
  font9.size = 48

  var font10 = aclonica
  font10.size = 48
  font10.lineHeight = 120

  let spans = @[
    newSpan("Using spans, ", font1),
    newSpan("Pixie ", font2),
    newSpan("can arrange and rasterize ", font3),
    newSpan("very complex text layouts. ", font4),
    newSpan("Spans", font5),
    newSpan(" can have different ", font6),
    newSpan("font sizes,", font7),
    newSpan(" colors", font8),
    newSpan(" and ", font9),
    newSpan("line heights.", font10)
  ]

  let image = newImage(600, 600)
  image.fill(rgba(255, 255, 255, 255))

  let arrangement = typeset(spans, bounds = image.wh)

  image.fillText(arrangement)

  doDiff(image, "spans4")

block:
  let ubuntu = readFont("tests/fonts/Ubuntu-Regular_1.ttf")

  var font1 = ubuntu
  font1.size = 15
  font1.paint = "#CACACA"

  var font2 = ubuntu
  font2.size = 84

  var font3 = ubuntu
  font3.size = 18
  font3.paint = "#007FF4"

  var font4 = ubuntu
  font4.size = 20
  font4.paint = "#4F4F4F"

  let spans = @[
    newSpan("verb [with object] ", font1),
    newSpan("strallow\n", font2),
    newSpan("\nstral·low\n", font3),
    newSpan("\n1. free (something) from restrictive restrictions \"the regulations are intended to strallow changes in public policy\" ", font4)
  ]

  let image = newImage(400, 400)
  image.fill(rgba(255, 255, 255, 255))

  let arrangement = typeset(spans, bounds = vec2(360, 360))

  image.fillText(arrangement, vec2(20, 20))

  doDiff(image, "spans5")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.underline = true

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to new line",
    bounds = vec2(200, 0)
  )

  doDiff(image, "underline1")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.underline = true
  font.paint = rgba(0, 0, 0, 127)

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to new line",
    bounds = vec2(200, 0)
  )

  doDiff(image, "underline2")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.underline = true

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.strokeText(
    font,
    "Wrapping text to new line",
    bounds = vec2(200, 0)
  )

  doDiff(image, "underline3")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.strikethrough = true

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to new line",
    bounds = vec2(200, 0)
  )

  doDiff(image, "strikethrough1")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.strikethrough = true
  font.paint = rgba(0, 0, 0, 127)

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to new line",
    bounds = vec2(200, 0)
  )

  doDiff(image, "strikethrough2")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.strikethrough = true

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.strokeText(
    font,
    "Wrapping text to new line",
    bounds = vec2(200, 0)
  )

  doDiff(image, "strikethrough3")

block:
  let ubuntu = readFont("tests/fonts/Ubuntu-Regular_1.ttf")

  var font1 = ubuntu
  font1.size = 15
  font1.paint = "#CACACA"

  var font2 = ubuntu
  font2.size = 84

  var font3 = ubuntu
  font3.size = 18
  font3.paint = "#007FF4"

  var font4 = ubuntu
  font4.size = 20
  font4.paint = "#4F4F4F"

  var font5 = ubuntu
  font5.size = 20
  font5.paint = "#4F4F4F"
  font5.underline = true

  var font6 = ubuntu
  font6.size = 20
  font6.paint = "#4F4F4F"
  font6.strikethrough = true

  let spans = @[
    newSpan("verb [with object] ", font1),
    newSpan("strallow\n", font2),
    newSpan("\nstral·low\n", font3),
    newSpan("\n1. free (something) from ", font4),
    newSpan("restrictive restrictions", font5),
    newSpan(" ", font4),
    newSpan("\"the regulations are intended to strallow changes in public policy\" ", font6)
  ]

  let image = newImage(400, 400)
  image.fill(rgba(255, 255, 255, 255))

  let arrangement = typeset(spans, bounds = vec2(360, 360))

  image.fillText(arrangement, vec2(20, 20))

  doDiff(image, "spans6")
