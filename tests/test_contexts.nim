import chroma, pixie, xrays

block:
  let ctx = newContext(newImage(300, 160))

  ctx.beginPath()
  ctx.fillStyle = "#ff6"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.beginPath()
  ctx.fillStyle = "blue"
  ctx.moveTo(20, 20)
  ctx.lineTo(180, 20)
  ctx.lineTo(130, 130)
  ctx.closePath()
  ctx.fill()

  ctx.clearRect(10, 10, 120, 100)

  ctx.image.xray("tests/contexts/clearRect_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.strokeStyle = "blue"
  ctx.moveTo(20, 20)
  ctx.lineTo(200, 20)
  ctx.stroke()

  ctx.beginPath()
  ctx.strokeStyle = "green"
  ctx.moveTo(20, 20)
  ctx.lineTo(120, 120)
  ctx.stroke()

  ctx.image.xray("tests/contexts/beginPath_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(50, 50)
  ctx.lineTo(200, 50)
  ctx.moveTo(50, 90)
  ctx.lineTo(280, 120)
  ctx.stroke()

  ctx.image.xray("tests/contexts/moveTo_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  let region = newPath()
  region.moveTo(30, 90)
  region.lineTo(110, 20)
  region.lineTo(240, 130)
  region.lineTo(60, 130)
  region.lineTo(190, 20)
  region.lineTo(270, 90)
  region.closePath()

  ctx.fillStyle = "green"
  ctx.fill(region, EvenOdd)

  ctx.image.xray("tests/contexts/fill_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.rect(10, 10, 150, 100)
  ctx.stroke()

  ctx.image.xray("tests/contexts/stroke_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.lineWidth = 26
  ctx.strokeStyle = "orange"
  ctx.moveTo(20, 20)
  ctx.lineTo(160, 20)
  ctx.stroke()

  ctx.lineWidth = 14
  ctx.strokeStyle = "green"
  ctx.moveTo(20, 80)
  ctx.lineTo(220, 80)
  ctx.stroke()

  ctx.lineWidth = 4
  ctx.strokeStyle = "pink"
  ctx.moveTo(20, 140)
  ctx.lineTo(280, 140)
  ctx.stroke()

  ctx.image.xray("tests/contexts/stroke_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.lineWidth = 26
  ctx.strokeStyle = "red"

  ctx.beginPath()
  ctx.rect(25, 25, 100, 100)
  ctx.fill()
  ctx.stroke()

  ctx.beginPath()
  ctx.rect(175, 25, 100, 100)
  ctx.stroke()
  ctx.fill()

  ctx.image.xray("tests/contexts/stroke_3.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(20, 140)
  ctx.lineTo(120, 10)
  ctx.lineTo(220, 140)
  ctx.closePath()
  ctx.stroke()

  ctx.image.xray("tests/contexts/closePath_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  let
    start = vec2(50, 20)
    cp1 = vec2(230, 30)
    cp2 = vec2(150, 80)
    to = vec2(250, 100)

  ctx.beginPath()
  ctx.moveTo(start)
  ctx.bezierCurveTo(cp1, cp2, to)
  ctx.stroke()

  ctx.image.xray("tests/contexts/bezierCurveTo_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(30, 30)
  ctx.bezierCurveTo(120, 160, 180, 10, 220, 140)
  ctx.stroke()

  ctx.image.xray("tests/contexts/bezierCurveTo_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.moveTo(50, 20)
  ctx.quadraticCurveTo(230, 30, 50, 100)
  ctx.stroke()

  ctx.image.xray("tests/contexts/quadracticCurveTo_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(20, 110)
  ctx.quadraticCurveTo(230, 150, 250, 20)
  ctx.stroke()

  ctx.image.xray("tests/contexts/quadracticCurveTo_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.ellipse(100, 75, 75, 50)
  ctx.stroke()

  ctx.image.xray("tests/contexts/ellipse_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.strokeStyle = "green"
  ctx.strokeRect(20, 10, 160, 100)

  ctx.image.xray("tests/contexts/strokeRect_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.lineJoin = BevelJoin
  ctx.lineWidth = 15
  ctx.strokeStyle = "#38f"
  ctx.strokeRect(30, 30, 160, 90)

  ctx.image.xray("tests/contexts/strokeRect_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.setTransform(mat3(1, 0.2, 0, 0.8, 1, 0, 0, 0, 1))
  ctx.fillRect(0, 0, 100, 100)

  ctx.image.xray("tests/contexts/setTransform_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.setTransform(mat3(1, 0.2, 0, 0.8, 1, 0, 0, 0, 1))
  ctx.fillRect(0, 0, 100, 100)

  ctx.image.xray("tests/contexts/resetTransform_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.rotate(45 * PI / 180)
  ctx.fillRect(60, 0, 100, 30)

  ctx.image.xray("tests/contexts/resetTransform_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.transform(mat3(1, 0, 0, 1.7, 1, 0, 0, 0, 1))
  ctx.fillStyle = "gray"
  ctx.fillRect(40, 40, 50, 20)
  ctx.fillRect(40, 90, 50, 20)

  ctx.resetTransform()
  ctx.fillStyle = "red"
  ctx.fillRect(40, 40, 50, 20)
  ctx.fillRect(40, 90, 50, 20)

  ctx.image.xray("tests/contexts/resetTransform_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.translate(110, 30)
  ctx.fillStyle = "red"
  ctx.fillRect(0, 0, 80, 80)

  ctx.setTransform(mat3(1, 0, 0, 0, 1, 0, 0, 0, 1))

  ctx.fillStyle = "gray"
  ctx.fillRect(0, 0, 80, 80)

  ctx.image.xray("tests/contexts/translate_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.scale(9, 3)
  ctx.fillStyle = "red"
  ctx.fillRect(10, 10, 8, 20)

  ctx.setTransform(mat3(1, 0, 0, 0, 1, 0, 0, 0, 1))

  ctx.fillStyle = "gray"
  ctx.fillRect(10, 10, 8, 20)

  ctx.image.xray("tests/contexts/scale_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.fillStyle = "gray"
  ctx.fillRect(100, 0, 80, 20)

  ctx.rotate(45 * PI / 180)
  ctx.fillStyle = "red"
  ctx.fillRect(100, 0, 80, 20)

  ctx.image.xray("tests/contexts/rotate_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.font = "tests/fonts/Roboto-Regular_1.ttf"
  ctx.fontSize = 50
  ctx.save()
  ctx.fontSize = 30
  ctx.restore()

  ctx.fillText("Hello world", 50, 90)

  ctx.image.xray("tests/contexts/fillText_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.font = "tests/fonts/Roboto-Regular_1.ttf"
  ctx.fontSize = 50

  ctx.strokeText("Hello world", 50, 90)

  ctx.image.xray("tests/contexts/strokeText_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.save()

  ctx.fillStyle = "green"
  ctx.fillRect(10, 10, 100, 100)

  ctx.restore()

  ctx.fillRect(150, 40, 100, 100)

  ctx.image.xray("tests/contexts/save_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.circle(100, 75, 50)
  ctx.clip()

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)
  ctx.fillStyle = "orange"
  ctx.fillRect(0, 0, 100, 100)

  ctx.image.xray("tests/contexts/clip_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.beginPath()
  ctx.circle(100, 75, 50)
  ctx.clip()

  ctx.fillStyle = "red"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)
  ctx.fillStyle = "orange"
  ctx.fillRect(0, 0, 100, 100)

  ctx.image.xray("tests/contexts/clip_1b.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.save()

  ctx.beginPath()
  ctx.circle(100, 75, 50)
  ctx.clip()

  ctx.fillStyle = "red"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)
  ctx.fillStyle = "orange"
  ctx.fillRect(0, 0, 100, 100)

  ctx.restore()

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.image.xray("tests/contexts/clip_1c.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.beginPath()
  ctx.circle(100, 75, 50)
  ctx.clip()

  ctx.saveLayer()

  ctx.fillStyle = "red"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)
  ctx.fillStyle = "orange"
  ctx.fillRect(0, 0, 100, 100)

  ctx.restore()

  ctx.image.xray("tests/contexts/clip_1d.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.save()

  ctx.beginPath()
  ctx.circle(100, 75, 50)
  ctx.clip()

  ctx.saveLayer()

  ctx.fillStyle = "red"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)
  ctx.fillStyle = "orange"
  ctx.fillRect(0, 0, 100, 100)

  ctx.restore() # Pop the layer
  ctx.restore() # Pop the clip

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.image.xray("tests/contexts/clip_1e.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.save()

  ctx.beginPath()
  ctx.circle(100, 75, 50)
  ctx.clip()

  ctx.saveLayer()

  ctx.fillStyle = "red"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.restore()
  ctx.saveLayer()

  ctx.fillStyle = "orange"
  ctx.fillRect(0, 0, 100, 100)

  ctx.restore() # Pop the layer

  ctx.image.xray("tests/contexts/clip_1f.png")

block:
  let ctx = newContext(newImage(300, 150))

  let region = newPath()
  region.rect(80, 10, 20, 130)
  region.rect(40, 50, 100, 50)
  ctx.clip(region, EvenOdd)

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.image.xray("tests/contexts/clip_2.png")

block:
  let image = newImage(300, 150)

  let ctx = newContext(image)

  var circlePath = newPath()
  circlePath.circle(150, 75, 75)
  var squarePath = newPath()
  squarePath.rect(85, 10, 130, 130)

  ctx.clip(circlePath)
  ctx.clip(squarePath)

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  image.xray("tests/contexts/clip_3.png")

block:
  let image = newImage(300, 150)

  let ctx = newContext(image)
  ctx.font = "tests/fonts/Roboto-Regular_1.ttf"
  ctx.fontSize = 50
  ctx.fillStyle = "blue"

  ctx.saveLayer()

  var circlePath = newPath()
  circlePath.circle(150, 75, 75)

  ctx.clip(circlePath)

  ctx.fillText("Hello world", 50, 90)

  ctx.restore()

  image.xray("tests/contexts/clip_text.png")

block:
  let ctx = newContext(100, 100)
  ctx.font = "tests/fonts/Roboto-Regular_1.ttf"

  let metrics = ctx.measureText("Hello world")
  doAssert metrics.width == 60

block:
  let
    image = newImage(300, 150)
    ctx = newContext(image)

  var y = 15.float32

  proc drawDashedLine(pattern: seq[float32]) =
    ctx.beginPath()
    ctx.setLineDash(pattern)
    ctx.moveTo(0, y)
    ctx.lineTo(300, y)
    ctx.stroke()
    y += 20

  drawDashedLine(@[])
  drawDashedLine(@[1.float32, 1])
  drawDashedLine(@[10.float32, 10])
  drawDashedLine(@[20.float32, 5])
  drawDashedLine(@[15.float32, 3, 3, 3])
  drawDashedLine(@[20.float32, 3, 3, 3, 3, 3, 3, 3])
  drawDashedLine(@[12.float32, 3, 3])

  image.xray("tests/contexts/setLineDash_1.png")

block:
  let
    image = newImage(300, 150)
    ctx = newContext(image)

  image.fill(rgba(255, 255, 255, 255))

  let paint = newPaint(SolidPaint)
  paint.color = color(0, 0, 1, 1)
  paint.blendMode = ExclusionBlend

  ctx.fillStyle = paint

  ctx.fillRect(10, 10, 100, 100)

  image.xray("tests/contexts/blendmode_1.png")

block:
  let
    image = newImage(300, 150)
    ctx = newContext(image)

  image.fill(rgba(255, 255, 255, 255))

  ctx.globalAlpha = 0.5

  ctx.fillStyle = "blue"
  ctx.fillRect(10, 10, 100, 100)

  ctx.fillStyle = "red"
  ctx.fillRect(50, 50, 100, 100)

  image.xray("tests/contexts/globalAlpha_1.png")

block:
  let
    image = newImage(100, 100)
    ctx = newContext(image)
    testImage = readImage("tests/images/pip1.png")
  ctx.drawImage(testImage, 0, 0)
  ctx.drawImage(testImage, 30, 30)
  image.xray("tests/contexts/draw_image.png")

block:
  let
    image = newImage(100, 100)
    ctx = newContext(image)
    testImage = readImage("tests/images/pip1.png")
  ctx.translate(30, 30)
  ctx.drawImage(testImage, -30, -30)
  ctx.drawImage(testImage, 0, 0)
  image.xray("tests/contexts/draw_image_translated.png")

block:
  let
    image = newImage(100, 100)
    ctx = newContext(image)
    testImage = readImage("tests/images/pip1.png")
  ctx.scale(2, 2)
  ctx.drawImage(testImage, 0, 0)
  ctx.scale(0.25, 0.25)
  ctx.drawImage(testImage, 0, 0)
  image.xray("tests/contexts/draw_image_scaled.png")

block:
  let
    image = newImage(100, 100)
    ctx = newContext(image)
    testImage = readImage("tests/images/pip1.png")
  ctx.drawImage(testImage, 30, 30, 20, 20)
  image.xray("tests/contexts/draw_image_self_scaled.png")

block:
  let
    image = newImage(300, 227)
    ctx = newContext(image)
    rhino = readImage("tests/images/rhino.png")
  ctx.drawImage(rhino, 33, 71, 104, 124, 21, 20, 87, 104)
  image.xray("tests/contexts/draw_image_rhino.png")

block:
  let
    image = newImage(300, 227)
    ctx = newContext(image)
    rhino = readImage("tests/images/rhino.png")
  ctx.drawImage(rhino, rect(33, 71, 104, 124), rect(21, 20, 87, 104))
  image.xray("tests/contexts/draw_image_rhino2.png")

block:
  let
    image = newImage(100, 100)
    ctx = newContext(image)
  ctx.rect(10, 10, 100, 100)
  doAssert ctx.isPointInPath(30, 70)

block:
  let
    image = newImage(300, 150)
    ctx = newContext(image)
  ctx.arc(150, 75, 50, 0, 2 * PI)
  doAssert ctx.isPointInPath(150, 50)

block:
  let
    image = newImage(100, 100)
    ctx = newContext(image)
  ctx.rect(10, 10, 100, 100)
  doAssert ctx.isPointInStroke(50, 10)

block:
  let
    image = newImage(300, 150)
    ctx = newContext(image)
  ctx.ellipse(150, 75, 40, 60)
  ctx.lineWidth = 25
  doAssert ctx.isPointInStroke(110, 75)

block:
  let ctx = newContext(newImage(100, 100))
  ctx.fillStyle.color = color(1, 0, 0, 1)
  ctx.save()
  ctx.fillStyle.color = color(0, 0, 1, 1)
  ctx.restore()
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)
  ctx.image.xray("tests/contexts/paintSaveRestore.png")

block:
  # From https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/textBaseline
  let
    image = newImage(550, 500)
    ctx = newContext(image)
  image.fill(rgba(255, 255, 255, 255))

  const baselines = @[
    TopBaseline,
    HangingBaseline,
    MiddleBaseline,
    AlphabeticBaseline,
    IdeographicBaseline,
    BottomBaseline,
  ]

  ctx.font = "tests/fonts/Roboto-Regular_1.ttf"
  ctx.fontSize = 28
  ctx.strokeStyle = "red"

  for index, baseline in baselines:
    ctx.textBaseline = baseline
    let y = (75 + index * 75).float32
    ctx.beginPath()
    ctx.moveTo(0, y + 0.5)
    ctx.lineTo(550, y + 0.5)
    ctx.stroke()
    ctx.fillText("Abcdefghijklmnop (" & $baseline & ")", 0, y)

  ctx.image.xray("tests/contexts/textBaseline_1.png")
