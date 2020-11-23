## Blending modes.
import chroma, math, algorithm

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

proc mix*(blendMode: BlendMode, target, blend: Color): Color =

  if blendMode == bmMask:
    result.r = target.r
    result.g = target.g
    result.b = target.b
    result.a = min(target.a, blend.a)
    return
  elif blendMode == bmSubtractMask:
    result.r = target.r
    result.g = target.g
    result.b = target.b
    result.a = target.a * (1 - blend.a)
    return
  elif blendMode == bmIntersectMask:
    result.r = target.r
    result.g = target.g
    result.b = target.b
    result.a = target.a * blend.a
    return
  elif blendMode == bmExcludeMask:
    result.r = target.r
    result.g = target.g
    result.b = target.b
    result.a = abs(target.a - blend.a)
    return
  elif blendMode == bmOverwrite:
    result = blend
    return

  proc multiply(Cb, Cs: float32): float32 =
    Cb * Cs

  proc screen(Cb, Cs: float32): float32 =
    1 - (1 - Cb) * (1 - Cs)

  proc hardLight(Cb, Cs: float32): float32 =
    if Cs <= 0.5: multiply(Cb, 2 * Cs)
    else: screen(Cb, 2 * Cs - 1)

  # Here are 4 implementations of soft light, none of them are quite right.

  # proc softLight(Cb, Cs: float32): float32 =
  #   ## W3C
  #   proc D(cb: float32): float32 =
  #     if Cb <= 0.25:
  #       ((16 * Cb - 12) * Cb + 4) * Cb
  #     else:
  #       sqrt(Cb)
  #   if Cs <= 0.5:
  #     return Cb - (1 - 2 * Cs) * Cb * (1 - Cb)
  #   else:
  #     return Cb + (2 * Cs - 1) * (D(Cb) - Cb)

  # proc softLight(a, b: float32): float32 =
  #   ## Photoshop
  #   if b < 0.5:
  #     2 * a * b + a ^ 2 * (1 - 2 * b)
  #   else:
  #     2 * a * (1 - b) + sqrt(a) * (2 * b - 1)

  proc softLight(a, b: float32): float32 =
    ## Pegtop
    (1 - 2 * b) * a ^ 2 + 2 * b * a

  # proc softLight(a, b: float32): float32 =
  #   ## Illusions.hu
  #   pow(a, pow(2, (2 * (0.5 - b))))

  proc Lum(C: Color): float32 =
    0.3 * C.r + 0.59 * C.g + 0.11 * C.b

  proc ClipColor(C: Color): Color =
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

  proc SetLum(C: Color, l: float32): Color =
    let
      d = l - Lum(C)
    result.r = C.r + d
    result.g = C.g + d
    result.b = C.b + d
    return ClipColor(result)

  proc Sat(C: Color): float32 =
    max([C.r, C.g, C.b]) - min([C.r, C.g, C.b])

  proc SetSat(C: Color, s: float32): Color =
    var arr = [(C.r, 0), (C.g, 1), (C.b, 2)]
    # TODO: Don't rely on sort.
    arr.sort()
    var
      Cmin = arr[0][0]
      Cmid = arr[1][0]
      Cmax = arr[2][0]
    if Cmax > Cmin:
      Cmid = (((Cmid - Cmin) * s) / (Cmax - Cmin))
      Cmax = s
    else:
      Cmid = 0
      Cmax = 0
    Cmin = 0

    if arr[0][1] == 0:
      result.r = Cmin
    if arr[1][1] == 0:
      result.r = Cmid
    if arr[2][1] == 0:
      result.r = Cmax

    if arr[0][1] == 1:
      result.g = Cmin
    if arr[1][1] == 1:
      result.g = Cmid
    if arr[2][1] == 1:
      result.g = Cmax

    if arr[0][1] == 2:
      result.b = Cmin
    if arr[1][1] == 2:
      result.b = Cmid
    if arr[2][1] == 2:
      result.b = Cmax

  proc blendChannel(blendMode: BlendMode, Cb, Cs: float32): float32 =
    result = case blendMode
    of bmNormal:       Cs
    of bmDarken:       min(Cb, Cs)
    of bmMultiply:     multiply(Cb, Cs)
    of bmLinearBurn:   Cb + Cs - 1
    of bmColorBurn:
      if Cb == 1:    1.0
      elif Cs == 0:  0.0
      else:          1.0 - min(1, (1 - Cb) / Cs)
    of bmLighten:      max(Cb, Cs)
    of bmScreen:       screen(Cb, Cs)
    of bmLinearDodge:  Cb + Cs
    of bmColorDodge:
      if Cb == 0:    0.0
      elif Cs == 1:  1.0
      else:          min(1, Cb / (1 - Cs))
    of bmOverlay:      hardLight(Cs, Cb)
    of bmHardLight:    hardLight(Cb, Cs)
    of bmSoftLight:    softLight(Cb, Cs)
    of bmDifference:   abs(Cb - Cs)
    of bmExclusion:    Cb + Cs - 2 * Cb * Cs
    else: 0.0
  let Cb = target
  let Cs = blend

  var mixed: Color
  if blendMode == bmColor:
    mixed = SetLum(Cs, Lum(Cb))
  elif blendMode == bmLuminosity:
    mixed = SetLum(Cb, Lum(Cs))
  elif blendMode == bmHue:
    mixed = SetLum(SetSat(Cs, Sat(Cb)), Lum(Cb))
  elif blendMode == bmSaturation:
    mixed = SetLum(SetSat(Cb, Sat(Cs)), Lum(Cb))
  else:
    mixed.r = blendMode.blendChannel(Cb.r, Cs.r)
    mixed.g = blendMode.blendChannel(Cb.g, Cs.g)
    mixed.b = blendMode.blendChannel(Cb.b, Cs.b)

  let ab = Cb.a
  let As = Cs.a
  result.r = As * (1 - ab) * Cs.r + As * ab * mixed.r + (1 - As) * ab * Cb.r
  result.g = As * (1 - ab) * Cs.g + As * ab * mixed.g + (1 - As) * ab * Cb.g
  result.b = As * (1 - ab) * Cs.b + As * ab * mixed.b + (1 - As) * ab * Cb.b

  result.a = (blend.a + target.a * (1.0 - blend.a))
  result.r /= result.a
  result.g /= result.a
  result.b /= result.a

proc mix*(blendMode: BlendMode, dest, src: ColorRGBA): ColorRGBA {.inline.} =
  return blendMode.mix(dest.color, src.color).rgba

  # TODO: Fix fast paths
  # if blendMode == Normal:
  #   # Fast pass
  #   # target * (1 - blend.a) + blend * blend.a
  #   if target.a == 0: return blend
  #   let blendAComp = 255 - blend.a
  #   result.r = ((target.r.uint16 * blendAComp + blend.r.uint16 * blend.a) div 255).uint8
  #   result.g = ((target.g.uint16 * blendAComp + blend.g.uint16 * blend.a) div 255).uint8
  #   result.b = ((target.b.uint16 * blendAComp + blend.b.uint16 * blend.a) div 255).uint8
  #   result.a = (blend.a.uint16 + (target.a.uint16 * blendAComp) div 255).uint8
  #   inc blendCount
  # elif blendMode == Mask:
  #   result.r = target.r
  #   result.g = target.g
  #   result.b = target.b
  #   result.a = min(target.a, blend.a)
  # elif blendMode == COPY:
  #   result = target
  # else:
  #   return blendMode.mix(target.color, blend.color).rgba
