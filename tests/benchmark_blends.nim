import benchy, chroma, vmath

include pixie/blends

const iterations = 1_000_000

let
  a = rgba(100, 200, 100, 255)
  b = rgba(25, 33, 100, 127)

timeIt "blendNormal":
  for i in 0 ..< iterations:
    keep blendNormal(a, b)

timeIt "blendNormalFloats":
  for i in 0 ..< iterations:
    keep blendNormalFloats(a.color, b.color).rgba

timeIt "blendDarken":
  for i in 0 ..< iterations:
    keep blendDarken(a, b)

timeIt "blendDarkenFloats":
  for i in 0 ..< iterations:
    keep blendDarkenFloats(a.color, b.color).rgba

timeIt "blendMultiply":
  for i in 0 ..< iterations:
    keep blendMultiply(a, b)

timeIt "blendMultiplyFloats":
  for i in 0 ..< iterations:
    keep blendMultiplyFloats(a.color, b.color).rgba

timeIt "blendLinearBurn":
  for i in 0 ..< iterations:
    keep blendLinearBurn(a, b)

timeIt "blendLinearBurnFloats":
  for i in 0 ..< iterations:
    keep blendLinearBurnFloats(a.color, b.color).rgba

timeIt "blendColorBurn":
  for i in 0 ..< iterations:
    keep blendColorBurn(a, b)

timeIt "blendColorBurnFloats":
  for i in 0 ..< iterations:
    keep blendColorBurnFloats(a.color, b.color).rgba

timeIt "blendLighten":
  for i in 0 ..< iterations:
    keep blendLighten(a, b)

timeIt "blendLightenFloats":
  for i in 0 ..< iterations:
    keep blendLightenFloats(a.color, b.color).rgba

timeIt "blendScreen":
  for i in 0 ..< iterations:
    keep blendScreen(a, b)

timeIt "blendScreenFloats":
  for i in 0 ..< iterations:
    keep blendScreenFloats(a.color, b.color).rgba

timeIt "blendLinearDodge":
  for i in 0 ..< iterations:
    keep blendLinearDodge(a, b)

timeIt "blendLinearDodgeFloats":
  for i in 0 ..< iterations:
    keep blendLinearDodgeFloats(a.color, b.color).rgba

timeIt "blendColorDodge":
  for i in 0 ..< iterations:
    keep blendColorDodge(a, b)

timeIt "blendColorDodgeFloats":
  for i in 0 ..< iterations:
    keep blendColorDodgeFloats(a.color, b.color).rgba

timeIt "blendOverlay":
  for i in 0 ..< iterations:
    keep blendOverlay(a, b)

timeIt "blendOverlayFloats":
  for i in 0 ..< iterations:
    keep blendOverlayFloats(a.color, b.color).rgba

timeIt "blendSoftLight":
  for i in 0 ..< iterations:
    keep blendSoftLight(a, b)

timeIt "blendSoftLightFloats":
  for i in 0 ..< iterations:
    keep blendSoftLightFloats(a.color, b.color).rgba

timeIt "blendHardLight":
  for i in 0 ..< iterations:
    keep blendHardLight(a, b)

timeIt "blendHardLightFloats":
  for i in 0 ..< iterations:
    keep blendHardLightFloats(a.color, b.color).rgba

timeIt "blendDifference":
  for i in 0 ..< iterations:
    keep blendDifference(a, b)

timeIt "blendDifferenceFloats":
  for i in 0 ..< iterations:
    keep blendDifferenceFloats(a.color, b.color).rgba

timeIt "blendExclusion":
  for i in 0 ..< iterations:
    keep blendExclusion(a, b)

timeIt "blendExclusionFloats":
  for i in 0 ..< iterations:
    keep blendExclusionFloats(a.color, b.color).rgba

timeIt "blendHue":
  for i in 0 ..< iterations:
    keep blendHue(a, b)

timeIt "blendHueFloats":
  for i in 0 ..< iterations:
    keep blendHueFloats(a.color, b.color).rgba

timeIt "blendSaturation":
  for i in 0 ..< iterations:
    keep blendSaturation(a, b)

timeIt "blendSaturationFloats":
  for i in 0 ..< iterations:
    keep blendSaturationFloats(a.color, b.color).rgba

timeIt "blendColor":
  for i in 0 ..< iterations:
    keep blendColor(a, b)

timeIt "blendColorFloats":
  for i in 0 ..< iterations:
    keep blendColorFloats(a.color, b.color).rgba

timeIt "blendLuminosity":
  for i in 0 ..< iterations:
    keep blendLuminosity(a, b)

timeIt "blendLuminosityFloats":
  for i in 0 ..< iterations:
    keep blendLuminosityFloats(a.color, b.color).rgba

timeIt "blendMask":
  for i in 0 ..< iterations:
    keep blendMask(a, b)

timeIt "blendMaskFloats":
  for i in 0 ..< iterations:
    keep blendMaskFloats(a.color, b.color).rgba

timeIt "blendSubtractMask":
  for i in 0 ..< iterations:
    keep blendSubtractMask(a, b)

timeIt "blendSubtractMaskFloats":
  for i in 0 ..< iterations:
    keep blendSubtractMaskFloats(a.color, b.color).rgba

timeIt "blendIntersectMask":
  for i in 0 ..< iterations:
    keep blendIntersectMask(a, b)

timeIt "blendIntersectMaskFloats":
  for i in 0 ..< iterations:
    keep blendIntersectMaskFloats(a.color, b.color).rgba

timeIt "blendExcludeMask":
  for i in 0 ..< iterations:
    keep blendExcludeMask(a, b)

timeIt "blendExcludeMaskFloats":
  for i in 0 ..< iterations:
    keep blendExcludeMaskFloats(a.color, b.color).rgba
