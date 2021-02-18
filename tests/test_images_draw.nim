import pixie

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

  a.draw(b, translate(vec2(250, 250)) * rotationMat3(90 * PI / 180))
  a.writeFile("tests/images/rotate90.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotationMat3(180 * PI / 180))
  a.writeFile("tests/images/rotate180.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotationMat3(270 * PI / 180))
  a.writeFile("tests/images/rotate270.png")

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, translate(vec2(250, 250)) * rotationMat3(360 * PI / 180))
  a.writeFile("tests/images/rotate360.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.drawRect(rect(vec2(10, 10), vec2(30, 30)), rgba(255, 255, 0, 255))
  image.writeFile("tests/images/drawRect.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.drawRoundedRect(
    rect(vec2(10, 10), vec2(30, 30)),
    10,
    rgba(255, 255, 0, 255)
  )
  image.writeFile("tests/images/drawRoundedRect.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.drawSegment(
    segment(vec2(10, 10), vec2(90, 90)),
    rgba(255, 255, 0, 255),
    strokeWidth = 10
  )
  image.writeFile("tests/images/drawSegment.png")
