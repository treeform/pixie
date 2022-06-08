import chroma, pixie, pixie/internal, vmath

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
  image.data.toPremultipliedAlpha()
  doAssert image[9, 9] == rgba(128, 0, 0, 128)

block:
  var data = newSeq[ColorRGBX](100)
  fillUnsafe(data, rgbx(100, 0, 0, 128), 0, data.len)
  data.toStraightAlpha()
  doAssert data[10] == rgbx(199, 0, 0, 128)

block:
  let image = newImage(100, 100)
  image.fill(rgbx(200, 200, 200, 200))
  image.applyOpacity(0.5)
  doAssert image[0, 0] == rgbx(100, 100, 100, 100)
  doAssert image[88, 88] == rgbx(100, 100, 100, 100)

block:
  let
    a = newImage(101, 101)
    b = newImage(50, 50)

  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b)

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

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.minifyBy2()
  b.writeFile("tests/images/minifiedBy2.png")

block:
  let
    a = readImage("tests/images/minifiedBy2.png")
    b = a.magnifyBy2()
  b.writeFile("tests/images/magnifiedBy2.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.minifyBy2(2)
  b.writeFile("tests/images/minifiedBy4.png")

block:
  let
    a = readImage("tests/images/minifiedBy4.png")
    b = a.magnifyBy2(2)
  b.writeFile("tests/images/magnifiedBy4.png")

block:
  let
    a = readImage("tests/fileformats/png/mandrill.png")
    b = a.minifyBy2()
  b.writeFile("tests/images/minifiedMandrill.png")

block:
  let a = newImage(100, 100)
  a.fill(rgbx(50, 100, 150, 200))
  a.invert()
  doAssert a[0, 0] == rgbx(44, 33, 22, 55)

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 255, 255)
  ctx.image.fill(rgba(0, 0, 0, 255))
  ctx.fillRect(rect(25, 25, 50, 50), )
  ctx.image.blur(20)
  ctx.image.writeFile("tests/images/imageblur20.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 255, 255)
  ctx.image.fill(rgba(0, 0, 0, 255))
  ctx.fillRect(rect(25, 25, 50, 50))
  ctx.image.blur(20, rgba(0, 0, 0, 255))
  ctx.image.writeFile("tests/images/imageblur20oob.png")

block: # Test conversion between image and mask
  let
    originalImage = newImage(100, 100)
    originalMask = newMask(100, 100)

  let p = newPath()
  p.circle(50, 50, 25)

  originalImage.fillPath(p, rgba(255, 0, 0, 255))
  originalMask.fillPath(p)

  # Converting an image to a mask == a mask of the same fill
  doAssert newMask(originalImage).data == originalMask.data

  # Converting a mask to an image == converting an image to a mask as an image
  doAssert newImage(newMask(originalImage)).data == newImage(originalMask).data

block:
  let p = newPath()
  p.roundedRect(10, 10, 80, 80, 10, 10, 10, 10)

  let image = newImage(100, 100)
  image.fillPath(p, rgba(255, 0, 0, 255))

  newImage(newMask(image)).writeFile("tests/images/mask2image.png")

block:
  let image = newImage(100, 100)
  doAssert image.isOneColor()

block:
  let image = newImage(100, 100)
  image.fill(rgba(255, 255, 255, 255))
  doAssert image.isOneColor()

block:
  let image = newImage(100, 100)
  image.fill(rgba(1, 2, 3, 4))
  doAssert image.isOneColor()

block:
  let image = newImage(100, 100)
  image[99, 99] = rgba(255, 255, 255, 255)
  doAssert not image.isOneColor()

block:
  let image = newImage(100, 100)
  doAssert image.isTransparent()

block:
  let image = newImage(100, 100)
  image.fill(rgba(255, 255, 255, 0))
  doAssert image.isTransparent()

block:
  let image = newImage(100, 100)
  image[99, 99] = rgba(255, 255, 255, 255)
  doAssert not image.isTransparent()

block:
  let image = newImage(100, 100)
  image.fill(rgba(255, 255, 255, 255))
  doAssert not image.isTransparent()

block:
  let image = newImage(100, 100)
  image.fill(rgba(255, 255, 255, 255))
  doAssert image.isOpaque()

block:
  let image = newImage(100, 100)
  image.fill(rgba(255, 255, 255, 255))
  image[9, 13] = rgbx(250, 250, 250, 250)
  doAssert not image.isOpaque()

block:
  let a = newImage(400, 400)
  let b = newImage(156, 434)
  b.fill(rgba(255, 0, 0, 255))
  a.draw(
    b,
    mat3(
      -0.5, -4.371138828673793e-008, 0.0,
      -4.371138828673793e-008, 0.5, 0.0,
      292.0, 45.0, 1.0
    )
  )
