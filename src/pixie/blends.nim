## Blending modes.
import chroma, math, nimsimd/sse2

# See https://www.w3.org/TR/compositing-1/
# See https://www.khronos.org/registry/OpenGL/extensions/KHR/KHR_blend_equation_advanced.txt

type
  BlendMode* = enum
    bmNormal
    bmDarken
    bmMultiply
    bmLinearBurn
    bmColorBurn
    bmLighten
    bmScreen
    bmLinearDodge
    bmColorDodge
    bmOverlay
    bmSoftLight
    bmHardLight
    bmDifference
    bmExclusion
    bmHue
    bmSaturation
    bmColor
    bmLuminosity

    bmMask  ## Special blend mode that is used for masking
    bmOverwrite  ## Special that does not blend but copies the pixels from target.
    bmSubtractMask ## Inverse mask
    bmIntersectMask
    bmExcludeMask

  Mixer* = proc(a, b: ColorRGBA): ColorRGBA

proc `+`*(a, b: Color): Color {.inline.} =
  result.r = a.r + b.r
  result.g = a.g + b.g
  result.b = a.b + b.b
  result.a = a.a + b.a

proc `+`*(c: Color, v: float32): Color {.inline.} =
  result.r = c.r + v
  result.g = c.g + v
  result.b = c.b + v
  result.a = c.a + v

proc `+`*(v: float32, c: Color): Color {.inline.} =
  c + v

proc `*`*(c: Color, v: float32): Color {.inline.} =
  result.r = c.r * v
  result.g = c.g * v
  result.b = c.b * v
  result.a = c.a * v

proc `*`*(v: float32, target: Color): Color {.inline.} =
  target * v

proc `/`*(c: Color, v: float32): Color {.inline.} =
  result.r = c.r / v
  result.g = c.g / v
  result.b = c.b / v
  result.a = c.a / v

proc `-`*(c: Color, v: float32): Color {.inline.} =
  result.r = c.r - v
  result.g = c.g - v
  result.b = c.b - v
  result.a = c.a - v

proc screen(backdrop, source: float32): float32 {.inline.} =
  1 - (1 - backdrop) * (1 - source)

proc hardLight(backdrop, source: float32): float32 {.inline.} =
  if source <= 0.5:
    backdrop * 2 * source
  else:
    screen(backdrop, 2 * source - 1)

proc softLight(backdrop, source: float32): float32 {.inline.} =
  ## Pegtop
  (1 - 2 * source) * backdrop ^ 2 + 2 * source * backdrop

proc Lum(C: Color): float32 {.inline.} =
  0.3 * C.r + 0.59 * C.g + 0.11 * C.b

proc ClipColor(C: var Color) {.inline.} =
  let
    L = Lum(C)
    n = min([C.r, C.g, C.b])
    x = max([C.r, C.g, C.b])
  if n < 0:
      C = L + (((C - L) * L) / (L - n))
  if x > 1:
      C = L + (((C - L) * (1 - L)) / (x - L))

proc SetLum(C: Color, l: float32): Color {.inline.} =
  let d = l - Lum(C)
  result.r = C.r + d
  result.g = C.g + d
  result.b = C.b + d
  ClipColor(result)

proc Sat(C: Color): float32 {.inline.} =
  max([C.r, C.g, C.b]) - min([C.r, C.g, C.b])

proc SetSat(C: Color, s: float32): Color {.inline.} =
  let satC = Sat(C)
  if satC > 0:
    result = (C - min([C.r, C.g, C.b])) * s / satC

proc alphaFix(backdrop, source, mixed: Color): Color =
  let
    t0 = source.a * (1 - backdrop.a)
    t1 = source.a * backdrop.a
    t2 = (1 - source.a) * backdrop.a

  result.r = t0 * source.r + t1 * mixed.r + t2 * backdrop.r
  result.g = t0 * source.g + t1 * mixed.g + t2 * backdrop.g
  result.b = t0 * source.b + t1 * mixed.b + t2 * backdrop.b

  result.a = (source.a + backdrop.a * (1.0 - source.a))
  result.r /= result.a
  result.g /= result.a
  result.b /= result.a

proc blendNormalFloats(backdrop, source: Color): Color {.inline.} =
  result = source
  result = alphaFix(backdrop, source, result)

proc blendDarkenFloats(backdrop, source: Color): Color {.inline.} =
  result.r = min(backdrop.r, source.r)
  result.g = min(backdrop.g, source.g)
  result.b = min(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendMultiplyFloats(backdrop, source: Color): Color {.inline.} =
  result.r = backdrop.r * source.r
  result.g = backdrop.g * source.g
  result.b = backdrop.b * source.b
  result = alphaFix(backdrop, source, result)

proc blendLinearBurnFloats(backdrop, source: Color): Color {.inline.} =
  result.r = backdrop.r + source.r - 1
  result.g = backdrop.g + source.g - 1
  result.b = backdrop.b + source.b - 1
  result = alphaFix(backdrop, source, result)

proc blendColorBurnFloats(backdrop, source: Color): Color {.inline.} =
  proc blend(backdrop, source: float32): float32 {.inline.} =
    if backdrop == 1:
      1.0
    elif source == 0:
      0.0
    else:
      1.0 - min(1, (1 - backdrop) / source)
  result.r = blend(backdrop.r, source.r)
  result.g = blend(backdrop.g, source.g)
  result.b = blend(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendLightenFloats(backdrop, source: Color): Color {.inline.} =
  result.r = max(backdrop.r, source.r)
  result.g = max(backdrop.g, source.g)
  result.b = max(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendScreenFloats(backdrop, source: Color): Color {.inline.} =
  result.r = screen(backdrop.r, source.r)
  result.g = screen(backdrop.g, source.g)
  result.b = screen(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendLinearDodgeFloats(backdrop, source: Color): Color {.inline.} =
  result.r = backdrop.r + source.r
  result.g = backdrop.g + source.g
  result.b = backdrop.b + source.b
  result = alphaFix(backdrop, source, result)

proc blendColorDodgeFloats(backdrop, source: Color): Color {.inline.} =
  proc blend(backdrop, source: float32): float32 {.inline.} =
    if backdrop == 0:
      0.0
    elif source == 1:
      1.0
    else:
      min(1, backdrop / (1 - source))
  result.r = blend(backdrop.r, source.r)
  result.g = blend(backdrop.g, source.g)
  result.b = blend(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendOverlayFloats(backdrop, source: Color): Color {.inline.} =
  result.r = hardLight(source.r, backdrop.r)
  result.g = hardLight(source.g, backdrop.g)
  result.b = hardLight(source.b, backdrop.b)
  result = alphaFix(backdrop, source, result)

proc blendHardLightFloats(backdrop, source: Color): Color {.inline.} =
  result.r = hardLight(backdrop.r, source.r)
  result.g = hardLight(backdrop.g, source.g)
  result.b = hardLight(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendSoftLightFloats(backdrop, source: Color): Color {.inline.} =
  result.r = softLight(backdrop.r, source.r)
  result.g = softLight(backdrop.g, source.g)
  result.b = softLight(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendDifferenceFloats(backdrop, source: Color): Color {.inline.} =
  result.r = abs(backdrop.r - source.r)
  result.g = abs(backdrop.g - source.g)
  result.b = abs(backdrop.b - source.b)
  result = alphaFix(backdrop, source, result)

proc blendExclusionFloats(backdrop, source: Color): Color {.inline.} =
  proc blend(backdrop, source: float32): float32 {.inline.} =
    backdrop + source - 2 * backdrop * source
  result.r = blend(backdrop.r, source.r)
  result.g = blend(backdrop.g, source.g)
  result.b = blend(backdrop.b, source.b)
  result = alphaFix(backdrop, source, result)

proc blendColorFloats(backdrop, source: Color): Color {.inline.} =
  result = SetLum(source, Lum(backdrop))
  result = alphaFix(backdrop, source, result)

proc blendLuminosityFloats(backdrop, source: Color): Color {.inline.} =
  result = SetLum(backdrop, Lum(source))
  result = alphaFix(backdrop, source, result)

proc blendHueFloats(backdrop, source: Color): Color {.inline.} =
  result = SetLum(SetSat(source, Sat(backdrop)), Lum(backdrop))
  result = alphaFix(backdrop, source, result)

proc blendSaturationFloats(backdrop, source: Color): Color {.inline.} =
  result = SetLum(SetSat(backdrop, Sat(source)), Lum(backdrop))
  result = alphaFix(backdrop, source, result)

proc blendMaskFloats(backdrop, source: Color): Color {.inline.} =
  result = backdrop
  result.a = min(backdrop.a, source.a)

proc blendSubtractMaskFloats(backdrop, source: Color): Color {.inline.} =
  result = backdrop
  result.a = backdrop.a * (1 - source.a)

proc blendIntersectMaskFloats(backdrop, source: Color): Color {.inline.} =
  result = backdrop
  result.a = backdrop.a * source.a

proc blendExcludeMaskFloats(backdrop, source: Color): Color {.inline.} =
  result = backdrop
  result.a = abs(backdrop.a - source.a)

proc blendOverwriteFloats(backdrop, source: Color): Color {.inline.} =
  source

proc alphaFix(backdrop, source, mixed: ColorRGBA): ColorRGBA {.inline.} =
  let
    sa = source.a.float32
    ba = backdrop.a.float32
    a = sa + ba * (255 - sa) / 255
  if a < 1:
    return

  let
    vb = mm_setr_ps(backdrop.r.float32, backdrop.g.float32, backdrop.b.float32, 0)
    vs = mm_setr_ps(source.r.float32, source.g.float32, source.b.float32, 0)
    vm = mm_setr_ps(mixed.r.float32, mixed.g.float32, mixed.b.float32, 0)
    vt0 = mm_set1_ps(sa * (255 - ba))
    vt1 = mm_set1_ps(sa * ba)
    vt2 = mm_set1_ps((255 - sa) * ba)
    va = mm_set1_ps(a)
    v255 = mm_set1_ps(255)
    values = cast[array[4, int32]](
      mm_cvtps_epi32((vt0 * vs + vt1 * vm + vt2 * vb) / va / v255)
    )

  result.r = values[0].uint8
  result.g = values[1].uint8
  result.b = values[2].uint8
  result.a = a.uint8

proc blendNormal(backdrop, source: ColorRGBA): ColorRGBA =
  result = source
  result = alphaFix(backdrop, source, result)

proc blendDarken(backdrop, source: ColorRGBA): ColorRGBA =
  blendDarkenFloats(backdrop.color, source.color).rgba

proc blendMultiply(backdrop, source: ColorRGBA): ColorRGBA =
  blendMultiplyFloats(backdrop.color, source.color).rgba

proc blendLinearBurn(backdrop, source: ColorRGBA): ColorRGBA =
  blendLinearBurnFloats(backdrop.color, source.color).rgba

proc blendColorBurn(backdrop, source: ColorRGBA): ColorRGBA =
  blendColorBurnFloats(backdrop.color, source.color).rgba

proc blendLighten(backdrop, source: ColorRGBA): ColorRGBA =
  blendLightenFloats(backdrop.color, source.color).rgba

proc blendScreen(backdrop, source: ColorRGBA): ColorRGBA =
  blendScreenFloats(backdrop.color, source.color).rgba

proc blendLinearDodge(backdrop, source: ColorRGBA): ColorRGBA =
  blendLinearDodgeFloats(backdrop.color, source.color).rgba

proc blendColorDodge(backdrop, source: ColorRGBA): ColorRGBA =
  blendColorDodgeFloats(backdrop.color, source.color).rgba

proc blendOverlay(backdrop, source: ColorRGBA): ColorRGBA =
  blendOverlayFloats(backdrop.color, source.color).rgba

proc blendHardLight(backdrop, source: ColorRGBA): ColorRGBA =
  blendHardLightFloats(backdrop.color, source.color).rgba

proc blendSoftLight(backdrop, source: ColorRGBA): ColorRGBA =
  blendSoftLightFloats(backdrop.color, source.color).rgba

proc blendDifference(backdrop, source: ColorRGBA): ColorRGBA =
  blendDifferenceFloats(backdrop.color, source.color).rgba

proc blendExclusion(backdrop, source: ColorRGBA): ColorRGBA =
  blendExclusionFloats(backdrop.color, source.color).rgba

proc blendColor(backdrop, source: ColorRGBA): ColorRGBA =
  blendColorFloats(backdrop.color, source.color).rgba

proc blendLuminosity(backdrop, source: ColorRGBA): ColorRGBA =
  blendLuminosityFloats(backdrop.color, source.color).rgba

proc blendHue(backdrop, source: ColorRGBA): ColorRGBA =
  blendHueFloats(backdrop.color, source.color).rgba

proc blendSaturation(backdrop, source: ColorRGBA): ColorRGBA =
  blendSaturationFloats(backdrop.color, source.color).rgba

proc blendMask(backdrop, source: ColorRGBA): ColorRGBA =
  result = backdrop
  result.a = min(backdrop.a, source.a)

proc blendSubtractMask(backdrop, source: ColorRGBA): ColorRGBA =
  result = backdrop
  result.a = max(0, (backdrop.a.int32 * (255 - source.a.int32)) div 255).uint8

proc blendIntersectMask(backdrop, source: ColorRGBA): ColorRGBA =
  result = backdrop
  result.a = ((backdrop.a.uint32 * (source.a.uint32)) div 255).uint8

proc blendExcludeMask(backdrop, source: ColorRGBA): ColorRGBA =
  result = backdrop
  result.a = max(backdrop.a, source.a) - min(backdrop.a, source.a)

proc blendOverwrite(backdrop, source: ColorRGBA): ColorRGBA =
  source

proc mixer*(blendMode: BlendMode): Mixer =
  case blendMode
  of bmNormal: blendNormal
  of bmDarken: blendDarken
  of bmMultiply: blendMultiply
  of bmLinearBurn: blendLinearBurn
  of bmColorBurn: blendColorBurn
  of bmLighten: blendLighten
  of bmScreen: blendScreen
  of bmLinearDodge: blendLinearDodge
  of bmColorDodge: blendColorDodge
  of bmOverlay: blendOverlay
  of bmSoftLight: blendSoftLight
  of bmHardLight: blendHardLight
  of bmDifference: blendDifference
  of bmExclusion: blendExclusion
  of bmHue: blendHue
  of bmSaturation: blendSaturation
  of bmColor: blendColor
  of bmLuminosity: blendLuminosity
  of bmMask: blendMask
  of bmOverwrite: blendOverwrite
  of bmSubtractMask: blendSubtractMask
  of bmIntersectMask: blendIntersectMask
  of bmExcludeMask: blendExcludeMask
