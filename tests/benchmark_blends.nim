import benchy, chroma, vmath, pixie/images

include pixie/blends

let
  backdrop = newImage(256, 256)
  source = newImage(256, 256)
source.fill(rgba(100, 100, 100, 100))

template reset() =
  backdrop.fill(rgba(0, 0, 0, 255))

reset()

timeIt "blendNormal":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendNormal(backdrop.data[i], source.data[i])

reset()

timeIt "blendNormalFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendNormalFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendDarken":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendDarken(backdrop.data[i], source.data[i])

reset()

timeIt "blendDarkenFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendDarkenFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendMultiply":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendMultiply(backdrop.data[i], source.data[i])

reset()

timeIt "blendMultiplyFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendMultiplyFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendLinearBurn":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLinearBurn(backdrop.data[i], source.data[i])

reset()

timeIt "blendLinearBurnFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLinearBurnFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendColorBurn":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColorBurn(backdrop.data[i], source.data[i])

reset()

timeIt "blendColorBurnFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColorBurnFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendLighten":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLighten(backdrop.data[i], source.data[i])

reset()

timeIt "blendLightenFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLightenFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendScreen":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendScreen(backdrop.data[i], source.data[i])

reset()

timeIt "blendScreenFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendScreenFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendLinearDodge":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLinearDodge(backdrop.data[i], source.data[i])

reset()

timeIt "blendLinearDodgeFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLinearDodgeFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendColorDodge":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColorDodge(backdrop.data[i], source.data[i])

reset()

timeIt "blendColorDodgeFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColorDodgeFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendOverlay":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendOverlay(backdrop.data[i], source.data[i])

reset()

timeIt "blendOverlayFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendOverlayFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendSoftLight":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSoftLight(backdrop.data[i], source.data[i])

reset()

timeIt "blendSoftLightFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSoftLightFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendHardLight":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendHardLight(backdrop.data[i], source.data[i])

reset()

timeIt "blendHardLightFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendHardLightFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendDifference":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendDifference(backdrop.data[i], source.data[i])

reset()

timeIt "blendDifferenceFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendDifferenceFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendExclusion":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendExclusion(backdrop.data[i], source.data[i])

reset()

timeIt "blendExclusionFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendExclusionFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendHue":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendHue(backdrop.data[i], source.data[i])

reset()

timeIt "blendHueFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendHueFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendSaturation":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSaturation(backdrop.data[i], source.data[i])

reset()

timeIt "blendSaturationFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSaturationFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendColor":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColor(backdrop.data[i], source.data[i])

reset()

timeIt "blendColorFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColorFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendLuminosity":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLuminosity(backdrop.data[i], source.data[i])

reset()

timeIt "blendLuminosityFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLuminosityFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendMask":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendMask(backdrop.data[i], source.data[i])

reset()

timeIt "blendMaskFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendMaskFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendSubtractMask":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSubtractMask(backdrop.data[i], source.data[i])

reset()

timeIt "blendSubtractMaskFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSubtractMaskFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendIntersectMask":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendIntersectMask(backdrop.data[i], source.data[i])

reset()

timeIt "blendIntersectMaskFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendIntersectMaskFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendExcludeMask":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendExcludeMask(backdrop.data[i], source.data[i])

reset()

timeIt "blendExcludeMaskFloats":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendExcludeMaskFloats(
      backdrop.data[i].color, source.data[i].color
    ).rgba

reset()

timeIt "blendNormalPremultiplied":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendNormalPremultiplied(backdrop.data[i], source.data[i])

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

  timeIt "blendNormalPremultiplied [simd]":
    for i in countup(0, backdrop.data.len - 4, 4):
      let
        b = mm_loadu_si128(backdrop.data[i].addr)
        s = mm_loadu_si128(source.data[i].addr)
      mm_storeu_si128(backdrop.data[i].addr, blendNormalPremultiplied(b, s))
