import chroma, pixie, benchy

let a = newImage(2560, 1440)

timeIt "fill":
  a.fill(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)

timeIt "fill_rgba":
  a.fill(rgba(63, 127, 191, 191))
  doAssert a[0, 0] == rgba(63, 127, 191, 191)

timeIt "subImage":
  keep a.subImage(0, 0, 256, 256)

timeIt "invert":
  a.invert()
  keep(a)

timeIt "applyOpacity":
  a.applyOpacity(0.5)
  keep(a)

timeIt "sharpOpacity":
  a.sharpOpacity()
  keep(a)

a.fill(rgba(63, 127, 191, 191))

timeIt "toPremultipliedAlpha":
  a.toPremultipliedAlpha()

timeIt "toStraightAlpha":
  a.toStraightAlpha()

timeIt "lerp integers":
  for i in 0 ..< 100000:
    let c = a[0, 0]
    var z: int
    for t in 0 .. 100:
      z += lerp(c, c, t.float32 / 100).a.int
    doAssert z > 0

timeIt "lerp floats":
  for i in 0 ..< 100000:
    let c = a[0, 0]
    var z: int
    for t in 0 .. 100:
      z += lerp(c.color, c.color, t.float32 / 100).rgba().a.int
    doAssert z > 0
