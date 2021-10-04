import pixie, strformat

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)))
  a.writeFile("tests/images/rotate0.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(90 * PI.float32 / 180))
  a.writeFile("tests/images/rotate90.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(180 * PI.float32 / 180))
  a.writeFile("tests/images/rotate180.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(270 * PI.float32 / 180))
  a.writeFile("tests/images/rotate270.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotate(360 * PI.float32 / 180))
  a.writeFile("tests/images/rotate360.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillRect(rect(vec2(10, 10), vec2(30, 30)))
  ctx.image.writeFile("tests/images/drawRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeRect(rect(vec2(10, 10), vec2(30, 30)))
  ctx.image.writeFile("tests/images/strokeRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillRoundedRect(rect(vec2(10, 10), vec2(30, 30)), 10)
  ctx.image.writeFile("tests/images/drawRoundedRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeRoundedRect(rect(vec2(10, 10), vec2(30, 30)), 10)
  ctx.image.writeFile("tests/images/strokeRoundedRect.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeSegment(segment(vec2(10, 10), vec2(90, 90)))
  ctx.image.writeFile("tests/images/drawSegment.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillEllipse(vec2(50, 50), 25, 25)
  ctx.image.writeFile("tests/images/drawEllipse.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokeEllipse(vec2(50, 50), 25, 25)
  ctx.image.writeFile("tests/images/strokeEllipse.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 0, 255)
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.fillPolygon(vec2(50, 50), 30, 6)
  ctx.image.writeFile("tests/images/drawPolygon.png")

block:
  let ctx = newContext(100, 100)
  ctx.strokeStyle = rgba(255, 255, 0, 255)
  ctx.lineWidth = 10
  ctx.image.fill(rgba(0, 255, 255, 255))
  ctx.strokePolygon(vec2(50, 50), 30, 6)
  ctx.image.writeFile("tests/images/strokePolygon.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * scale(vec2(0.5, 0.5)))
  a.writeFile("tests/images/scaleHalf.png")

proc doDiff(rendered: Image, name: string) =
  rendered.writeFile(&"tests/images/rendered/{name}.png")
  let
    master = readImage(&"tests/images/masters/{name}.png")
    (diffScore, diffImage) = diff(master, rendered)
  echo &"{name} score: {diffScore}"
  diffImage.writeFile(&"tests/images/diffs/{name}.png")

block:
  let
    image = newImage(100, 100)
    path = newPath()
  path.rect(0, 0, 99, 99)
  image.fillPath(path, rgba(0, 0, 0, 255), translate(vec2(0.5, 0.5)))
  doDiff(image, "smooth1")

block:
  let
    a = newImage(100, 100)
    b = newImage(100, 100)
    path = newPath()
  path.rect(-25, -25, 50, 50)
  path.transform(rotate(45 * PI.float32 / 180))
  b.fillPath(path, rgba(0, 0, 0, 255), translate(vec2(50, 50)))
  a.fill(rgba(255, 255, 255, 255))
  a.draw(b, translate(vec2(0, 0.4)))
  doDiff(a, "smooth2")

block:
  let
    a = newImage(100, 100)
    b = newImage(50, 50)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgba(0, 0, 0, 255))
  a.draw(b, translate(vec2(25.2, 25)))
  doDiff(a, "smooth3")

block:
  let
    a = newImage(100, 100)
    b = newImage(50, 50)
  a.fill(rgba(255, 255, 255, 255))
  b.fill(rgba(0, 0, 0, 255))
  a.draw(b, translate(vec2(25.2, 25.6)))
  doDiff(a, "smooth4")
