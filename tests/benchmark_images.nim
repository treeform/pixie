import chroma, pixie, benchy

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

reset()

timeIt "subImage":
  keep image.subImage(0, 0, 256, 256)

reset()

# timeIt "superImage":
#   discard

reset()

timeIt "minifyBy2":
  let minified = image.minifyBy2()
  doAssert minified[0, 0] == rgba(63, 127, 191, 191)

reset()

timeIt "invert":
  image.invert()

reset()

timeIt "applyOpacity":
  image.applyOpacity(0.5)

reset()

timeIt "toPremultipliedAlpha":
  image.toPremultipliedAlpha()

reset()

timeIt "toStraightAlpha":
  image.toStraightAlpha()

reset()

block:
  var path: Path
  path.ellipse(image.width / 2, image.height / 2, 300, 300)

  let mask = newMask(image.width, image.height)
  mask.fillPath(path)

  timeIt "mask":
    image.draw(mask)

reset()

timeIt "newMask":
  let mask = image.newMask()
  doAssert mask[0, 0] == image[0, 0].a

reset()

timeIt "blur":
  image.blur(40)

reset()

timeIt "lerp integers":
  for i in 0 ..< 100000:
    let c = image[0, 0]
    var z: int
    for t in 0 .. 100:
      z += lerp(c, c, t.float32 / 100).a.int
    doAssert z > 0

timeIt "lerp floats":
  for i in 0 ..< 100000:
    let c = image[0, 0]
    var z: int
    for t in 0 .. 100:
      z += lerp(c.color, c.color, t.float32 / 100).rgba().a.int
    doAssert z > 0
