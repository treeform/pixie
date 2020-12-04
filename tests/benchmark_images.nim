import chroma, pixie, benchy

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

var a = newImage(2560, 1440)

timeIt "fillOriginal":
  a.fillOriginal(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)
  keep(a)

timeIt "fill":
  a.fill(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)
  keep(a)

timeIt "invertOriginal":
  a.invertOriginal()
  keep(a)

timeIt "invert":
  a.invert()
  keep(a)

timeIt "applyOpacityOriginal":
  a = a.applyOpacityOriginal(0.5)
  keep(a)

timeIt "applyOpacity":
  a.applyOpacity(0.5)
  keep(a)

timeIt "sharpOpacityOriginal":
  a = a.sharpOpacityOriginal()
  keep(a)

timeIt "sharpOpacity":
  a.sharpOpacity()
  keep(a)
