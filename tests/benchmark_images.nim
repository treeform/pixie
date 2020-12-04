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

proc applyOpacityOriginal(a: Image, opacity: float32): Image =
  result = newImage(a.width, a.height)
  let op = (255 * opacity).uint32
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      rgba.a = ((rgba.a.uint32 * op) div 255).clamp(0, 255).uint8
      result.setRgbaUnsafe(x, y, rgba)

proc sharpOpacityOriginal(a: Image): Image =
  result = newImage(a.width, a.height)
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      if rgba.a == 0:
        result.setRgbaUnsafe(x, y, rgba(0, 0, 0, 0))
      else:
        result.setRgbaUnsafe(x, y, rgba(255, 255, 255, 255))

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

timeIt "applyOpacityOriginal":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a = a.applyOpacityOriginal(0.5)

timeIt "applyOpacity":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a.applyOpacity(0.5)

timeIt "sharpOpacityOriginal":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a = a.sharpOpacityOriginal()

timeIt "sharpOpacity":
  var a = newImage(2560, 1440)
  for i in 0 ..< iterations:
    a.sharpOpacity()
