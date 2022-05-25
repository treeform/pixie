import benchy, chroma, pixie, pixie/internal

let image = newImage(2560, 1440)

proc reset() =
  image.fill(rgba(63, 127, 191, 191))

reset()

timeIt "fill":
  image.fill(rgba(255, 255, 255, 255))
  doAssert image[0, 0] == rgba(255, 255, 255, 255)

reset()

timeIt "fill_rgba":
  image.fill(rgba(63, 127, 191, 191))
  doAssert image[0, 0] == rgba(63, 127, 191, 191)

image.fill(rgba(100, 0, 100, 100))
timeIt "isOneColor":
  doAssert image.isOneColor()

image.fill(rgba(0, 0, 0, 0))
timeIt "isTransparent":
  doAssert image.isTransparent()

image.fill(rgba(255, 255, 255, 255))
timeIt "isOpaque":
  doAssert image.isOpaque()

reset()

timeIt "subImage":
  keep image.subImage(0, 0, 256, 256)

reset()

timeIt "superImage":
  keep image.superImage(-10, -10, 2580, 1460)

reset()

timeIt "minifyBy2":
  let minified = image.minifyBy2()
  doAssert minified[0, 0] == rgba(63, 127, 191, 191)

reset()

timeIt "magnifyBy2":
  let minified = image.magnifyBy2()
  doAssert minified[0, 0] == rgba(63, 127, 191, 191)

reset()

timeIt "flipHorizontal":
  image.flipHorizontal()

reset()

timeIt "flipVertical":
  image.flipVertical()

reset()

timeIt "rotate90":
  image.rotate90()

reset()

timeIt "invert":
  image.invert()

reset()

timeIt "applyOpacity":
  image.applyOpacity(0.5)

reset()

timeIt "toPremultipliedAlpha":
  image.data.toPremultipliedAlpha()

reset()

timeIt "toStraightAlpha":
  image.data.toStraightAlpha()

reset()

block:
  let path = newPath()
  path.ellipse(image.width / 2, image.height / 2, 300, 300)

  let mask = newMask(image.width, image.height)
  mask.fillPath(path)

  timeIt "mask":
    image.draw(mask)

reset()

timeIt "newMask(image)":
  let mask = image.newMask()
  doAssert mask[0, 0] == image[0, 0].a

reset()

block:
  let mask = image.newMask()

  timeIt "newImage(mask)":
    let image = newImage(mask)
    doAssert mask[0, 0] == image[0, 0].a

  reset()

timeIt "blur":
  image.blur(40)

reset()

timeIt "mix integers":
  for i in 0 ..< 100000:
    let c = image[0, 0]
    var z: int
    for t in 0 .. 100:
      z += mix(c, c, t.float32 / 100).a.int
    doAssert z > 0

timeIt "mix floats":
  for i in 0 ..< 100000:
    let c = image[0, 0]
    var z: int
    for t in 0 .. 100:
      z += mix(c.color, c.color, t.float32 / 100).rgba().a.int
    doAssert z > 0
