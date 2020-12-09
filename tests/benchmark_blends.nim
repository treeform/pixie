import benchy, chroma, vmath

include pixie/blends

const iterations = 100_000_000

let
  a = rgba(100, 200, 100, 255)
  b = rgba(25, 33, 100, 127)

timeIt "bmNormal":
  for i in 0 ..< iterations:
    keep blendNormal(a, b)

timeIt "bmDarken":
  for i in 0 ..< iterations:
    keep blendDarken(a, b)

timeIt "bmMultiply":
  for i in 0 ..< iterations:
    keep blendMultiply(a, b)
