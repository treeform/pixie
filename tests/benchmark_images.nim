import chroma, pixie, benchy, system/memory

proc fill1(a: Image, rgba: ColorRGBA) =
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      a.setRgbaUnsafe(x, y, rgba)

proc fill2*(image: Image, rgba: ColorRgba) =
  ## Fills the image with a solid color.
  if rgba.r == rgba.g and rgba.r == rgba.b and rgba.r == rgba.a:
    nimSetMem(image.data[0].addr, rgba.r.cint, image.data.len * 4)
  else:
    for c in image.data.mitems:
      c = rgba

proc invert1(a: Image) =
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      rgba.r = 255 - rgba.r
      rgba.g = 255 - rgba.g
      rgba.b = 255 - rgba.b
      rgba.a = 255 - rgba.a
      a.setRgbaUnsafe(x, y, rgba)

proc invert2*(image: Image) =
  for rgba in image.data.mitems:
    rgba.r = 255 - rgba.r
    rgba.g = 255 - rgba.g
    rgba.b = 255 - rgba.b
    rgba.a = 255 - rgba.a

proc applyOpacity1(a: Image, opacity: float32): Image =
  result = newImage(a.width, a.height)
  let op = (255 * opacity).uint32
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      rgba.a = ((rgba.a.uint32 * op) div 255).clamp(0, 255).uint8
      result.setRgbaUnsafe(x, y, rgba)

proc sharpOpacity1(a: Image): Image =
  result = newImage(a.width, a.height)
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      if rgba.a == 0:
        result.setRgbaUnsafe(x, y, rgba(0, 0, 0, 0))
      else:
        result.setRgbaUnsafe(x, y, rgba(255, 255, 255, 255))

var a = newImage(2560, 1440)

timeIt "fill1":
  a.fill1(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)
  keep(a)

timeIt "fill2":
  a.fill2(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)
  keep(a)

timeIt "fill":
  a.fill(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)
  keep(a)

timeIt "fill1_rgba":
  a.fill1(rgba(63, 127, 191, 255))
  doAssert a[0, 0] == rgba(63, 127, 191, 255)
  keep(a)

timeIt "fill2_rgba":
  a.fill2(rgba(63, 127, 191, 255))
  doAssert a[0, 0] == rgba(63, 127, 191, 255)
  keep(a)

timeIt "fill_rgba":
  a.fill(rgba(63, 127, 191, 255))
  doAssert a[0, 0] == rgba(63, 127, 191, 255)
  keep(a)

timeIt "invert1":
  a.invert1()
  keep(a)

timeIt "invert2":
  a.invert2()
  keep(a)

timeIt "invert":
  a.invert()
  keep(a)

timeIt "applyOpacity1":
  a = a.applyOpacity1(0.5)
  keep(a)

timeIt "applyOpacity":
  a.applyOpacity(0.5)
  keep(a)

timeIt "sharpOpacity1":
  a = a.sharpOpacity1()
  keep(a)

timeIt "sharpOpacity":
  a.sharpOpacity()
  keep(a)
