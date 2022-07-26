import os, pixie, strformat, unicode, xrays

proc wh(image: Image): Vec2 =
  ## Return with and height as a size vector.
  vec2(image.width.float32, image.height.float32)

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let bounds = font.layoutBounds("Word")
  doAssert bounds == vec2(56, 28)

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let bounds = font.layoutBounds("Word\n")
  doAssert bounds == vec2(56, 56)

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "fill")

  image.xray("tests/fonts/masters/image_fill.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 64
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.strokeText(font, "stroke")

  image.xray("tests/fonts/masters/image_stroke.png")

block:
  # SVG Fonts have no masters
  block:
    var font = readFont("tests/fonts/Changa-Bold.svg")
    font.size = 48
    let image = newImage(200, 100)
    image.fillText(font, "Changa")
    image.xray("tests/fonts/svg_changa.png")

  block:
    var font = readFont("tests/fonts/DejaVuSans.svg")
    font.size = 48
    let image = newImage(200, 100)
    image.fillText(font, "Deja vu ")
    image.xray("tests/fonts/svg_dejavu.png")

  block:
    var font = readFont("tests/fonts/IBMPlexSans-Regular.svg")
    font.size = 48
    let image = newImage(200, 100)
    image.fillText(font, "IBM ")
    image.xray("tests/fonts/svg_ibm.png")

  block:
    var font = readFont("tests/fonts/Moon-Bold.svg")
    font.size = 48
    let image = newImage(200, 100)
    image.fillText(font, "Moon ")
    image.xray("tests/fonts/svg_moon.png")

  block:
    var font = readFont("tests/fonts/Ubuntu.svg")
    font.size = 48
    let image = newImage(200, 100)
    image.fillText(font, "Ubuntu ")
    image.xray("tests/fonts/svg_ubuntu.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "asdf")

  image.xray("tests/fonts/masters/basic1.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 72

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A cow")

  image.xray("tests/fonts/masters/basic2.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "A bit of text HERE")

  image.xray("tests/fonts/masters/basic3.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24
  font.lineHeight = 100

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Line height")

  image.xray("tests/fonts/masters/basic4.png")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Another font")

  image.xray("tests/fonts/masters/basic5.png")

block:
  var font = readFont("tests/fonts/Aclonica-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Different font")

  image.xray("tests/fonts/masters/basic6.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "First line")
  image.fillText(
    font, "Second line", translate(vec2(0, font.defaultLineHeight))
  )

  image.xray("tests/fonts/masters/basic7.png")

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

  image.xray("tests/fonts/masters/basic8.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Long words: Supercalifragilisticexpialidocious\nAntidisestablishmentarianism",
    bounds = vec2(100, 0)
  )

  image.xray("tests/fonts/masters/basic8b.png")

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

  image.xray("tests/fonts/masters/basic9.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 24

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "a b c d e f g h i j k l m n o p",
    bounds = vec2(200, 0),
    hAlign = RightAlign
  )

  image.xray("tests/fonts/masters/basic10.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

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
    image.xray(&"tests/fonts/masters/{name}.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 100

  let image = newImage(1400, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/huge1.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 100
  font.noKerningAdjustments = true

  let image = newImage(1400, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/huge1_nokern.png")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 100

  let image = newImage(1400, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/huge2.png")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 100
  font.noKerningAdjustments = true

  let image = newImage(1400, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Shehadcometotheconclusion",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/huge2_nokern.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 100

  let image = newImage(1400, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to the next line",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/huge3.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 100
  font.noKerningAdjustments = true

  let image = newImage(1400, 200)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Wrapping text to the next line",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/huge3_nokern.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 50

  let image = newImage(1400, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "HA HT HX HY IA IT IX IY MA MT MX MY NA NT NX NY",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/pairs1.png")

block:
  var font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")
  font.size = 50

  let image = newImage(1400, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "V( V) V- V/ V: v; v? v@ VT VV VW VX VY V] Vu Vz V{",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/pairs2.png")

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
  font.size = 50

  let image = newImage(1400, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "B, B. BA BJ BT BW BY Bf Bg Bt bw By",
    bounds = image.wh
  )

  image.xray("tests/fonts/masters/pairs3.png")

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

  image.xray("tests/fonts/masters/lines1.png")

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

  image.xray("tests/fonts/masters/lines2.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 36

  let image = newImage(800, 800)
  image.fill(rgba(255, 255, 255, 255))

  image.fillText(
    font,
    "TopLeft",
    bounds = image.wh,
    hAlign = LeftAlign,
    vAlign = TopAlign
  )

  image.fillText(
    font,
    "TopCenter",
    bounds = image.wh,
    hAlign = CenterAlign,
    vAlign = TopAlign
  )

  image.fillText(
    font,
    "TopRight",
    bounds = image.wh,
    hAlign = RightAlign,
    vAlign = TopAlign
  )

  image.fillText(
    font,
    "MiddleLeft",
    bounds = image.wh,
    hAlign = LeftAlign,
    vAlign = MiddleAlign
  )

  image.fillText(
    font,
    "MiddleCenter",
    bounds = image.wh,
    hAlign = CenterAlign,
    vAlign = MiddleAlign
  )

  image.fillText(
    font,
    "MiddleRight",
    bounds = image.wh,
    hAlign = RightAlign,
    vAlign = MiddleAlign
  )

  image.fillText(
    font,
    "BottomLeft",
    bounds = image.wh,
    hAlign = LeftAlign,
    vAlign = BottomAlign
  )

  image.fillText(
    font,
    "BottomCenter",
    bounds = image.wh,
    hAlign = CenterAlign,
    vAlign = BottomAlign
  )

  image.fillText(
    font,
    "BottomRight",
    bounds = image.wh,
    hAlign = RightAlign,
    vAlign = BottomAlign
  )

  image.xray("tests/fonts/masters/alignments.png")

block:
  var font = readFont("tests/fonts/IBMPlexSans-Regular_2.ttf")
  font.size = 48
  font.paint = newPaint(LinearGradientPaint)
  font.paint.gradientHandlePositions = @[
    vec2(0, 50),
    vec2(100, 50),
  ]
  font.paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.5), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Text")

  image.xray("tests/fonts/masters/image_paint_fill.png")

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

  image.xray("tests/fonts/masters/spans1.png")

  let ctx = newContext(image)
  ctx.fillStyle = rgba(127, 127, 127, 127)
  for i, rect in arrangement.selectionRects:
    ctx.fillRect(rect)

  image.xray("tests/fonts/masters/selection_rects1.png")

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

  image.xray("tests/fonts/masters/spans2.png")

  let ctx = newContext(image)
  ctx.fillStyle = rgba(127, 127, 127, 127)
  for i, rect in arrangement.selectionRects:
    ctx.fillRect(rect)

  image.xray("tests/fonts/masters/selection_rects2.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 16

  let image = newImage(75, 75)
  image.fill(rgba(255, 255, 255, 255))

  let arrangement = typeset(
    font, "Wrapping text to the next line", bounds = image.wh
  )

  image.fillText(arrangement)

  let ctx = newContext(image)
  ctx.fillStyle = rgba(127, 127, 127, 127)
  for i, rect in arrangement.selectionRects:
    ctx.fillRect(rect)

  image.xray("tests/fonts/masters/selection_rects3.png")

block:
  let
    roboto = readTypeface("tests/fonts/Roboto-Regular_1.ttf")
    aclonica = readTypeface("tests/fonts/Aclonica-Regular_1.ttf")
    ubuntu = readTypeface("tests/fonts/Ubuntu-Regular_1.ttf")
    ibm = readTypeface("tests/fonts/IBMPlexSans-Regular_2.ttf")
    noto = readTypeface("tests/fonts/NotoSans-Regular_4.ttf")

  var font1 = newFont(roboto)
  font1.size = 64

  var font2 = newFont(aclonica)
  font2.size = 80

  var font3 = newFont(ibm)
  font3.size = 40

  var font4 = newFont(ubuntu)
  font4.size = 56

  var font5 = newFont(noto)
  font5.size = 72

  var font6 = newFont(roboto)
  font6.size = 48

  var font7 = newFont(noto)
  font7.size = 64

  var font8 = newFont(ubuntu)
  font8.size = 54
  font8.paint.color = color(1, 0, 0, 1)

  var font9 = newFont(roboto)
  font9.size = 48

  var font10 = newFont(aclonica)
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

  image.xray("tests/fonts/masters/spans4.png")

block:
  let ubuntu = readTypeface("tests/fonts/Ubuntu-Regular_1.ttf")

  var font1 = newFont(ubuntu)
  font1.size = 15
  font1.paint = "#CACACA"

  var font2 = newFont(ubuntu)
  font2.size = 84

  var font3 = newFont(ubuntu)
  font3.size = 18
  font3.paint = "#007FF4"

  var font4 = newFont(ubuntu)
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

  image.fillText(arrangement, translate(vec2(20, 20)))

  image.xray("tests/fonts/masters/spans5.png")

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

  image.xray("tests/fonts/masters/underline1.png")

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

  image.xray("tests/fonts/masters/underline2.png")

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

  image.xray("tests/fonts/masters/underline3.png")

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

  image.xray("tests/fonts/masters/strikethrough1.png")

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

  image.xray("tests/fonts/masters/strikethrough2.png")

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

  image.xray("tests/fonts/masters/strikethrough3.png")

block:
  let ubuntu = readTypeface("tests/fonts/Ubuntu-Regular_1.ttf")

  var font1 = newFont(ubuntu)
  font1.size = 15
  font1.paint = "#CACACA"

  var font2 = newFont(ubuntu)
  font2.size = 84

  var font3 = newFont(ubuntu)
  font3.size = 18
  font3.paint = "#007FF4"

  var font4 = newFont(ubuntu)
  font4.size = 20
  font4.paint = "#4F4F4F"

  var font5 = newFont(ubuntu)
  font5.size = 20
  font5.paint = "#4F4F4F"
  font5.underline = true

  var font6 = newFont(ubuntu)
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

  image.fillText(arrangement, translate(vec2(20, 20)))

  image.xray("tests/fonts/masters/spans6.png")

block:

  let typeface1 = readTypeface("tests/fonts/PinyonScript.ttf")

  var font1 = newFont(typeface1)
  font1.size = 82
  font1.lineHeight = 60
  font1.paint = "#000000"

  let spans = @[
    newSpan("Fancy text", font1),
  ]

  let image = newImage(400, 400)
  image.fill(rgba(255, 255, 255, 255))
  let ctx = newContext(image)
  ctx.fillStyle = "#FFD6D6"
  ctx.fillRect(rect(40, 170, 320, 60))

  let
    arrangement = typeset(spans, bounds = vec2(320, 60))
    snappedBounds = arrangement.computeBounds().snapToPixels()
    textImage = newImage(snappedBounds.w.int, snappedBounds.h.int)
  textImage.fillText(arrangement, translate(-snappedBounds.xy))

  image.draw(textImage, translate(snappedBounds.xy + vec2(40, 170)))

  # Enable this to show bounds
  # ctx.strokeStyle = "#FF0000"
  # ctx.translate(vec2(40, 170))
  # ctx.strokeRect(arrangement.computeBounds())

  # Enable this to show how text is drawing directly
  # image.fillText(arrangement, translate(vec2(40, 170)))

  image.xray("tests/fonts/masters/spans7.png")

block:
  var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  font.size = 36

  var paints: seq[Paint]
  paints.add(rgba(0, 0, 255, 127))
  paints.add(rgba(255, 0, 0, 127))

  font.paints = paints

  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    "Multiple fills",
    bounds = vec2(200, 0)
  )

  image.xray("tests/fonts/masters/paints1.png")

block:
  var typeface = readTypeface("tests/fonts/Roboto-Regular_1.ttf")
  doAssert typeface.getKerningAdjustment('T'.Rune, 'e'.Rune) == -99.0

block:
  var font = readFont("tests/fonts/Inter-Regular.ttf")
  font.size = 26
  let image = newImage(800, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Grumpy wizards make toxic brew for the evil Queen and Jack.")

  image.xray("tests/fonts/masters/cff.png")

block:
  var font = readFont("tests/fonts/NotoSansJP-Regular.ttf")
  font.size = 26
  let image = newImage(800, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "仰コソ会票カク帰了ノ終準港みせス議徳モチタ提請ルまつ力路お")

  image.xray("tests/fonts/masters/cff_jp.png")

block:
  var font = readFont("tests/fonts/Inter-Regular.ttf")
  font.size = 26
  font.underline = true
  let image = newImage(800, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Grumpy wizards make toxic brew for the evil Queen and Jack.")

  image.xray("tests/fonts/masters/cff_underline.png")

block:
  var font = readFont("tests/fonts/Inter-Regular.ttf")
  font.size = 26
  font.strikethrough = true
  let image = newImage(800, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Grumpy wizards make toxic brew for the evil Queen and Jack.")

  image.xray("tests/fonts/masters/cff_strikethrough.png")

block:
  var font = readFont("tests/fonts/Inter-Regular.ttf")
  var typeface = readTypeface("tests/fonts/NotoSansJP-Regular.ttf")
  font.typeface.fallbacks.add(typeface)
  font.size = 26
  let image = newImage(800, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Grumpy ウィザード make 有毒な醸造 for the 悪い女王 and Jack.")

  image.xray("tests/fonts/masters/fallback.png")

block:
  let
    font = readFont("tests/fonts/Inter-Regular.ttf")
    typeface1 = readTypeface("tests/fonts/Aclonica-Regular_1.ttf")
    typeface2 = readTypeface("tests/fonts/Ubuntu-Regular_1.ttf")
    typeface3 = readTypeface("tests/fonts/NotoSansJP-Regular.ttf")

  #  font
  #   |.... typeface1
  #         |.... typeface2
  #         |.... typeface3 (with JP)

  font.typeface.fallbacks.add(typeface1)
  typeface1.fallbacks.add(typeface2)
  typeface1.fallbacks.add(typeface3)

  font.size = 26
  let image = newImage(800, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "Grumpy ウィザード make 有毒な醸造 for the 悪い女王 and Jack.")

  image.xray("tests/fonts/masters/fallback2.png")

block:
  var font = readFont("tests/fonts/Inter-Regular.ttf")

  font.size = 26
  let image = newImage(800, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "This[]Advance!")

  image.xray("tests/fonts/masters/tofu_advance.png")

block:
  let image = newImage(200, 200)
  image.fill(color(1, 1, 1, 1))

  let paint = newPaint(SolidPaint)
  paint.color = color(1, 0, 0, 1)

  let ctx = newContext(image)
  ctx.lineWidth = 1
  ctx.strokeStyle = paint
  ctx.strokeRect(0, 60, 200, 80)

  let text = "AbCd\naBcD"

  let font = pixie.read_font("tests/fonts/Inter-Bold.ttf")
  font.size = 40
  font.line_height = 27

  let arrangement1 = font.typeset(
    text,
    vec2(200, 80),
    CenterAlign,
    TopAlign
  )

  # let p1 = newPath()
  # p1.rect(arrangement1.selectionRects[0])
  # image.fillpath(p1, rgba(196, 196, 196, 255), translate(vec2(0, 266)))

  font.paint.color = color(1, 0, 0, 1)
  image.fillText(arrangement1, translate(vec2(0, 60)))

  let arrangement2 = font.typeset(
    text,
    vec2(200, 80),
    CenterAlign,
    MiddleAlign
  )

  # let p2 = newPath()
  # p2.rect(arrangement2.selectionRects[0])
  # image.fillpath(p2, rgba(196, 196, 196, 255), translate(vec2(0, 266)))

  font.paint.color = color(0, 1, 0, 1)
  image.fillText(arrangement2, translate(vec2(0, 60)))

  font.paint.color = color(0, 0, 1, 1)
  image.fillText(
      font,
      text,
      bounds = vec2(200, 80),
      hAlign = CenterAlign,
      vAlign = BottomAlign,
      transform = translate(vec2(0, 60))
  )

  image.xray("tests/fonts/masters/customlineheight.png")

block:
  var font = readTypefaces("tests/fonts/PTSans.ttc")[0].newFont
  font.size = 72
  let image = newImage(200, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "AbCd")

block:
  var typefaces = readTypefaces("tests/fonts/PTSans.ttc")
  for i, typeface in typefaces:
    echo i, ": ", typeface.name

when defined(windows):
  block:
    let files = @[
      "/Windows/Fonts/batang.ttc",
      "/Windows/Fonts/BIZ-UDGothicB.ttc",
      "/Windows/Fonts/BIZ-UDGothicR.ttc",
      "/Windows/Fonts/BIZ-UDMinchoM.ttc",
      "/Windows/Fonts/cambria.ttc",
      "/Windows/Fonts/gulim.ttc",
      "/Windows/Fonts/meiryo.ttc",
      "/Windows/Fonts/meiryob.ttc",
      "/Windows/Fonts/mingliub.ttc",
      "/Windows/Fonts/msgothic.ttc",
      "/Windows/Fonts/msjh.ttc",
      "/Windows/Fonts/msjhbd.ttc",
      "/Windows/Fonts/msjhl.ttc",
      "/Windows/Fonts/msmincho.ttc",
      "/Windows/Fonts/msyh.ttc",
      "/Windows/Fonts/msyhbd.ttc",
      "/Windows/Fonts/msyhl.ttc",
      "/Windows/Fonts/simsun.ttc",
      "/Windows/Fonts/Sitka.ttc",
      "/Windows/Fonts/SitkaB.ttc",
      "/Windows/Fonts/SitkaI.ttc",
      "/Windows/Fonts/SitkaZ.ttc",
      "/Windows/Fonts/UDDigiKyokashoN-B.ttc",
      "/Windows/Fonts/UDDigiKyokashoN-R.ttc",
      "/Windows/Fonts/YuGothB.ttc",
      "/Windows/Fonts/YuGothL.ttc",
      "/Windows/Fonts/YuGothM.ttc",
      "/Windows/Fonts/YuGothR.ttc",
    ]
    for file in files:
      if fileExists(file):
        echo file
        var typefaces = readTypefaces(file)
        for i, typeface in typefaces:
          echo i, ": ", typeface.name
