import pixie, chroma, vmath

block:
  let image = newImage(10, 10)
  image[0, 0] = rgba(255, 255, 255, 255)
  doAssert image[0, 0] == rgba(255, 255, 255, 255)

block:
  let image = newImage(10, 10)
  image.fill(rgba(255, 0, 0, 255))
  doAssert image[0, 0] == rgba(255, 0, 0, 255)

block:
  let
    image = newImage(256, 256)
    subImage = image.subImage(0, 0, 128, 128)
  doAssert subImage.width == 128 and subImage.height == 128

block:
  let image = newImage(10, 10)
  image.fill(rgba(255, 0, 0, 128))
  image.toPremultipliedAlpha()
  doAssert image[9, 9] == rgba(128, 0, 0, 128)

block:
  let image = newImage(10, 10)
  image.fill(rgba(128, 0, 0, 128))
  image.toStraightAlpha()
  doAssert image[9, 9] == rgba(254, 0, 0, 128)

block:
  let
    a = newImage(101, 101)
    b = newImage(50, 50)

  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, vec2(0, 0))

  a.writeFile("tests/images/flipped1.png")
  a.flipVertical()
  a.writeFile("tests/images/flipped2.png")
  a.flipHorizontal()
  a.writeFile("tests/images/flipped3.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(-10, 0, 20, 20)
  b.writeFile("tests/images/superimage1.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(-10, -10, 20, 20)
  b.writeFile("tests/images/superimage2.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(90, 0, 120, 120)
  b.writeFile("tests/images/superimage3.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(90, 90, 120, 120)
  b.writeFile("tests/images/superimage4.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(-10, -10, 120, 120)
  b.writeFile("tests/images/superimage5.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(45, 45, 20, 20)
  b.writeFile("tests/images/superimage6.png")
