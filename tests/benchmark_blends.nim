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

timeIt "bmLinearBurn":
  a.draw(b, vec2(0, 0), bmLinearBurn)

timeIt "bmColorBurn":
  a.draw(b, vec2(0, 0), bmColorBurn)

timeIt "bmLighten":
  a.draw(b, vec2(0, 0), bmLighten)

timeIt "bmScreen":
  a.draw(b, vec2(0, 0), bmScreen)

timeIt "bmLinearDodge":
  a.draw(b, vec2(0, 0), bmLinearDodge)

timeIt "bmColorDodge":
  a.draw(b, vec2(0, 0), bmColorDodge)

timeIt "bmOverlay":
  a.draw(b, vec2(0, 0), bmOverlay)

timeIt "bmSoftLight":
  a.draw(b, vec2(0, 0), bmSoftLight)

timeIt "bmHardLight":
  a.draw(b, vec2(0, 0), bmHardLight)

timeIt "bmDifference":
  a.draw(b, vec2(0, 0), bmDifference)

timeIt "bmExclusion":
  a.draw(b, vec2(0, 0), bmExclusion)

timeIt "bmHue":
  a.draw(b, vec2(0, 0), bmHue)

timeIt "bmSaturation":
  a.draw(b, vec2(0, 0), bmSaturation)

timeIt "bmColor":
  a.draw(b, vec2(0, 0), bmColor)

timeIt "bmLuminosity":
  a.draw(b, vec2(0, 0), bmLuminosity)

timeIt "bmMask":
  a.draw(b, vec2(0, 0), bmMask)

timeIt "bmSubtractMask":
  a.draw(b, vec2(0, 0), bmSubtractMask)

timeIt "bmIntersectMask":
  a.draw(b, vec2(0, 0), bmIntersectMask)

timeIt "bmExcludeMask":
  a.draw(b, vec2(0, 0), bmExcludeMask)
