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
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.fillRect(rect(vec2(10, 10), vec2(30, 30)), rgba(255, 255, 0, 255))
  image.writeFile("tests/images/drawRect.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.strokeRect(rect(vec2(10, 10), vec2(30, 30)), rgba(255, 255, 0, 255), 10)
  image.writeFile("tests/images/strokeRect.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.fillRoundedRect(
    rect(vec2(10, 10), vec2(30, 30)),
    10,
    rgba(255, 255, 0, 255)
  )
  image.writeFile("tests/images/drawRoundedRect.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.strokeRoundedRect(
    rect(vec2(10, 10), vec2(30, 30)),
    10,
    rgba(255, 255, 0, 255),
    10
  )
  image.writeFile("tests/images/strokeRoundedRect.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.strokeSegment(
    segment(vec2(10, 10), vec2(90, 90)),
    rgba(255, 255, 0, 255),
    strokeWidth = 10
  )
  image.writeFile("tests/images/drawSegment.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.fillEllipse(
    vec2(50, 50),
    25,
    25,
    rgba(255, 255, 0, 255)
  )
  image.writeFile("tests/images/drawEllipse.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.strokeEllipse(
    vec2(50, 50),
    25,
    25,
    rgba(255, 255, 0, 255),
    10
  )
  image.writeFile("tests/images/strokeEllipse.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.fillPolygon(
    vec2(50, 50),
    30,
    6,
    rgba(255, 255, 0, 255)
  )
  image.writeFile("tests/images/drawPolygon.png")

block:
  let image = newImage(100, 100)
  image.fill(rgba(0, 255, 255, 255))
  image.strokePolygon(
    vec2(50, 50),
    30,
    6,
    rgba(255, 255, 0, 255),
    10
  )
  image.writeFile("tests/images/strokePolygon.png")
