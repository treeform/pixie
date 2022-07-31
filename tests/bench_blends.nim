import benchy, chroma, pixie/blends, pixie/images, vmath

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

timeIt "blendDarken":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendDarken(backdrop.data[i], source.data[i])

reset()

timeIt "blendMultiply":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendMultiply(backdrop.data[i], source.data[i])

# reset()

# timeIt "blendLinearBurn":
#   for i in 0 ..< backdrop.data.len:
#     backdrop.data[i] = blendLinearBurn(backdrop.data[i], source.data[i])

reset()

timeIt "blendColorBurn":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColorBurn(backdrop.data[i], source.data[i])

reset()

timeIt "blendLighten":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLighten(backdrop.data[i], source.data[i])

reset()

timeIt "blendScreen":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendScreen(backdrop.data[i], source.data[i])

# reset()

# timeIt "blendLinearDodge":
#   for i in 0 ..< backdrop.data.len:
#     backdrop.data[i] = blendLinearDodge(backdrop.data[i], source.data[i])

reset()

timeIt "blendColorDodge":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColorDodge(backdrop.data[i], source.data[i])

reset()

timeIt "blendOverlay":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendOverlay(backdrop.data[i], source.data[i])

reset()

timeIt "blendSoftLight":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSoftLight(backdrop.data[i], source.data[i])

reset()

timeIt "blendHardLight":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendHardLight(backdrop.data[i], source.data[i])

reset()

timeIt "blendDifference":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendDifference(backdrop.data[i], source.data[i])

reset()

timeIt "blendExclusion":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendExclusion(backdrop.data[i], source.data[i])

reset()

timeIt "blendHue":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendHue(backdrop.data[i], source.data[i])

reset()

timeIt "blendSaturation":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSaturation(backdrop.data[i], source.data[i])

reset()

timeIt "blendColor":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendColor(backdrop.data[i], source.data[i])

reset()

timeIt "blendLuminosity":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendLuminosity(backdrop.data[i], source.data[i])

reset()

timeIt "blendMask":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendMask(backdrop.data[i], source.data[i])

reset()

timeIt "blendSubtractMask":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendSubtractMask(backdrop.data[i], source.data[i])

reset()

timeIt "blendExcludeMask":
  for i in 0 ..< backdrop.data.len:
    backdrop.data[i] = blendExcludeMask(backdrop.data[i], source.data[i])
