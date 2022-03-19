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
  echo "??? stroke zero polygon ???"

  try:
    echo "inside the try"
    raise newException(PixieError, "Just the exception please")
    echo "no exception wut?"
  except PixieError:
    echo "getCurrentExceptionMsg"
    echo getCurrentExceptionMsg()

echo "test completed"
