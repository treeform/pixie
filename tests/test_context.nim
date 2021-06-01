import chroma, pixie

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

  ctx.image.writeFile("tests/images/context/clearRect_1.png")

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

  ctx.image.writeFile("tests/images/context/beginPath_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(50, 50)
  ctx.lineTo(200, 50)
  ctx.moveTo(50, 90)
  ctx.lineTo(280, 120)
  ctx.stroke()

  ctx.image.writeFile("tests/images/context/moveTo_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  var region: Path
  region.moveTo(30, 90)
  region.lineTo(110, 20)
  region.lineTo(240, 130)
  region.lineTo(60, 130)
  region.lineTo(190, 20)
  region.lineTo(270, 90)
  region.closePath()

  ctx.fillStyle = "green"
  ctx.fill(region, wrEvenOdd)

  ctx.image.writeFile("tests/images/context/fill_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.rect(10, 10, 150, 100)
  ctx.stroke()

  ctx.image.writeFile("tests/images/context/stroke_1.png")

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

  ctx.image.writeFile("tests/images/context/stroke_2.png")

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

  ctx.image.writeFile("tests/images/context/stroke_3.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(20, 140)
  ctx.lineTo(120, 10)
  ctx.lineTo(220, 140)
  ctx.closePath()
  ctx.stroke()

  ctx.image.writeFile("tests/images/context/closePath_1.png")

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

  ctx.image.writeFile("tests/images/context/bezierCurveTo_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(30, 30)
  ctx.bezierCurveTo(120, 160, 180, 10, 220, 140)
  ctx.stroke()

  ctx.image.writeFile("tests/images/context/bezierCurveTo_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.moveTo(50, 20)
  ctx.quadraticCurveTo(230, 30, 50, 100)
  ctx.stroke()

  ctx.image.writeFile("tests/images/context/quadracticCurveTo_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.moveTo(20, 110)
  ctx.quadraticCurveTo(230, 150, 250, 20)
  ctx.stroke()

  ctx.image.writeFile("tests/images/context/quadracticCurveTo_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.ellipse(100, 75, 75, 50)
  ctx.stroke()

  ctx.image.writeFile("tests/images/context/ellipse_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.strokeStyle = "green"
  ctx.strokeRect(20, 10, 160, 100)

  ctx.image.writeFile("tests/images/context/strokeRect_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.lineJoin = ljBevel
  ctx.lineWidth = 15
  ctx.strokeStyle = "#38f"
  ctx.strokeRect(30, 30, 160, 90)

  ctx.image.writeFile("tests/images/context/strokeRect_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.setTransform(1, 0.2, 0.8, 1, 0, 0)
  ctx.fillRect(0, 0, 100, 100)

  ctx.image.writeFile("tests/images/context/setTransform_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.setTransform(1, 0.2, 0.8, 1, 0, 0)
  ctx.fillRect(0, 0, 100, 100)

  ctx.image.writeFile("tests/images/context/resetTransform_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.rotate(45 * PI / 180)
  ctx.fillRect(60, 0, 100, 30)

  ctx.image.writeFile("tests/images/context/resetTransform_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.transform(1, 0, 1.7, 1, 0, 0)
  ctx.fillStyle = "gray"
  ctx.fillRect(40, 40, 50, 20)
  ctx.fillRect(40, 90, 50, 20)

  ctx.resetTransform()
  ctx.fillStyle = "red"
  ctx.fillRect(40, 40, 50, 20)
  ctx.fillRect(40, 90, 50, 20)

  ctx.image.writeFile("tests/images/context/resetTransform_2.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.translate(110, 30)
  ctx.fillStyle = "red"
  ctx.fillRect(0, 0, 80, 80)

  ctx.setTransform(1, 0, 0, 1, 0, 0)

  ctx.fillStyle = "gray"
  ctx.fillRect(0, 0, 80, 80)

  ctx.image.writeFile("tests/images/context/translate_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.scale(9, 3)
  ctx.fillStyle = "red"
  ctx.fillRect(10, 10, 8, 20)

  ctx.setTransform(1, 0, 0, 1, 0, 0)

  ctx.fillStyle = "gray"
  ctx.fillRect(10, 10, 8, 20)

  ctx.image.writeFile("tests/images/context/scale_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.fillStyle = "gray"
  ctx.fillRect(100, 0, 80, 20)

  ctx.rotate(45 * PI / 180)
  ctx.fillStyle = "red"
  ctx.fillRect(100, 0, 80, 20)

  ctx.image.writeFile("tests/images/context/rotate_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  ctx.font.size = 50

  ctx.fillText("Hello world", 50, 90)

  ctx.image.writeFile("tests/images/context/fillText_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  ctx.font.size = 50

  ctx.strokeText("Hello world", 50, 90)

  ctx.image.writeFile("tests/images/context/strokeText_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.save()

  ctx.fillStyle = "green"
  ctx.fillRect(10, 10, 100, 100)

  ctx.restore()

  ctx.fillRect(150, 40, 100, 100)

  ctx.image.writeFile("tests/images/context/save_1.png")

block:
  let ctx = newContext(newImage(300, 150))

  ctx.beginPath()
  ctx.circle(100, 75, 50)
  ctx.clip()

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)
  ctx.fillStyle = "orange"
  ctx.fillRect(0, 0, 100, 100)

  ctx.image.writeFile("tests/images/context/clip_1.png")

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

  ctx.image.writeFile("tests/images/context/clip_1b.png")

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

  ctx.image.writeFile("tests/images/context/clip_1c.png")

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

  ctx.image.writeFile("tests/images/context/clip_1d.png")

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

  ctx.image.writeFile("tests/images/context/clip_1e.png")

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

  ctx.image.writeFile("tests/images/context/clip_1f.png")

block:
  let ctx = newContext(newImage(300, 150))

  var region: Path
  region.rect(80, 10, 20, 130)
  region.rect(40, 50, 100, 50)
  ctx.clip(region, wrEvenOdd)

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  ctx.image.writeFile("tests/images/context/clip_2.png")

block:
  let image = newImage(300, 150)

  let ctx = newContext(image)

  var circlePath: Path
  circlePath.circle(150, 75, 75)
  var squarePath: Path
  squarePath.rect(85, 10, 130, 130)

  ctx.clip(circlePath)
  ctx.clip(squarePath)

  ctx.fillStyle = "blue"
  ctx.fillRect(0, 0, ctx.image.width.float32, ctx.image.height.float32)

  image.writeFile("tests/images/context/clip_3.png")

block:
  let image = newImage(300, 150)

  let ctx = newContext(image)
  ctx.font = readFont("tests/fonts/Roboto-Regular_1.ttf")
  ctx.font.size = 50
  ctx.fillStyle = "blue"

  ctx.saveLayer()

  var circlePath: Path
  circlePath.circle(150, 75, 75)

  ctx.clip(circlePath)

  ctx.fillText("Hello world", 50, 90)

  ctx.restore()

  image.writeFile("tests/images/context/clip_text.png")

block:
  let ctx = newContext(100, 100)
  ctx.font = readFont("tests/fonts/Roboto-Regular_1.ttf")

  let metrics = ctx.measureText("Hello world")
  doAssert metrics.width == 61

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

  image.writeFile("tests/images/context/setLineDash_1.png")

block:
  let
    image = newImage(300, 150)
    ctx = newContext(image)

  image.fill(rgba(255, 255, 255, 255))

  var paint = Paint(kind: pkSolid, color: rgba(0, 0, 255, 255))
  paint.blendMode = bmExclusion

  ctx.fillStyle = paint

  ctx.fillRect(10, 10, 100, 100)

  image.writeFile("tests/images/context/blendmode_1.png")

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

  image.writeFile("tests/images/context/globalAlpha_1.png")
