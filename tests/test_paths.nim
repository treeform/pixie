import chroma, pixie, pixie/fileformats/png, strformat

block:
  let pathStr = """
  m 1 2 3 4 5 6
  """
  let path = parsePath(pathStr)
  doAssert $path == "m1 2 l3 4 l5 6"

block:
  let pathStr = """
  l 1 2 3 4 5 6
  """
  let path = parsePath(pathStr)
  doAssert $path == "l1 2 l3 4 l5 6"

block:
  let pathStr = """
    m 1 2
    l 3 4
    h 5
    v 6
    c 0 0 0 0 0 0
    q 1 1 1 1
    t 2 2
    a 7 7 7 7 7 7 7
    z
  """
  let path = parsePath(pathStr)
  doAssert $path == "m1 2 l3 4 h5 v6 c0 0 0 0 0 0 q1 1 1 1 t2 2 a7 7 7 7 7 7 7 Z"

block:
  let pathStr = """
    M 1 2
    L 3 4
    H 5
    V 6
    C 0 0 0 0 0 0
    Q 1 1 1 1
    T 2 2
    A 7 7 7 7 7 7 7
    z
  """
  let path = parsePath(pathStr)
  doAssert $path == "M1 2 L3 4 H5 V6 C0 0 0 0 0 0 Q1 1 1 1 T2 2 A7 7 7 7 7 7 7 Z"

block:
  let pathStr = "M 0.1E-10 0.1e10 L2+2 L3-3 L0.1E+10-1"
  discard parsePath(pathStr)

block:
  let
    image = newImage(100, 100)
    pathStr = "M 10 10 L 90 90"
    color = rgba(255, 0, 0, 255)
  image.strokePath(pathStr, color, strokeWidth = 10)
  image.writeFile("tests/paths/pathStroke1.png")

block:
  let
    image = newImage(100, 100)
    pathStr = "M 10 10 L 50 60 90 90"
    color = rgba(255, 0, 0, 255)
  image.strokePath(pathStr, color, strokeWidth = 10)
  image.writeFile("tests/paths/pathStroke2.png")

block:
  let image = newImage(100, 100)
  image.strokePath(
    "M 15 10 L 30 90 60 30 90 90",
    rgba(255, 255, 0, 255),
    strokeWidth = 10
  )
  image.writeFile("tests/paths/pathStroke3.png")

block:
  let
    image = newImage(100, 100)
    pathStr = "M 10 10 H 90 V 90 H 10 L 10 10"
    color = rgba(0, 0, 0, 255)
  image.fillPath(pathStr, color)
  image.writeFile("tests/paths/pathBlackRectangle.png")

block:
  let
    image = newImage(100, 100)
    pathStr = "M 10 10 H 90 V 90 H 10 Z"
    color = rgba(0, 0, 0, 255)
  image.fillPath(parsePath(pathStr), color)
  image.writeFile("tests/paths/pathBlackRectangleZ.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 10 10 H 90 V 90 H 10 L 10 10",
    rgba(255, 255, 0, 255)
  )
  image.writeFile("tests/paths/pathYellowRectangle.png")

block:
  let path = newPath()
  path.moveTo(10, 10)
  path.lineTo(10, 90)
  path.lineTo(90, 90)
  path.lineTo(90, 10)
  path.lineTo(10, 10)

  let image = newImage(100, 100)
  image.fillPath(path, rgba(255, 0, 0, 255))
  image.writeFile("tests/paths/pathRedRectangle.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M30 60 A 20 20 0 0 0 90 60 L 30 60",
    parseHtmlColor("#FC427B").rgba
  )
  image.writeFile("tests/paths/pathBottomArc.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    """
      M 10,30
      A 20,20 0,0,1 50,30
      A 20,20 0,0,1 90,30
      Q 90,60 50,90
      Q 10,60 10,30 z
    """,
    parseHtmlColor("#FC427B").rgba
  )
  image.writeFile("tests/paths/pathHeart.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 20 50 A 20 10 45 1 1 80 50 L 20 50",
    parseHtmlColor("#FC427B").rgba
  )
  image.writeFile("tests/paths/pathRotatedArc.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 0 50 A 50 50 0 0 0 50 0 L 50 50 L 0 50",
    parseHtmlColor("#FC427B").rgba
  )
  image.writeFile("tests/paths/pathInvertedCornerArc.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 0 50 A 50 50 0 0 1 50 0 L 50 50 L 0 50",
    parseHtmlColor("#FC427B").rgba
  )
  image.writeFile("tests/paths/pathCornerArc.png")

# block:
#   let
#     image = newImage(100, 100)
#     r = 10.0
#     x = 10.0
#     y = 10.0
#     h = 80.0
#     w = 80.0
#   let path = newPath()
#   path.moveTo(x + r, y)
#   path.arcTo(x + w, y, x + w, y + h, r)
#   path.arcTo(x + w, y + h, x, y + h, r)
#   path.arcTo(x, y + h, x, y, r)
#   path.arcTo(x, y, x + w, y, r)
#   image.fillPath(path, rgba(255, 0, 0, 255))
#   image.writeFile("tests/paths/pathRoundRect.png")

block:
  let
    mask = newMask(100, 100)
    pathStr = "M 10 10 H 90 V 90 H 10 L 10 10"
  mask.fillPath(pathStr)
  writeFile("tests/paths/pathRectangleMask.png", mask.encodePng())

# block:
#   let
#     mask = newMask(100, 100)
#     r = 10.0
#     x = 10.0
#     y = 10.0
#     h = 80.0
#     w = 80.0
#   let path = newPath()
#   path.moveTo(x + r, y)
#   path.arcTo(x + w, y, x + w, y + h, r)
#   path.arcTo(x + w, y + h, x, y + h, r)
#   path.arcTo(x, y + h, x, y, r)
#   path.arcTo(x, y, x + w, y, r)
#   mask.fillPath(path)
#   writeFile("tests/paths/pathRoundRectMask.png", mask.encodePng())

block:
  let image = newImage(200, 200)
  image.fill(rgba(255, 255, 255, 255))

  var p = parsePath("M1 0.5C1 0.776142 0.776142 1 0.5 1C0.223858 1 0 0.776142 0 0.5C0 0.223858 0.223858 0 0.5 0C0.776142 0 1 0.223858 1 0.5Z")
  image.fillPath(p, rgba(255, 0, 0, 255), scale(vec2(200, 200)))

  image.strokePath(p, rgba(0, 255, 0, 255), scale(vec2(200, 200)),
      strokeWidth = 0.01)

  image.writeFile("tests/paths/pixelScale.png")

block:
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 20 3 L 20 20 L 3 20 Z")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, RoundCap, RoundJoin
  )

  image.writeFile("tests/paths/boxRound.png")

block:
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 20 3 L 20 20 L 3 20 Z")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, RoundCap, BevelJoin
  )

  image.writeFile("tests/paths/boxBevel.png")

block:
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 20 3 L 20 20 L 3 20 Z")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, RoundCap, MiterJoin
  )

  image.writeFile("tests/paths/boxMiter.png")

block:
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 20 3 L 20 20 L 3 20")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, ButtCap, BevelJoin
  )

  image.writeFile("tests/paths/ButtCap.png")

block:
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 20 3 L 20 20 L 3 20")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, RoundCap, BevelJoin
  )

  image.writeFile("tests/paths/RoundCap.png")

block:
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 20 3 L 20 20 L 3 20")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, BevelJoin
  )

  image.writeFile("tests/paths/SquareCap.png")

block:
  let
    image = newImage(60, 120)
    path = parsePath("M 0 0 L 50 0")
  image.fill(rgba(255, 255, 255, 255))

  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(5, 5)), 10, ButtCap, BevelJoin,
  )

  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(5, 25)), 10, ButtCap, BevelJoin,
    dashes = @[2.float32, 2]
  )

  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(5, 45)), 10, ButtCap, BevelJoin,
    dashes = @[4.float32, 4]
  )

  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(5, 65)), 10, ButtCap, BevelJoin,
    dashes = @[2.float32, 4, 6, 2]
  )

  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(5, 85)), 10, ButtCap, BevelJoin,
    dashes = @[1.float32]
  )

  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(5, 105)), 10, ButtCap, BevelJoin,
    dashes = @[1.float32, 2, 3, 4, 5, 6, 7, 8, 9]
  )

  image.writeFile("tests/paths/dashes.png")

block:
  proc miterTest(angle, limit: float32) =
    let
      image = newImage(60, 60)
    image.fill(rgba(255, 255, 255, 255))
    let path = newPath()
    path.moveTo(-20, 0)
    path.lineTo(0, 0)
    let th = angle.float32.degToRad() + PI/2
    path.lineTo(sin(th)*20, cos(th)*20)

    image.strokePath(
      path, rgba(0, 0, 0, 255), translate(vec2(30, 30)), 8, ButtCap, MiterJoin,
      miterLimit = limit
    )
    image.writeFile(&"tests/paths/miterLimit_{angle.int}deg_{limit:0.2f}num.png")

  miterTest(10, 2)
  miterTest(145, 2)
  miterTest(155, 2)
  miterTest(165, 2)
  miterTest(165, 10)
  miterTest(145, 3.32)
  miterTest(145, 3.33)

block:
  # Test self closing subpaths on fill
  let
    image = newImage(60, 60)
    path = parsePath("M0 0 L0 0 L60 0 L60 60 L0 60")
  image.fill(rgba(255, 255, 255, 255))
  image.fillPath(path, rgba(127, 127, 127, 255))
  image.writeFile("tests/paths/selfclosing.png")

# Potential error cases, ensure they do not crash

block:
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 3 3 L 3 3")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  let
    image = newImage(60, 60)
    path = parsePath("L 0 0 L 0 0")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  let
    image = newImage(60, 60)
    path = parsePath("L 1 1")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  let
    image = newImage(60, 60)
    path = parsePath("L 0 0")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 10 10 H 60 V 60 H 10 z",
    rgbx(255, 0, 0, 255)
  )

  let paint = newPaint(SolidPaint)
  paint.color = color(0, 1, 0, 1)
  paint.blendMode = ExcludeMaskBlend

  image.fillPath(
    "M 30 30 H 80 V 80 H 30 z",
    paint
  )
  image.writeFile("tests/paths/rectExcludeMask.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 10.1 10.1 H 60.1 V 60.1 H 10.1 z",
    rgbx(255, 0, 0, 255)
  )

  let paint = newPaint(SolidPaint)
  paint.color = color(0, 1, 0, 1)
  paint.blendMode = ExcludeMaskBlend

  image.fillPath(
    "M 30.1 30.1 H 80.1 V 80.1 H 30.1 z",
    paint
  )
  image.writeFile("tests/paths/rectExcludeMaskAA.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 10 10 H 60 V 60 H 10 z",
    rgbx(255, 0, 0, 255)
  )

  let paint = newPaint(SolidPaint)
  paint.color = color(0, 1, 0, 1)
  paint.blendMode = MaskBlend

  image.fillPath(
    "M 30 30 H 80 V 80 H 30 z",
    paint
  )
  image.writeFile("tests/paths/rectMask.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    "M 10.1 10.1 H 60.1 V 60.1 H 10.1 z",
    rgbx(255, 0, 0, 255)
  )

  let paint = newPaint(SolidPaint)
  paint.color = color(0, 1, 0, 1)
  paint.blendMode = MaskBlend

  image.fillPath(
    "M 30.1 30.1 H 80.1 V 80.1 H 30.1 z",
    paint
  )
  image.writeFile("tests/paths/rectMaskAA.png")

block:
  let mask = newMask(100, 100)
  mask.fillPath("M 10 10 H 60 V 60 H 10 z")
  mask.fillPath("M 30 30 H 80 V 80 H 30 z", blendMode = ExcludeMaskBlend)
  writeFile("tests/paths/maskRectExcludeMask.png", mask.encodePng())

block:
  let mask = newMask(100, 100)
  mask.fillPath("M 10.1 10.1 H 60.1 V 60.1 H 10.1 z")
  mask.fillPath("M 30.1 30.1 H 80.1 V 80.1 H 30.1 z", blendMode = ExcludeMaskBlend)
  writeFile("tests/paths/maskRectExcludeMaskAA.png", mask.encodePng())

block:
  let mask = newMask(100, 100)
  mask.fillPath("M 10 10 H 60 V 60 H 10 z")
  mask.fillPath("M 30 30 H 80 V 80 H 30 z", blendMode = MaskBlend)
  writeFile("tests/paths/maskRectMask.png", mask.encodePng())

block:
  let mask = newMask(100, 100)
  mask.fillPath("M 10.1 10.1 H 60.1 V 60.1 H 10.1 z")
  mask.fillPath("M 30.1 30.1 H 80.1 V 80.1 H 30.1 z", blendMode = MaskBlend)
  writeFile("tests/paths/maskRectMaskAA.png", mask.encodePng())

block:
  var
    surface = newImage(256, 256)
    ctx = newContext(surface)

  surface.fill(rgba(255, 255, 255, 255))

  # Draw shapes
  for i in 0 .. 3:
    for j in 0 .. 2:
      ctx.beginPath()
      let x = 25f + j.float32 * 50f # x coordinate
      let y = 25f + i.float32 * 50f # y coordinate
      let radius = 20f # Arc radius
      let startAngle = 0f # Starting point on circle
      let endAngle = PI + (PI * j.float32) / 2           # End point on circle
      let counterclockwise = i mod 2 == 1 # Draw counterclockwise

      ctx.arc(x, y, radius, startAngle, endAngle, counterclockwise)

      if i > 1:
        ctx.fill()
      else:
        ctx.stroke()

  surface.writeFile("tests/paths/arc.png")

block:
  var
    surface = newImage(256, 256)
    ctx = newContext(surface)
  surface.fill(rgba(255, 255, 255, 255))

  let
    p0 = vec2(230, 20)
    p1 = vec2(90, 130)
    p2 = vec2(20, 20)

  ctx.beginPath()
  ctx.moveTo(p0.x, p0.y)
  ctx.arcTo(p1.x, p1.y, p2.x, p2.y, 50)
  ctx.lineTo(p2.x, p2.y)
  ctx.stroke()

  surface.writeFile("tests/paths/arcTo1.png")

block:
  var
    surface = newImage(256, 256)
    ctx = newContext(surface)
  surface.fill(rgba(255, 255, 255, 255))
  # Tangential lines
  ctx.beginPath()
  ctx.strokeStyle = "gray"
  ctx.moveTo(200, 20)
  ctx.lineTo(200, 130)
  ctx.lineTo(50, 20)
  ctx.stroke()

  # Arc
  ctx.beginPath()
  ctx.strokeStyle = "black"
  ctx.lineWidth = 5
  ctx.moveTo(200, 20)
  ctx.arcTo(200, 130, 50, 20, 40)
  ctx.stroke()

  # Start point
  ctx.beginPath()
  ctx.fillStyle = "blue"
  ctx.arc(200, 20, 5, 0, 2 * PI)
  ctx.fill()

  # Control points
  ctx.beginPath()
  ctx.fillStyle = "red"
  ctx.arc(200, 130, 5, 0, 2 * PI) # Control point one
  ctx.arc(50, 20, 5, 0, 2 * PI) # Control point two
  ctx.fill()

  surface.writeFile("tests/paths/arcTo2.png")

block:
  var
    surface = newImage(256, 256)
    ctx = newContext(surface)
  surface.fill(rgba(255, 255, 255, 255))

  ctx.beginPath()
  ctx.moveTo(180, 90)
  ctx.arcTo(180, 130, 110, 130, 130)
  ctx.lineTo(110, 130)
  ctx.stroke()

  surface.writeFile("tests/paths/arcTo3.png")

block:
  let path = newPath()
  path.rect(0, 0, 10, 10)

  doAssert path.fillOverlaps(vec2(5, 5))
  doAssert path.fillOverlaps(vec2(0, 0))
  doAssert path.fillOverlaps(vec2(9, 0))
  doAssert path.fillOverlaps(vec2(0, 9))
  doAssert not path.fillOverlaps(vec2(10, 10))

block:
  let path = newPath()
  path.ellipse(20, 20, 20, 10)

  doAssert not path.fillOverlaps(vec2(0, 0))
  doAssert path.fillOverlaps(vec2(20, 20))
  doAssert path.fillOverlaps(vec2(10, 20))
  doAssert path.fillOverlaps(vec2(30, 20))

block:
  let path = newPath()
  path.rect(10, 10, 10, 10)

  doAssert path.strokeOverlaps(vec2(10, 10))
  doAssert path.strokeOverlaps(vec2(20.1, 20.1))
  doAssert not path.strokeOverlaps(vec2(5, 5))

block:
  let path = newPath()
  path.ellipse(20, 20, 20, 10)

  doAssert not path.strokeOverlaps(vec2(0, 0))
  doAssert not path.strokeOverlaps(vec2(20, 20))
  doAssert path.strokeOverlaps(vec2(0, 20))
  doAssert path.strokeOverlaps(vec2(39.9, 19.9))
  doAssert path.strokeOverlaps(vec2(19.8, 30.2))
  doAssert not path.strokeOverlaps(vec2(19.4, 30.6))

block:
  let path = newPath()
  path.circle(50, 50, 30)

  let paint = newPaint(SolidPaint)
  paint.color = color(1, 0, 1, 1)
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(path, paint)

  image.writeFile("tests/paths/opacityFill.png")

block:
  let path = newPath()
  path.circle(50, 50, 30)

  let paint = newPaint(SolidPaint)
  paint.color = color(1, 0, 1, 1)
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.strokePath(path, paint, strokeWidth = 10)

  image.writeFile("tests/paths/opacityStroke.png")

block:
  let
    image = newImage(100, 100)
    pathStr = "M0 0 L200 200"
    color = rgba(255, 0, 0, 255)
  image.strokePath(pathStr, color, strokeWidth = 10)
  image.writeFile("tests/paths/pathStroke1Big.png")

block:
  let
    image = newMask(100, 100)
    pathStr = "M0 0 L200 200"
  image.strokePath(pathStr, strokeWidth = 10)
  image.writeFile("tests/paths/pathStroke1BigMask.png")

block:
  let
    image = newImage(100, 100)
    pathStr = "M99 99 L999 99 L999 100 L99 100 Z"
    color = rgba(255, 0, 0, 255)
  image.fillPath(pathStr, color)
  image.writeFile("tests/paths/path1pxCover.png")

block:
  let
    image = newImage(100, 100)
    pathStr = "M100 100 L999 100 L999 101 L100 101 Z"
    color = rgba(255, 0, 0, 255)
  image.fillPath(pathStr, color)
  image.writeFile("tests/paths/path0pxCover.png")

block:
  let image = newImage(200, 200)
  image.fill(rgba(255, 255, 255, 255))

  let ctx = newContext(image)
  ctx.setLineDash(@[2.0.float32])

  doAssertRaises PixieError:
    ctx.strokePolygon(vec2(0.0, 0.0), 0.0, 0)

block:
  # Test zero width image fill.
  let
    image = newImage(100, 100)
    pathStr = "M0 0 L0 1 L0 0 Z"
    color = rgba(255, 0, 0, 255)
  image.fillPath(pathStr, color)

block:
  # Test zero width mask fill.
  let
    mask = newMask(100, 100)
    pathStr = "M0 0 L0 1 L0 0 Z"
  mask.fillPath(pathStr)

block:
  # Test different polygons.
  for i in 3 .. 8:
    let path = newPath()
    path.polygon(vec2(50, 50), 30, i)
    let mask = newMask(100, 100)
    mask.fillPath(path)
    mask.writeFile(&"tests/paths/polygon{i}.png")
