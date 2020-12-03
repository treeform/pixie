import chroma, pixie, fidget/opengl/perf

const iterations = 100

proc fillOriginal(a: Image, rgba: ColorRGBA) =
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      a.setRgbaUnsafe(x, y, rgba)

proc invertOriginal(a: Image) =
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      rgba.r = 255 - rgba.r
      rgba.g = 255 - rgba.g
      rgba.b = 255 - rgba.b
      rgba.a = 255 - rgba.a
      a.setRgbaUnsafe(x, y, rgba)

timeIt "fillOriginal":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a.fillOriginal(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)

timeIt "fill":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a.fill(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)

timeIt "invertOriginal":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a.invertOriginal()

timeIt "invert":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a.invert()
