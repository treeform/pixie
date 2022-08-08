## Blending modes.

import chroma, common

# See https://www.w3.org/TR/compositing-1/
# See https://www.khronos.org/registry/OpenGL/extensions/KHR/KHR_blend_equation_advanced.txt

type
  Blender* = proc(backdrop, source: ColorRGBX): ColorRGBX {.gcsafe, raises: [].}
    ## Function signature returned by blender.

when defined(release):
  {.push checks: off.}

proc min(a, b: uint32): uint32 {.inline.} =
  if a < b: a else: b

proc alphaFix(backdrop, source, mixed: ColorRGBA): ColorRGBA =
  ## After mixing an image, adjust its alpha value to be correct.
  let
    sa = source.a.uint32
    ba = backdrop.a.uint32
    t0 = sa * (255 - ba)
    t1 = sa * ba
    t2 = (255 - sa) * ba

  let
    r = t0 * source.r.uint32 + t1 * mixed.r.uint32 + t2 * backdrop.r.uint32
    g = t0 * source.g.uint32 + t1 * mixed.g.uint32 + t2 * backdrop.g.uint32
    b = t0 * source.b.uint32 + t1 * mixed.b.uint32 + t2 * backdrop.b.uint32
    a = sa + ba * (255 - sa) div 255

  if a == 0:
    return

  result.r = (r div a div 255).uint8
  result.g = (g div a div 255).uint8
  result.b = (b div a div 255).uint8
  result.a = a.uint8

proc blendAlpha*(backdrop, source: uint8): uint8 {.inline.} =
  ## Blends alphas of backdrop, source.
  source + ((backdrop.uint32 * (255 - source)) div 255).uint8

proc screen(backdrop, source: uint32): uint8 {.inline.} =
  ((backdrop + source).int32 - ((backdrop * source) div 255).int32).uint8

proc hardLight(
  backdropColor, backdropAlpha, sourceColor, sourceAlpha: uint32
): uint8 {.inline.} =
  if sourceColor * 2 <= sourceAlpha:
    ((
      2 * sourceColor * backdropColor +
      (sourceColor * (255 - backdropAlpha)) +
      (backdropColor * (255 - sourceAlpha))
    ) div 255).uint8
  else:
    screen(backdropColor, sourceColor)

proc blendNormal*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  if backdrop.a == 0 or source.a == 255:
    return source
  if source.a == 0:
    return backdrop

  let k = (255 - source.a.uint32)
  result.r = source.r + ((backdrop.r.uint32 * k) div 255).uint8
  result.g = source.g + ((backdrop.g.uint32 * k) div 255).uint8
  result.b = source.b + ((backdrop.b.uint32 * k) div 255).uint8
  result.a = blendAlpha(backdrop.a, source.a)

proc blendDarken*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  proc blend(
    backdropColor, backdropAlpha, sourceColor, sourceAlpha: uint8
  ): uint8 {.inline.} =
    min(
      backdropColor + ((255 - backdropAlpha).uint32 * sourceColor) div 255,
      sourceColor + ((255 - sourceAlpha).uint32 * backdropColor) div 255
    ).uint8

  result.r = blend(backdrop.r, backdrop.a, source.r, source.a)
  result.g = blend(backdrop.g, backdrop.a, source.g, source.a)
  result.b = blend(backdrop.b, backdrop.a, source.b, source.a)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendMultiply*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  proc blend(
    backdropColor, backdropAlpha, sourceColor, sourceAlpha: uint8
  ): uint8 {.inline.} =
    ((
      (255 - backdropAlpha).uint32 * sourceColor +
      (255 - sourceAlpha).uint32 * backdropColor +
      backdropColor.uint32 * sourceColor
    ) div 255).uint8

  result.r = blend(backdrop.r, backdrop.a, source.r, source.a)
  result.g = blend(backdrop.g, backdrop.a, source.g, source.a)
  result.b = blend(backdrop.b, backdrop.a, source.b, source.a)
  result.a = blendAlpha(backdrop.a, source.a)

# proc blendLinearBurn(backdrop, source: ColorRGBX): ColorRGBX =
#   let
#     backdrop = backdrop.toStraightAlpha()
#     source = source.toStraightAlpha()
#   result.r = min(0, backdrop.r.int32 + source.r.int32 - 255).uint8
#   result.g = min(0, backdrop.g.int32 + source.g.int32 - 255).uint8
#   result.b = min(0, backdrop.b.int32 + source.b.int32 - 255).uint8
#   result = alphaFix(backdrop, source, result)
#   result = result.toPremultipliedAlpha()

proc blendColorBurn*(backdrop, source: ColorRGBX): ColorRGBX =
  let
    backdrop = backdrop.rgba()
    source = source.rgba()
  proc blend(backdrop, source: uint32): uint8 {.inline.} =
    if backdrop == 255:
      255.uint8
    elif source == 0:
      0
    else:
      255 - min(255, (255 * (255 - backdrop)) div source).uint8
  var blended: ColorRGBA
  blended.r = blend(backdrop.r, source.r)
  blended.g = blend(backdrop.g, source.g)
  blended.b = blend(backdrop.b, source.b)
  result = alphaFix(backdrop, source, blended).rgbx()

proc blendLighten*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  proc blend(
    backdropColor, backdropAlpha, sourceColor, sourceAlpha: uint8
  ): uint8 {.inline.} =
    max(
      backdropColor + ((255 - backdropAlpha).uint32 * sourceColor) div 255,
      sourceColor + ((255 - sourceAlpha).uint32 * backdropColor) div 255
    ).uint8

  result.r = blend(backdrop.r, backdrop.a, source.r, source.a)
  result.g = blend(backdrop.g, backdrop.a, source.g, source.a)
  result.b = blend(backdrop.b, backdrop.a, source.b, source.a)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendScreen*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  result.r = screen(backdrop.r, source.r)
  result.g = screen(backdrop.g, source.g)
  result.b = screen(backdrop.b, source.b)
  result.a = blendAlpha(backdrop.a, source.a)

# proc blendLinearDodge(backdrop, source: ColorRGBX): ColorRGBX =
#   let
#     backdrop = backdrop.toStraightAlpha()
#     source = source.toStraightAlpha()
#   result.r = min(backdrop.r.uint32 + source.r, 255).uint8
#   result.g = min(backdrop.g.uint32 + source.g, 255).uint8
#   result.b = min(backdrop.b.uint32 + source.b, 255).uint8
#   result = alphaFix(backdrop, source, result)
#   result = result.toPremultipliedAlpha()

proc blendColorDodge*(backdrop, source: ColorRGBX): ColorRGBX =
  let
    backdrop = backdrop.rgba()
    source = source.rgba()
  proc blend(backdrop, source: uint32): uint8 {.inline.} =
    if backdrop == 0:
      0.uint8
    elif source == 255:
      255
    else:
      min(255, (255 * backdrop) div (255 - source)).uint8
  var blended: ColorRGBA
  blended.r = blend(backdrop.r, source.r)
  blended.g = blend(backdrop.g, source.g)
  blended.b = blend(backdrop.b, source.b)
  result = alphaFix(backdrop, source, blended).rgbx()

proc blendOverlay*(backdrop, source: ColorRGBX): ColorRGBX =
  result.r = hardLight(source.r, source.a, backdrop.r, backdrop.a)
  result.g = hardLight(source.g, source.a, backdrop.g, backdrop.a)
  result.b = hardLight(source.b, source.a, backdrop.b, backdrop.a)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendSoftLight*(backdrop, source: ColorRGBX): ColorRGBX =
  blendSoftLight(backdrop.color, source.color).rgbx

proc blendHardLight*(backdrop, source: ColorRGBX): ColorRGBX =
  result.r = hardLight(backdrop.r, backdrop.a, source.r, source.a)
  result.g = hardLight(backdrop.g, backdrop.a, source.g, source.a)
  result.b = hardLight(backdrop.b, backdrop.a, source.b, source.a)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendDifference*(backdrop, source: ColorRGBX): ColorRGBX =
  proc blend(
    backdropColor, backdropAlpha, sourceColor, sourceAlpha: uint8
  ): uint8 {.inline.} =
    ((backdropColor + sourceColor).int32 - 2 *
      (min(
        backdropColor.uint32 * sourceAlpha,
        sourceColor.uint32 * backdropAlpha
      ) div 255).int32
    ).uint8

  result.r = blend(backdrop.r, backdrop.a, source.r, source.a)
  result.g = blend(backdrop.g, backdrop.a, source.g, source.a)
  result.b = blend(backdrop.b, backdrop.a, source.b, source.a)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendExclusion*(backdrop, source: ColorRGBX): ColorRGBX =
  proc blend(backdrop, source: uint32): uint8 {.inline.} =
    let v = (backdrop + source).int32 - ((2 * backdrop * source) div 255).int32
    max(0, v).uint8
  result.r = blend(backdrop.r.uint32, source.r.uint32)
  result.g = blend(backdrop.g.uint32, source.g.uint32)
  result.b = blend(backdrop.b.uint32, source.b.uint32)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendColor*(backdrop, source: ColorRGBX): ColorRGBX =
  blendColor(backdrop.color, source.color).rgbx

proc blendLuminosity*(backdrop, source: ColorRGBX): ColorRGBX =
  blendLuminosity(backdrop.color, source.color).rgbx

proc blendHue*(backdrop, source: ColorRGBX): ColorRGBX =
  blendHue(backdrop.color, source.color).rgbx

proc blendSaturation*(backdrop, source: ColorRGBX): ColorRGBX =
  blendSaturation(backdrop.color, source.color).rgbx

proc blendMask*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  let k = source.a.uint32
  result.r = ((backdrop.r * k) div 255).uint8
  result.g = ((backdrop.g * k) div 255).uint8
  result.b = ((backdrop.b * k) div 255).uint8
  result.a = ((backdrop.a * k) div 255).uint8

proc blendSubtractMask*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  let a = (backdrop.a.uint32 * (255 - source.a)) div 255
  result.r = ((backdrop.r * a) div 255).uint8
  result.g = ((backdrop.g * a) div 255).uint8
  result.b = ((backdrop.b * a) div 255).uint8
  result.a = a.uint8

proc blendExcludeMask*(backdrop, source: ColorRGBX): ColorRGBX {.inline.} =
  let a = max(backdrop.a, source.a).uint32 - min(backdrop.a, source.a)
  result.r = ((source.r * a) div 255).uint8
  result.g = ((source.g * a) div 255).uint8
  result.b = ((source.b * a) div 255).uint8
  result.a = a.uint8

proc normalBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendNormal(backdrop, source)

proc darkenBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendDarken(backdrop, source)

proc multiplyBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendMultiply(backdrop, source)

proc lightenBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendLighten(backdrop, source)

proc screenBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendScreen(backdrop, source)

proc maskBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendMask(backdrop, source)

proc overwriteBlender(backdrop, source: ColorRGBX): ColorRGBX =
  source

proc subtractMaskBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendSubtractMask(backdrop, source)

proc excludeMaskBlender(backdrop, source: ColorRGBX): ColorRGBX =
  blendExcludeMask(backdrop, source)

proc blender*(blendMode: BlendMode): Blender {.raises: [].} =
  ## Returns a blend function for a given blend mode.
  case blendMode:
  of NormalBlend: normalBlender
  of DarkenBlend: darkenBlender
  of MultiplyBlend: multiplyBlender
  # of BlendLinearBurn: blendLinearBurn
  of ColorBurnBlend: blendColorBurn
  of LightenBlend: lightenBlender
  of ScreenBlend: screenBlender
  # of BlendLinearDodge: blendLinearDodge
  of ColorDodgeBlend: blendColorDodge
  of OverlayBlend: blendOverlay
  of SoftLightBlend: blendSoftLight
  of HardLightBlend: blendHardLight
  of DifferenceBlend: blendDifference
  of ExclusionBlend: blendExclusion
  of HueBlend: blendHue
  of SaturationBlend: blendSaturation
  of ColorBlend: blendColor
  of LuminosityBlend: blendLuminosity
  of MaskBlend: maskBlender
  of OverwriteBlend: overwriteBlender
  of SubtractMaskBlend: subtractMaskBlender
  of ExcludeMaskBlend: excludeMaskBlender

when defined(release):
  {.pop.}
