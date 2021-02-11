import chroma, pixie, vmath

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
