import pixie, strformat, xrays

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)))
  a.xray("tests/images/rotate0.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(90 * PI.float32 / 180))
  a.xray("tests/images/rotate90.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(180 * PI.float32 / 180))
  a.xray("tests/images/rotate180.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(270 * PI.float32 / 180))
  a.xray("tests/images/rotate270.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(360 * PI.float32 / 180))
  a.xray("tests/images/rotate360.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillRect(rect(vec2(10, 10), vec2(30, 30)))
  ctx.image.xray("tests/images/drawRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeRect(rect(vec2(10, 10), vec2(30, 30)))
  ctx.image.xray("tests/images/strokeRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillRoundedRect(rect(vec2(10, 10), vec2(30, 30)), 10)
  ctx.image.xray("tests/images/drawRoundedRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeRoundedRect(rect(vec2(10, 10), vec2(30, 30)), 10)
  ctx.image.xray("tests/images/strokeRoundedRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeSegment(segment(vec2(10, 10), vec2(90, 90)))
  ctx.image.xray("tests/images/drawSegment.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillEllipse(vec2(50, 50), 25, 25)
  ctx.image.xray("tests/images/drawEllipse.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeEllipse(vec2(50, 50), 25, 25)
  ctx.image.xray("tests/images/strokeEllipse.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillPolygon(vec2(50, 50), 30, 6)
  ctx.image.xray("tests/images/drawPolygon.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokePolygon(vec2(50, 50), 30, 6)
  ctx.image.xray("tests/images/strokePolygon.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * scale(vec2(0.5, 0.5)))
  a.xray("tests/images/scaleHalf.png")

block:
  let
    a = newImage(100, 100)
    b = newImage(99, 99)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgbx(0, 0, 0, 255))
  a.draw(b, translate(vec2(0.5, 0.5)))
  a.xray("tests/images/masters/smooth1.png")

block:
  let
    a = newImage(100, 100)
    b = newImage(50, 50)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgbx(0, 0, 0, 255))
  a.draw(b, translate(vec2(0, 50)) * rotate(45.toRadians))
  a.xray("tests/images/masters/smooth2.png")

block:
  let
    a = newImage(100, 100)
    b = newImage(50, 50)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgba(0, 0, 0, 255))
  a.draw(b, translate(vec2(25.2, 25)))
  a.xray("tests/images/masters/smooth3.png")

block:
  let
    a = newImage(100, 100)
    b = newImage(50, 50)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgba(0, 0, 0, 255))
  a.draw(b, translate(vec2(25.2, 25.6)))
  a.xray("tests/images/masters/smooth4.png")

block:
  let
    a = newImage(100, 100)
    b = newImage(10, 10)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgbx(255, 0, 0, 255))
  let m = translate(vec2(50, 50)) * rotate(30.toRadians)
  a.draw(b, m)
  a.xray("tests/images/masters/smooth5.png")

block:
  let
    a = newImage(100, 100)
    b = readImage(&"tests/images/turtle.png")
  a.fill(rgba(255, 255, 255, 255))
  let m = translate(vec2(50, 50)) * rotate(30.toRadians)
  a.draw(b, m)
  a.xray("tests/images/masters/smooth6.png")

block:
  let
    a = newImage(100, 100)
    b = readImage(&"tests/images/turtle@10x.png")
  a.fill(rgba(255, 255, 255, 255))
  let m = translate(vec2(50, 50)) * rotate(30.toRadians) * scale(vec2(0.1, 0.1))
  a.draw(b, m)
  a.xray("tests/images/masters/smooth7.png")

block:
  let
    a = newImage(100, 100)
    b = readImage(&"tests/images/turtle.png")
  a.fill(rgba(255, 255, 255, 255))
  let m = scale(vec2(2, 2))
  a.draw(b, m)
  a.xray("tests/images/masters/smooth8.png")

block:
  let
    a = newImage(100, 100)
    b = readImage(&"tests/images/turtle.png")
  a.fill(rgba(255, 255, 255, 255))
  let m = translate(vec2(1, 1)) * scale(vec2(2, 2))
  a.draw(b, m)
  a.xray("tests/images/masters/smooth9.png")

block:
  let
    a = newImage(100, 100)
    b = readImage(&"tests/images/turtle.png")
  a.fill(rgba(255, 255, 255, 255))
  let m = translate(vec2(0.5, 0.5)) * scale(vec2(2, 2))
  a.draw(b, m)
  a.xray("tests/images/masters/smooth10.png")

block:
  let
    a = newImage(100, 100)
    b = readImage(&"tests/images/turtle.png")
  a.fill(rgba(255, 255, 255, 255))
  let m = translate(vec2(-43.29, -103.87)) *
    rotate(-15.toRadians) *
    scale(vec2(263.86/40, 263.86/40))
  a.draw(b, m)
  a.xray("tests/images/masters/smooth11.png")

block:
  let
    a = newImage(100, 100)
    b = readImage(&"tests/images/turtle.png")
  a.fill(rgba(255, 255, 255, 255))
  let m = translate(vec2(50, 50)) * rotate(-5.toRadians)
  a.draw(b, m * translate(vec2(0, 0)))
  a.draw(b, m * translate(vec2(-40, 0)))
  a.draw(b, m * translate(vec2(-40, -40)))
  a.draw(b, m * translate(vec2(0, -40)))
  a.xray("tests/images/masters/smooth12.png")

block:
  let
    a = newImage(100, 100)
    b = newImage(99, 99)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgba(0, 0, 0, 255))
  a.draw(b, scale(vec2(0.5, 0.5)))
  a.xray("tests/images/masters/minify_odd.png")

block:
  let
    rock = readImage("tests/images/rock.png")
    minified = rock.minifyBy2()
  minified.xray("tests/images/masters/rock_minified.png")

block:
  let
    rock = readImage("tests/images/rock.png")
    minified = rock.minifyBy2(2)
  minified.xray("tests/images/masters/rock_minified2.png")

block:
  let pathStr = """
  M 0 0
  L 20 0
  L 20 20
  L 0 20
  z
  """
  let
    image = newImage(20, 20)
    strokeImage = newImage(20, 20)
  image.fillPath(pathStr, color(1.0, 0.5, 0.25, 1.0))
  strokeImage.strokePath(pathStr, color(1, 1, 1, 1), strokeWidth = 4)
  image.draw(strokeImage)

  image.xray("tests/images/fillOptimization.png")
  doAssert image[10, 10] == rgbx(255, 128, 64, 255)

block:
  let a = newImage(100, 100)
  a.fill(color(1, 1, 1, 1))

  let draws = [
    # Overlaps in bounds
    (vec2(-50, -50), color(1, 0, 0, 1)),
    (vec2(50, -50), color(0, 1, 0, 1)),
    (vec2(50, 50), color(0, 0, 1, 1)),
    (vec2(-50, 50), color(1, 1, 0, 1)),
    # Out of bounds
    (vec2(-100, 00), color(1, 0, 1, 1)),
    (vec2(0, -100), color(0, 1, 1, 1)),
    (vec2(100, 00), color(0.5, 0.5, 0.5, 1)),
    (vec2(0, 100), color(0.75, 0.75, 0, 1))
  ]
  for (translation, color) in draws:
    let
      b = newImage(100, 100)
      path = newPath()
    path.rect(0, 0, b.width.float32, b.height.float32)
    b.strokePath(path, color, strokeWidth = 20)

    a.draw(b, translate(translation))

  a.xray("tests/images/fillOptimization2.png")

block:
  let transforms = [
    translate(vec2(0, 0)),
    translate(vec2(50, -50)),
    translate(vec2(50, 50)),
    translate(vec2(-50, 50)),
    translate(vec2(-50, -50))
  ]

  let path = newPath()
  path.rect(10, 10, 80, 80)

  let mask = newImage(100, 100)
  mask.fillPath(path, color(1, 1, 1, 1))

  let a = newImage(100, 100)

  for i, transform in transforms:
    a.fill(color(0, 0, 1, 1))
    a.draw(mask, transform, blendMode = MaskBlend)
    a.xray("tests/images/maskClearsOnDraw" & $i & ".png")

block:
  let transforms = [
    translate(vec2(100, 100)),
    translate(vec2(100, -100)),
    translate(vec2(-100, 100)),
    translate(vec2(-100, -100)),
    translate(vec2(0, 1000)),
    translate(vec2(0, -1000)),
    translate(vec2(1000, 0)),
    translate(vec2(-1000, 0)),
    translate(vec2(1000, 1000)),
    translate(vec2(1000, -1000)),
    translate(vec2(-1000, 1000)),
    translate(vec2(-1000, -1000)),
  ]

  let path = newPath()
  path.rect(10, 10, 80, 80)

  let mask = newImage(100, 100)
  mask.fillPath(path, color(1, 1, 1, 1))

  let a = newImage(100, 100)

  for i, transform in transforms:
    a.fill(color(0, 0, 1, 1))
    a.draw(mask, transform, blendMode = MaskBlend)
    doAssert a.isTransparent()
