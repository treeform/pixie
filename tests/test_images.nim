import chroma, pixie, pixie/internal, vmath, xrays

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

  a.xray("tests/images/flipped1.png")
  a.flipVertical()
  a.xray("tests/images/flipped2.png")
  a.flipHorizontal()
  a.xray("tests/images/flipped3.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(-10, 0, 20, 20)
  b.xray("tests/images/superimage1.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(-10, -10, 20, 20)
  b.xray("tests/images/superimage2.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(90, 0, 120, 120)
  b.xray("tests/images/superimage3.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(90, 90, 120, 120)
  b.xray("tests/images/superimage4.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(-10, -10, 120, 120)
  b.xray("tests/images/superimage5.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.superImage(45, 45, 20, 20)
  b.xray("tests/images/superimage6.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.minifyBy2()
  b.xray("tests/images/minifiedBy2.png")

block:
  let
    a = readImage("tests/images/minifiedBy2.png")
    b = a.magnifyBy2()
  b.xray("tests/images/magnifiedBy2.png")

block:
  let
    a = readImage("tests/images/flipped1.png")
    b = a.minifyBy2(2)
  b.xray("tests/images/minifiedBy4.png")

block:
  let
    a = readImage("tests/images/minifiedBy4.png")
    b = a.magnifyBy2(2)
  b.xray("tests/images/magnifiedBy4.png")

block:
  let
    a = readImage("tests/fileformats/png/mandrill.png")
    b = a.minifyBy2()
  b.xray("tests/images/minifiedMandrill.png")

block:
  let a = newImage(100, 100)
  a.fill(rgbx(50, 100, 150, 200))
  a.invert()
  doAssert a[0, 0] == rgbx(44, 33, 23, 55)

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 255, 255)
  ctx.image.fill(rgba(0, 0, 0, 255))
  ctx.fillRect(rect(25, 25, 50, 50), )
  ctx.image.blur(20)
  ctx.image.xray("tests/images/imageblur20.png")

block:
  let ctx = newContext(100, 100)
  ctx.fillStyle = rgba(255, 255, 255, 255)
  ctx.image.fill(rgba(0, 0, 0, 255))
  ctx.fillRect(rect(25, 25, 50, 50))
  ctx.image.blur(20, rgba(0, 0, 0, 255))
  ctx.image.xray("tests/images/imageblur20oob.png")

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

block:
  var
    colors: seq[ColorRGBA]
    premultiplied: seq[ColorRGBX]
  for a in 0.uint8 .. 255:
    for r in 0.uint8 .. 255:
      let
        rgba = rgba(r, 0, 0, a)
        floats = rgba.color()
        premul = color(floats.r * floats.a, 0, 0, floats.a)
        rgbx = rgbx(
          round(premul.r * 255).uint8,
          0,
          0,
          round(premul.a * 255).uint8
        )
      colors.add(rgba)
      premultiplied.add(rgbx)

  var converted = cast[seq[ColorRGBX]](colors)
  toPremultipliedAlpha(converted)

  for i in 0 ..< premultiplied.len:
    doAssert premultiplied[i] == converted[i]
    doAssert colors[i].rgbx == converted[i]

block:
  let image = newImage(100, 100)
  image.fill("white")
  doAssert image[10, 10] == rgba(255, 255, 255, 255)

block:
  # opaqueBounds of fully transparent image.
  let image = newImage(100, 100)
  doAssert image.opaqueBounds() == rect(0, 0, 0, 0)

block:
  # opaqueBounds of fully opaque image.
  let image = newImage(100, 100)
  image.fill(rgbx(255, 255, 255, 255))
  doAssert image.opaqueBounds() == rect(0.0, 0.0, 100.0, 100.0)

block:
  let image = newImage(160, 160)
  image.fillPath(
    """
      M 20 20
      L 140 20
      L 80 140
      z
    """,
    parseHtmlColor("#FC427B").rgba,
    scale(vec2(0.3, 0.3))
  )
  let rect = image.opaqueBounds()
  let trimmedImage = image.subImage(rect)
  trimmedImage.xray("tests/images/opaqueBounds.png")
