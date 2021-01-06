import chroma, pixie, benchy, system/memory

let a = newImage(2560, 1440)

timeIt "fill":
  a.fill(rgba(255, 255, 255, 255))
  doAssert a[0, 0] == rgba(255, 255, 255, 255)
  keep(a)

timeIt "fill_rgba":
  a.fill(rgba(63, 127, 191, 255))
  doAssert a[0, 0] == rgba(63, 127, 191, 255)
  keep(a)

timeIt "invert":
  a.invert()
  keep(a)

timeIt "applyOpacity":
  a.applyOpacity(0.5)
  keep(a)

timeIt "sharpOpacity":
  a.sharpOpacity()
  keep(a)
