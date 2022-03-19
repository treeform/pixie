import chroma, pixie, pixie/fileformats/png, strformat


block:
  echo "zero triangle"
  let
    image = newImage(60, 60)
    path = parsePath("M 3 3 L 3 3 L 3 3")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  echo "zero lines"
  let
    image = newImage(60, 60)
    path = parsePath("L 0 0 L 0 0")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  echo "line"
  let
    image = newImage(60, 60)
    path = parsePath("L 1 1")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  echo "zero line"
  let
    image = newImage(60, 60)
    path = parsePath("L 0 0")
  image.fill(rgba(255, 255, 255, 255))
  image.strokePath(
    path, rgba(0, 0, 0, 255), translate(vec2(10, 10)), 10, SquareCap, MiterJoin
  )

block:
  echo "exclude mask"
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
  echo "exclude mask aa"
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
  echo "rect mask"
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
  echo "rect mask aa"
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
  echo "rect exclude mask"
  let mask = newMask(100, 100)
  mask.fillPath("M 10 10 H 60 V 60 H 10 z")
  mask.fillPath("M 30 30 H 80 V 80 H 30 z", blendMode = ExcludeMaskBlend)
  writeFile("tests/paths/maskRectExcludeMask.png", mask.encodePng())

block:
  echo "rect exclude mask aa"
  let mask = newMask(100, 100)
  mask.fillPath("M 10.1 10.1 H 60.1 V 60.1 H 10.1 z")
  mask.fillPath("M 30.1 30.1 H 80.1 V 80.1 H 30.1 z", blendMode = ExcludeMaskBlend)
  writeFile("tests/paths/maskRectExcludeMaskAA.png", mask.encodePng())

block:
  echo "rect mask"
  let mask = newMask(100, 100)
  mask.fillPath("M 10 10 H 60 V 60 H 10 z")
  mask.fillPath("M 30 30 H 80 V 80 H 30 z", blendMode = MaskBlend)
  writeFile("tests/paths/maskRectMask.png", mask.encodePng())

block:
  echo "rect mask aa"
  let mask = newMask(100, 100)
  mask.fillPath("M 10.1 10.1 H 60.1 V 60.1 H 10.1 z")
  mask.fillPath("M 30.1 30.1 H 80.1 V 80.1 H 30.1 z", blendMode = MaskBlend)
  writeFile("tests/paths/maskRectMaskAA.png", mask.encodePng())

block:
  echo "arc"
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
  echo "arcTo"
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
  echo "arcTo2"
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
  echo "arcTo3"
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
  echo "fillOverlaps 1"
  let path = newPath()
  path.rect(0, 0, 10, 10)

  doAssert path.fillOverlaps(vec2(5, 5))
  doAssert path.fillOverlaps(vec2(0, 0))
  doAssert path.fillOverlaps(vec2(9, 0))
  doAssert path.fillOverlaps(vec2(0, 9))
  doAssert not path.fillOverlaps(vec2(10, 10))

block:
  echo "fillOverlaps 2"
  let path = newPath()
  path.ellipse(20, 20, 20, 10)

  doAssert not path.fillOverlaps(vec2(0, 0))
  doAssert path.fillOverlaps(vec2(20, 20))
  doAssert path.fillOverlaps(vec2(10, 20))
  doAssert path.fillOverlaps(vec2(30, 20))

block:
  echo "fillOverlaps 3"
  let path = newPath()
  path.rect(10, 10, 10, 10)

  doAssert path.strokeOverlaps(vec2(10, 10))
  doAssert path.strokeOverlaps(vec2(20.1, 20.1))
  doAssert not path.strokeOverlaps(vec2(5, 5))

block:
  echo "fillOverlaps 4"
  let path = newPath()
  path.ellipse(20, 20, 20, 10)

  doAssert not path.strokeOverlaps(vec2(0, 0))
  doAssert not path.strokeOverlaps(vec2(20, 20))
  doAssert path.strokeOverlaps(vec2(0, 20))
  doAssert path.strokeOverlaps(vec2(39.9, 19.9))
  doAssert path.strokeOverlaps(vec2(19.8, 30.2))
  doAssert not path.strokeOverlaps(vec2(19.4, 30.6))

block:
  echo "opacity fill"
  let path = newPath()
  path.circle(50, 50, 30)

  let paint = newPaint(SolidPaint)
  paint.color = color(1, 0, 1, 1)
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(path, paint)

  image.writeFile("tests/paths/opacityFill.png")

block:
  echo "opacity stroke"
  let path = newPath()
  path.circle(50, 50, 30)

  let paint = newPaint(SolidPaint)
  paint.color = color(1, 0, 1, 1)
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.strokePath(path, paint, strokeWidth = 10)

  image.writeFile("tests/paths/opacityStroke.png")

block:
  echo "stroke 1 big"
  let
    image = newImage(100, 100)
    pathStr = "M0 0 L200 200"
    color = rgba(255, 0, 0, 255)
  image.strokePath(pathStr, color, strokeWidth = 10)
  image.writeFile("tests/paths/pathStroke1Big.png")

block:
  echo "stroke 1 big maks"
  let
    image = newMask(100, 100)
    pathStr = "M0 0 L200 200"
  image.strokePath(pathStr, strokeWidth = 10)
  image.writeFile("tests/paths/pathStroke1BigMask.png")

block:
  echo "1px cover"
  let
    image = newImage(100, 100)
    pathStr = "M99 99 L999 99 L999 100 L99 100 Z"
    color = rgba(255, 0, 0, 255)
  image.fillPath(pathStr, color)
  image.writeFile("tests/paths/path1pxCover.png")

block:
  echo "0px cover"
  let
    image = newImage(100, 100)
    pathStr = "M100 100 L999 100 L999 101 L100 101 Z"
    color = rgba(255, 0, 0, 255)
  image.fillPath(pathStr, color)
  image.writeFile("tests/paths/path0pxCover.png")

block:
  echo "??? stroke zero polygon ???"

  try:
    echo "inside the try"
    raise newException(PixieError, "Just the exception please")
    echo "no exception wut?"
  except PixieError:
    echo "getCurrentExceptionMsg"
    echo getCurrentExceptionMsg()

block:
  echo "zero width image fill"
  let
    image = newImage(100, 100)
    pathStr = "M0 0 L0 1 L0 0 Z"
    color = rgba(255, 0, 0, 255)
  image.fillPath(pathStr, color)

block:
  echo "zero width mask fill"
  let
    mask = newMask(100, 100)
    pathStr = "M0 0 L0 1 L0 0 Z"
  mask.fillPath(pathStr)

block:
  echo "different polygons"
  for i in 3 .. 8:
    let path = newPath()
    path.polygon(vec2(50, 50), 30, i)
    let mask = newMask(100, 100)
    mask.fillPath(path)
    mask.writeFile(&"tests/paths/polygon{i}.png")

echo "test completed"
