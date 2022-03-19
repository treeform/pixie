import chroma, pixie, pixie/fileformats/png, strformat

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
  echo "??? stroke zero polygon ???"

  try:
    echo "inside the try"
    raise newException(PixieError, "Just the exception please")
    echo "no exception wut?"
  except PixieError:
    echo "getCurrentExceptionMsg"
    echo getCurrentExceptionMsg()

echo "test completed"
