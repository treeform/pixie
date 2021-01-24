import chroma, pixie, benchy

let a = newImage(2560, 1440)

timeIt "fill":
  a.fill(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)
  keep(a)

timeIt "fill_rgba":
  a.fill(rgba(63, 127, 191, 191))
  doAssert a[0, 0] == rgba(63, 127, 191, 191)
  keep(a)

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

timeIt "toAlphy":
  a.toAlphy()

timeIt "fromAlphy":
  a.fromAlphy()
