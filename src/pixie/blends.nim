## Blending modes.
import chroma, math

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

proc softLight(a, b: float32): float32 {.inline.} =
  ## Pegtop
  (1 - 2 * b) * a ^ 2 + 2 * b * a

proc Lum(C: Color): float32 {.inline.} =
  0.3 * C.r + 0.59 * C.g + 0.11 * C.b

proc ClipColor(C: Color): Color {.inline.} =
  let
    L = Lum(C)
    n = min([C.r, C.g, C.b])
    x = max([C.r, C.g, C.b])
  var
    C = C
  if n < 0:
      C = L + (((C - L) * L) / (L - n))
  if x > 1:
      C = L + (((C - L) * (1 - L)) / (x - L))
  return C

proc SetLum(C: Color, l: float32): Color {.inline.} =
  let
    d = l - Lum(C)
  result.r = C.r + d
  result.g = C.g + d
  result.b = C.b + d
  return ClipColor(result)

proc Sat(C: Color): float32 {.inline.} =
  max([C.r, C.g, C.b]) - min([C.r, C.g, C.b])

proc SetSat(C: Color, s: float32): Color {.inline.} =
  let satC = Sat(C)
  if satC > 0:
    result = (C - min([C.r, C.g, C.b])) * s / satC

proc alphaFix(Cb, Cs, mixed: Color): Color {.inline.} =
  let ab = Cb.a
  let As = Cs.a
  result.r = As * (1 - ab) * Cs.r + As * ab * mixed.r + (1 - As) * ab * Cb.r
  result.g = As * (1 - ab) * Cs.g + As * ab * mixed.g + (1 - As) * ab * Cb.g
  result.b = As * (1 - ab) * Cs.b + As * ab * mixed.b + (1 - As) * ab * Cb.b

  result.a = (Cs.a + Cb.a * (1.0 - Cs.a))
  result.r /= result.a
  result.g /= result.a
  result.b /= result.a

proc blendColorBurnFloat(Cb, Cs: float32): float32 {.inline.} =
  if Cb == 1:    1.0
  elif Cs == 0:  0.0
  else:          1.0 - min(1, (1 - Cb) / Cs)


proc blendColorDodgeFloat(Cb, Cs: float32): float32 {.inline.} =
  if Cb == 0:    0.0
  elif Cs == 1:  1.0
  else:          min(1, Cb / (1 - Cs))

proc blendSoftLightFloat(Cb, Cs: float32): float32 {.inline.} =
  softLight(Cb, Cs)

proc blendColorBurnFloats(Cb, Cs: Color): Color {.inline.} =
  result.r = blendColorBurnFloat(Cb.r, Cs.r)
  result.g = blendColorBurnFloat(Cb.g, Cs.g)
  result.b = blendColorBurnFloat(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendColorDodgeFloats(Cb, Cs: Color): Color {.inline.} =
  result.r = blendColorDodgeFloat(Cb.r, Cs.r)
  result.g = blendColorDodgeFloat(Cb.g, Cs.g)
  result.b = blendColorDodgeFloat(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendSoftLightFloats(Cb, Cs: Color): Color {.inline.} =
  result.r = blendSoftLightFloat(Cb.r, Cs.r)
  result.g = blendSoftLightFloat(Cb.g, Cs.g)
  result.b = blendSoftLightFloat(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendColorFloats(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(Cs, Lum(Cb))
  alphaFix(Cb, Cs, mixed)

proc blendLuminosityFloats(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(Cb, Lum(Cs))
  alphaFix(Cb, Cs, mixed)

proc blendHueFloats(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(SetSat(Cs, Sat(Cb)), Lum(Cb))
  alphaFix(Cb, Cs, mixed)

proc blendSaturationFloats(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(SetSat(Cb, Sat(Cs)), Lum(Cb))
  alphaFix(Cb, Cs, mixed)

proc alphaFix(Cb, Cs, mixed: ColorRGBA): ColorRGBA {.inline.} =
  let ab = Cb.a.int32
  let As = Cs.a.int32
  let r = As * (255 - ab) * Cs.r.int32 + As * ab * mixed.r.int32 + (255 - As) * ab * Cb.r.int32
  let g = As * (255 - ab) * Cs.g.int32 + As * ab * mixed.g.int32 + (255 - As) * ab * Cb.g.int32
  let b = As * (255 - ab) * Cs.b.int32 + As * ab * mixed.b.int32 + (255 - As) * ab * Cb.b.int32

  let a = Cs.a.int32 + Cb.a.int32 * (255 - Cs.a.int32) div 255
  if a == 0:
    return
  else:
    result.r = (r div a div 255).uint8
    result.g = (g div a div 255).uint8
    result.b = (b div a div 255).uint8
    result.a = a.uint8

proc screen(a, b: uint8): uint8 {.inline.} =
  (255 - ((255 - a).uint32 * (255 - b).uint32) div 255).uint8

proc hardLight(a, b: uint8): uint8 {.inline.} =
  if b <= 127:
    ((a * 2 * b) div 255).uint8
  else:
    screen(a, max(0, (2 * b.int32 - 255)).uint8)

proc blendNormal(a, b: ColorRGBA): ColorRGBA =
  result.r = b.r
  result.g = b.g
  result.b = b.b
  result = alphaFix(a, b, result)

proc blendDarken(a, b: ColorRGBA): ColorRGBA =
  result.r = min(a.r, b.r)
  result.g = min(a.g, b.g)
  result.b = min(a.b, b.b)
  result = alphaFix(a, b, result)

proc blendMultiply(a, b: ColorRGBA): ColorRGBA =
  result.r = ((a.r.uint32 * b.r.uint32) div 255).uint8
  result.g = ((a.g.uint32 * b.g.uint32) div 255).uint8
  result.b = ((a.b.uint32 * b.b.uint32) div 255).uint8
  result = alphaFix(a, b, result)

proc blendLinearBurn(a, b: ColorRGBA): ColorRGBA =
  result.r = max(0, a.r.int32 + b.r.int32 - 255).uint8
  result.g = max(0, a.g.int32 + b.g.int32 - 255).uint8
  result.b = max(0, a.b.int32 + b.b.int32 - 255).uint8
  result = alphaFix(a, b, result)

proc blendColorBurn(a, b: ColorRGBA): ColorRGBA =
  blendColorBurnFloats(a.color, b.color).rgba

proc blendLighten(a, b: ColorRGBA): ColorRGBA =
  result.r = max(a.r, b.r)
  result.g = max(a.g, b.g)
  result.b = max(a.b, b.b)
  result = alphaFix(a, b, result)

proc blendScreen(a, b: ColorRGBA): ColorRGBA =
  result.r = screen(a.r, b.r)
  result.g = screen(a.g, b.g)
  result.b = screen(a.b, b.b)
  result = alphaFix(a, b, result)

proc blendLinearDodge(a, b: ColorRGBA): ColorRGBA =
  result.r = (a.r.uint32 + b.r).uint8
  result.r = (a.g.uint32 + b.g).uint8
  result.r = (a.b.uint32 + b.b).uint8
  result = alphaFix(a, b, result)

proc blendColorDodge(a, b: ColorRGBA): ColorRGBA =
  blendColorDodgeFloats(a.color, b.color).rgba

proc blendOverlay(a, b: ColorRGBA): ColorRGBA =
  result.r = hardLight(b.r, a.r)
  result.g = hardLight(b.g, a.g)
  result.b = hardLight(b.b, a.b)
  result = alphaFix(a, b, result)

proc blendHardLight(a, b: ColorRGBA): ColorRGBA =
  result.r = hardLight(a.r, b.r)
  result.g = hardLight(a.g, b.g)
  result.b = hardLight(a.b, b.b)
  result = alphaFix(a, b, result)

proc blendSoftLight(a, b: ColorRGBA): ColorRGBA =
  blendSoftLightFloats(a.color, b.color).rgba

proc blendDifference(a, b: ColorRGBA): ColorRGBA =
  result.r = max(a.r, b.r) - min(a.r, b.r)
  result.g = max(a.g, b.g) - min(a.g, b.g)
  result.b = max(a.b, b.b) - min(a.b, b.b)
  result = alphaFix(a, b, result)

proc blendExclusion(a, b: ColorRGBA): ColorRGBA =
  template blend(a, b: int32): uint8 =
    max(0, a + b - (2 * a * b) div 255).uint8
  result.r = blend(a.r.int32, b.r.int32)
  result.g = blend(a.g.int32, b.g.int32)
  result.b = blend(a.b.int32, b.b.int32)
  result = alphaFix(a, b, result)

proc blendColor(a, b: ColorRGBA): ColorRGBA =
  blendColorFloats(a.color, b.color).rgba

proc blendLuminosity(a, b: ColorRGBA): ColorRGBA =
  blendLuminosityFloats(a.color, b.color).rgba

proc blendHue(a, b: ColorRGBA): ColorRGBA =
  blendHueFloats(a.color, b.color).rgba

proc blendSaturation(a, b: ColorRGBA): ColorRGBA =
  blendSaturationFloats(a.color, b.color).rgba

proc blendMask(a, b: ColorRGBA): ColorRGBA =
  result = a
  result.a = min(a.a, b.a)

proc blendSubtractMask(a, b: ColorRGBA): ColorRGBA =
  result = a
  result.a = max(0, (a.a.int32 * (255 - b.a.int32)) div 255).uint8

proc blendIntersectMask(a, b: ColorRGBA): ColorRGBA =
  result = a
  result.a = ((a.a.uint32 * (b.a.uint32)) div 255).uint8

proc blendExcludeMask(a, b: ColorRGBA): ColorRGBA =
  result = a
  result.a = max(a.a, b.a) - min(a.a, b.a)

proc blendOverwrite(a, b: ColorRGBA): ColorRGBA =
  b

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
