import benchy, chroma, pixie, vmath

let
  a = newImage(1000, 1000)
  b = newImage(1000, 1000)

b.fill(rgba(127, 127, 127, 255))

timeIt "bmNormal":
  a.draw(b, vec2(0, 0), bmNormal)

timeIt "bmDarken":
  a.draw(b, vec2(0, 0), bmDarken)

timeIt "bmMultiply":
  a.draw(b, vec2(0, 0), bmMultiply)
