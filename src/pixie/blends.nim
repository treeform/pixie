## Blending modes.
import chroma, math

# See https://www.w3.org/TR/compositing-1/
# See https://www.khronos.org/registry/OpenGL/extensions/KHR/KHR_blend_equation_advanced.txt

type BlendMode* = enum
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

proc screen(Cb, Cs: float32): float32 {.inline.} =
  1 - (1 - Cb) * (1 - Cs)

proc hardLight(Cb, Cs: float32): float32 {.inline.} =
  if Cs <= 0.5:
    Cb * 2 * Cs
  else:
    screen(Cb, 2 * Cs - 1)

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

proc blendDarken(Cb, Cs: float32): float32 {.inline.} =
  min(Cb, Cs)

proc blendMultiply(Cb, Cs: float32): float32 {.inline.} =
  Cb * Cs

proc blendLinearBurn(Cb, Cs: float32): float32 {.inline.} =
  Cb + Cs - 1

proc blendColorBurn(Cb, Cs: float32): float32 {.inline.} =
  if Cb == 1:    1.0
  elif Cs == 0:  0.0
  else:          1.0 - min(1, (1 - Cb) / Cs)

proc blendLighten(Cb, Cs: float32): float32 {.inline.} =
  max(Cb, Cs)

proc blendScreen(Cb, Cs: float32): float32 {.inline.} =
  screen(Cb, Cs)

proc blendLinearDodge(Cb, Cs: float32): float32 {.inline.} =
  Cb + Cs

proc blendColorDodge(Cb, Cs: float32): float32 {.inline.} =
  if Cb == 0:    0.0
  elif Cs == 1:  1.0
  else:          min(1, Cb / (1 - Cs))

proc blendOverlay(Cb, Cs: float32): float32 {.inline.} =
  hardLight(Cs, Cb)

proc blendHardLight(Cb, Cs: float32): float32 {.inline.} =
  hardLight(Cb, Cs)

proc blendSoftLight(Cb, Cs: float32): float32 {.inline.} =
  softLight(Cb, Cs)

proc blendDifference(Cb, Cs: float32): float32 {.inline.} =
  abs(Cb - Cs)

proc blendExclusion(Cb, Cs: float32): float32 {.inline.} =
  Cb + Cs - 2 * Cb * Cs

proc blendNormal(Cb, Cs: Color): Color {.inline.} =
  result.r = Cs.r
  result.g = Cs.g
  result.b = Cs.b
  result = alphaFix(Cb, Cs, result)

proc blendDarken(Cb, Cs: Color): Color {.inline.} =
  result.r = blendDarken(Cb.r, Cs.r)
  result.g = blendDarken(Cb.g, Cs.g)
  result.b = blendDarken(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendMultiply(Cb, Cs: Color): Color {.inline.} =
  result.r = blendMultiply(Cb.r, Cs.r)
  result.g = blendMultiply(Cb.g, Cs.g)
  result.b = blendMultiply(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendLinearBurn(Cb, Cs: Color): Color {.inline.} =
  result.r = blendLinearBurn(Cb.r, Cs.r)
  result.g = blendLinearBurn(Cb.g, Cs.g)
  result.b = blendLinearBurn(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendColorBurn(Cb, Cs: Color): Color {.inline.} =
  result.r = blendColorBurn(Cb.r, Cs.r)
  result.g = blendColorBurn(Cb.g, Cs.g)
  result.b = blendColorBurn(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendLighten(Cb, Cs: Color): Color {.inline.} =
  result.r = blendLighten(Cb.r, Cs.r)
  result.g = blendLighten(Cb.g, Cs.g)
  result.b = blendLighten(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendScreen(Cb, Cs: Color): Color {.inline.} =
  result.r = blendScreen(Cb.r, Cs.r)
  result.g = blendScreen(Cb.g, Cs.g)
  result.b = blendScreen(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendLinearDodge(Cb, Cs: Color): Color {.inline.} =
  result.r = blendLinearDodge(Cb.r, Cs.r)
  result.g = blendLinearDodge(Cb.g, Cs.g)
  result.b = blendLinearDodge(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendColorDodge(Cb, Cs: Color): Color {.inline.} =
  result.r = blendColorDodge(Cb.r, Cs.r)
  result.g = blendColorDodge(Cb.g, Cs.g)
  result.b = blendColorDodge(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendOverlay(Cb, Cs: Color): Color {.inline.} =
  result.r = blendOverlay(Cb.r, Cs.r)
  result.g = blendOverlay(Cb.g, Cs.g)
  result.b = blendOverlay(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendHardLight(Cb, Cs: Color): Color {.inline.} =
  result.r = blendHardLight(Cb.r, Cs.r)
  result.g = blendHardLight(Cb.g, Cs.g)
  result.b = blendHardLight(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendSoftLight(Cb, Cs: Color): Color {.inline.} =
  result.r = blendSoftLight(Cb.r, Cs.r)
  result.g = blendSoftLight(Cb.g, Cs.g)
  result.b = blendSoftLight(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendDifference(Cb, Cs: Color): Color {.inline.} =
  result.r = blendDifference(Cb.r, Cs.r)
  result.g = blendDifference(Cb.g, Cs.g)
  result.b = blendDifference(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendExclusion(Cb, Cs: Color): Color {.inline.} =
  result.r = blendExclusion(Cb.r, Cs.r)
  result.g = blendExclusion(Cb.g, Cs.g)
  result.b = blendExclusion(Cb.b, Cs.b)
  result = alphaFix(Cb, Cs, result)

proc blendColor(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(Cs, Lum(Cb))
  alphaFix(Cb, Cs, mixed)

proc blendLuminosity(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(Cb, Lum(Cs))
  alphaFix(Cb, Cs, mixed)

proc blendHue(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(SetSat(Cs, Sat(Cb)), Lum(Cb))
  alphaFix(Cb, Cs, mixed)

proc blendSaturation(Cb, Cs: Color): Color {.inline.} =
  let mixed = SetLum(SetSat(Cb, Sat(Cs)), Lum(Cb))
  alphaFix(Cb, Cs, mixed)

proc blendMask(target, blend: Color): Color {.inline.} =
  result.r = target.r
  result.g = target.g
  result.b = target.b
  result.a = min(target.a, blend.a)

proc blendSubtractMask(target, blend: Color): Color {.inline.} =
  result.r = target.r
  result.g = target.g
  result.b = target.b
  result.a = target.a * (1 - blend.a)

proc blendIntersectMask(target, blend: Color): Color {.inline.} =
  result.r = target.r
  result.g = target.g
  result.b = target.b
  result.a = target.a * blend.a

proc blendExcludeMask(target, blend: Color): Color {.inline.} =
  result.r = target.r
  result.g = target.g
  result.b = target.b
  result.a = abs(target.a - blend.a)

proc blendOverwrite(target, blend: Color): Color {.inline.} =
  result = blend

# proc mix*(blendMode: BlendMode, dest, src: Color): Color {.inline.} =
#   case blendMode
#   of bmNormal: blendNormal(dest, src)
#   of bmDarken: blendDarken(dest, src)
#   of bmMultiply: blendMultiply(dest, src)
#   of bmLinearBurn: blendLinearBurn(dest, src)
#   of bmColorBurn: blendColorBurn(dest, src)
#   of bmLighten: blendLighten(dest, src)
#   of bmScreen: blendScreen(dest, src)
#   of bmLinearDodge: blendLinearDodge(dest, src)
#   of bmColorDodge: blendColorDodge(dest, src)
#   of bmOverlay: blendOverlay(dest, src)
#   of bmSoftLight: blendSoftLight(dest, src)
#   of bmHardLight: blendHardLight(dest, src)
#   of bmDifference: blendDifference(dest, src)
#   of bmExclusion: blendExclusion(dest, src)
#   of bmHue: blendHue(dest, src)
#   of bmSaturation: blendSaturation(dest, src)
#   of bmColor: blendColor(dest, src)
#   of bmLuminosity: blendLuminosity(dest, src)
#   of bmMask: blendMask(dest, src)
#   of bmOverwrite: blendOverwrite(dest, src)
#   of bmSubtractMask: blendSubtractMask(dest, src)
#   of bmIntersectMask: blendIntersectMask(dest, src)
#   of bmExcludeMask: blendExcludeMask(dest, src)

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

proc blendNormal*(a, b: ColorRGBA): ColorRGBA =
  # blendNormal(a.color, b.color).rgba
  result.r = b.r
  result.g = b.g
  result.b = b.b
  result = alphaFix(a, b, result)

proc blendDarken(a, b: ColorRGBA): ColorRGBA =
  blendDarken(a.color, b.color).rgba

proc blendMultiply(a, b: ColorRGBA): ColorRGBA =
  blendMultiply(a.color, b.color).rgba

proc blendLinearBurn(a, b: ColorRGBA): ColorRGBA =
  blendLinearBurn(a.color, b.color).rgba

proc blendColorBurn(a, b: ColorRGBA): ColorRGBA =
  blendColorBurn(a.color, b.color).rgba

proc blendLighten(a, b: ColorRGBA): ColorRGBA =
  blendLighten(a.color, b.color).rgba

proc blendScreen(a, b: ColorRGBA): ColorRGBA =
  blendScreen(a.color, b.color).rgba

proc blendLinearDodge(a, b: ColorRGBA): ColorRGBA =
  blendLinearDodge(a.color, b.color).rgba

proc blendColorDodge(a, b: ColorRGBA): ColorRGBA =
  blendColorDodge(a.color, b.color).rgba

proc blendOverlay(a, b: ColorRGBA): ColorRGBA =
  blendOverlay(a.color, b.color).rgba

proc blendHardLight(a, b: ColorRGBA): ColorRGBA =
  blendHardLight(a.color, b.color).rgba

proc blendSoftLight(a, b: ColorRGBA): ColorRGBA =
  blendSoftLight(a.color, b.color).rgba

proc blendDifference(a, b: ColorRGBA): ColorRGBA =
  blendDifference(a.color, b.color).rgba

proc blendExclusion(a, b: ColorRGBA): ColorRGBA =
  blendExclusion(a.color, b.color).rgba

proc blendColor(a, b: ColorRGBA): ColorRGBA =
  blendColor(a.color, b.color).rgba

proc blendLuminosity(a, b: ColorRGBA): ColorRGBA =
  blendLuminosity(a.color, b.color).rgba

proc blendHue(a, b: ColorRGBA): ColorRGBA =
  blendHue(a.color, b.color).rgba

proc blendSaturation(a, b: ColorRGBA): ColorRGBA =
  blendSaturation(a.color, b.color).rgba

proc blendMask(a, b: ColorRGBA): ColorRGBA =
  result.r = a.r
  result.g = a.g
  result.b = a.b
  result.a = min(a.a, b.a)

proc blendSubtractMask(a, b: ColorRGBA): ColorRGBA =
  blendSubtractMask(a.color, b.color).rgba

proc blendIntersectMask(a, b: ColorRGBA): ColorRGBA =
  blendIntersectMask(a.color, b.color).rgba

proc blendExcludeMask(a, b: ColorRGBA): ColorRGBA =
  blendExcludeMask(a.color, b.color).rgba

proc blendOverwrite(a, b: ColorRGBA): ColorRGBA =
  blendOverwrite(a.color, b.color).rgba

proc mix*(blendMode: BlendMode, dest, src: ColorRGBA): ColorRGBA {.inline.} =
  case blendMode
  of bmNormal: blendNormal(dest, src)
  of bmDarken: blendDarken(dest, src)
  of bmMultiply: blendMultiply(dest, src)
  of bmLinearBurn: blendLinearBurn(dest, src)
  of bmColorBurn: blendColorBurn(dest, src)
  of bmLighten: blendLighten(dest, src)
  of bmScreen: blendScreen(dest, src)
  of bmLinearDodge: blendLinearDodge(dest, src)
  of bmColorDodge: blendColorDodge(dest, src)
  of bmOverlay: blendOverlay(dest, src)
  of bmSoftLight: blendSoftLight(dest, src)
  of bmHardLight: blendHardLight(dest, src)
  of bmDifference: blendDifference(dest, src)
  of bmExclusion: blendExclusion(dest, src)
  of bmHue: blendHue(dest, src)
  of bmSaturation: blendSaturation(dest, src)
  of bmColor: blendColor(dest, src)
  of bmLuminosity: blendLuminosity(dest, src)
  of bmMask: blendMask(dest, src)
  of bmOverwrite: blendOverwrite(dest, src)
  of bmSubtractMask: blendSubtractMask(dest, src)
  of bmIntersectMask: blendIntersectMask(dest, src)
  of bmExcludeMask: blendExcludeMask(dest, src)

proc mixStatic*(
  blendMode: static[BlendMode], dest, src: ColorRGBA
): ColorRGBA {.inline.} =
  when blendMOde == bmNormal: blendNormal(dest, src)
  elif blendMOde == bmDarken: blendDarken(dest, src)
  elif blendMOde == bmMultiply: blendMultiply(dest, src)
  elif blendMOde == bmLinearBurn: blendLinearBurn(dest, src)
  elif blendMOde == bmColorBurn: blendColorBurn(dest, src)
  elif blendMOde == bmLighten: blendLighten(dest, src)
  elif blendMOde == bmScreen: blendScreen(dest, src)
  elif blendMOde == bmLinearDodge: blendLinearDodge(dest, src)
  elif blendMOde == bmColorDodge: blendColorDodge(dest, src)
  elif blendMOde == bmOverlay: blendOverlay(dest, src)
  elif blendMOde == bmSoftLight: blendSoftLight(dest, src)
  elif blendMOde == bmHardLight: blendHardLight(dest, src)
  elif blendMOde == bmDifference: blendDifference(dest, src)
  elif blendMOde == bmExclusion: blendExclusion(dest, src)
  elif blendMOde == bmHue: blendHue(dest, src)
  elif blendMOde == bmSaturation: blendSaturation(dest, src)
  elif blendMOde == bmColor: blendColor(dest, src)
  elif blendMOde == bmLuminosity: blendLuminosity(dest, src)
  elif blendMOde == bmMask: blendMask(dest, src)
  elif blendMOde == bmOverwrite: blendOverwrite(dest, src)
  elif blendMOde == bmSubtractMask: blendSubtractMask(dest, src)
  elif blendMOde == bmIntersectMask: blendIntersectMask(dest, src)
  elif blendMOde == bmExcludeMask: blendExcludeMask(dest, src)
