## Blending modes.

import chroma, common, internal, std/math

when defined(amd64) and allowSimd:
  import nimsimd/sse2

# See https://www.w3.org/TR/compositing-1/
# See https://www.khronos.org/registry/OpenGL/extensions/KHR/KHR_blend_equation_advanced.txt

type
  Blender* = proc(backdrop, source: ColorRGBX): ColorRGBX {.gcsafe, raises: [].}
    ## Function signature returned by blender.
  Masker* = proc(backdrop, source: uint8): uint8 {.gcsafe, raises: [].}
    ## Function signature returned by masker.

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

proc alphaFix(backdrop, source, mixed: Color): Color =
  ## After mixing an image, adjust its alpha value to be correct.
  result.a = (source.a + backdrop.a * (1.0 - source.a))
  if result.a == 0:
    return

  let
    t0 = source.a * (1 - backdrop.a)
    t1 = source.a * backdrop.a
    t2 = (1 - source.a) * backdrop.a

  result.r = t0 * source.r + t1 * mixed.r + t2 * backdrop.r
  result.g = t0 * source.g + t1 * mixed.g + t2 * backdrop.g
  result.b = t0 * source.b + t1 * mixed.b + t2 * backdrop.b

  result.r /= result.a
  result.g /= result.a
  result.b /= result.a

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

proc softLight(backdrop, source: float32): float32 {.inline.} =
  ## Pegtop
  (1 - 2 * source) * backdrop ^ 2 + 2 * source * backdrop

proc `+`(c: Color, v: float32): Color {.inline.} =
  result.r = c.r + v
  result.g = c.g + v
  result.b = c.b + v
  result.a = c.a + v

proc `+`(v: float32, c: Color): Color {.inline.} =
  c + v

proc `*`(c: Color, v: float32): Color {.inline.} =
  result.r = c.r * v
  result.g = c.g * v
  result.b = c.b * v
  result.a = c.a * v

proc `/`(c: Color, v: float32): Color {.inline.} =
  result.r = c.r / v
  result.g = c.g / v
  result.b = c.b / v
  result.a = c.a / v

proc `-`(c: Color, v: float32): Color {.inline.} =
  result.r = c.r - v
  result.g = c.g - v
  result.b = c.b - v
  result.a = c.a - v

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

proc blendColorDodge(backdrop, source: ColorRGBX): ColorRGBX =
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
  # proc softLight(backdrop, source: int32): uint8 {.inline.} =
  #   ## Pegtop
  #   (
  #     ((255 - 2 * source) * backdrop ^ 2) div 255 ^ 2 +
  #     (2 * source * backdrop) div 255
  #   ).uint8

  let
    backdrop = backdrop.rgba()
    source = source.rgba()

  var rgba: ColorRGBA
  when defined(amd64) and allowSimd:
    let
      vb = mm_setr_ps(
        backdrop.r.float32,
        backdrop.g.float32,
        backdrop.b.float32,
        0
      )
      vs = mm_setr_ps(source.r.float32, source.g.float32, source.b.float32, 0)
      v2 = mm_set1_ps(2)
      v255 = mm_set1_ps(255)
      v255sq = mm_set1_ps(255 * 255)
      vm = ((v255 - v2 * vs) * vb * vb) / v255sq + (v2 * vs * vb) / v255
      values = cast[array[4, uint32]](mm_cvtps_epi32(vm))

    rgba.r = values[0].uint8
    rgba.g = values[1].uint8
    rgba.b = values[2].uint8

    # proc alphaFix(backdrop, source, mixed: ColorRGBX): ColorRGBX {.inline.} =
    #   if backdrop.a == 0 and source.a == 0:
    #     return
    #   let
    #     vb = mm_setr_ps(backdrop.r.float32, backdrop.g.float32, backdrop.b.float32, 0)
    #     vs = mm_setr_ps(source.r.float32, source.g.float32, source.b.float32, 0)
    #     vm = mm_setr_ps(mixed.r.float32, mixed.g.float32, mixed.b.float32, 0)
    #   alphaFix(backdrop, source, vb, vs, vm)

    let
      sa = source.a.float32
      ba = backdrop.a.float32
      a = sa + ba * (255 - sa) / 255
    if a == 0:
      return

    let
      t0 = mm_set1_ps(sa * (255 - ba))
      t1 = mm_set1_ps(sa * ba)
      t2 = mm_set1_ps((255 - sa) * ba)
      va = mm_set1_ps(a)
      final = cast[array[4, uint32]](
        mm_cvtps_epi32((t0 * vs + t1 * vm + t2 * vb) / va / v255)
      )

    rgba.r = final[0].uint8
    rgba.g = final[1].uint8
    rgba.b = final[2].uint8
    rgba.a = a.uint8
  else:
    let
      b = backdrop.color
      s = source.color
    var blended: Color
    blended.r = softLight(b.r, s.r)
    blended.g = softLight(b.g, s.g)
    blended.b = softLight(b.b, s.b)
    blended = alphaFix(b, s, blended)
    rgba = blended.rgba

  result = rgba.rgbx()

proc blendHardLight*(backdrop, source: ColorRGBX): ColorRGBX =
  result.r = hardLight(backdrop.r, backdrop.a, source.r, source.a)
  result.g = hardLight(backdrop.g, backdrop.a, source.g, source.a)
  result.b = hardLight(backdrop.b, backdrop.a, source.b, source.a)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendDifference(backdrop, source: ColorRGBX): ColorRGBX =
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

proc blendExclusion(backdrop, source: ColorRGBX): ColorRGBX =
  proc blend(backdrop, source: uint32): uint8 {.inline.} =
    let v = (backdrop + source).int32 - ((2 * backdrop * source) div 255).int32
    max(0, v).uint8
  result.r = blend(backdrop.r.uint32, source.r.uint32)
  result.g = blend(backdrop.g.uint32, source.g.uint32)
  result.b = blend(backdrop.b.uint32, source.b.uint32)
  result.a = blendAlpha(backdrop.a, source.a)

proc blendColor(backdrop, source: ColorRGBX): ColorRGBX =
  let
    backdrop = backdrop.rgba().color
    source = source.rgba().color
    blended = SetLum(source, Lum(backdrop))
  result = alphaFix(backdrop, source, blended).rgba.rgbx()

proc blendLuminosity(backdrop, source: ColorRGBX): ColorRGBX =
  let
    backdrop = backdrop.rgba().color
    source = source.rgba().color
    blended = SetLum(backdrop, Lum(source))
  result = alphaFix(backdrop, source, blended).rgba.rgbx()

proc blendHue(backdrop, source: ColorRGBX): ColorRGBX =
  let
    backdrop = backdrop.rgba().color
    source = source.rgba().color
    blended = SetLum(SetSat(source, Sat(backdrop)), Lum(backdrop))
  result = alphaFix(backdrop, source, blended).rgba.rgbx()

proc blendSaturation(backdrop, source: ColorRGBX): ColorRGBX =
  let
    backdrop = backdrop.rgba().color
    source = source.rgba().color
    blended = SetLum(SetSat(backdrop, Sat(source)), Lum(backdrop))
  result = alphaFix(backdrop, source, blended).rgba.rgbx()

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

proc maskBlendNormal*(backdrop, source: uint8): uint8 {.inline.} =
  ## Normal blend masks
  blendAlpha(backdrop, source)

proc maskBlendMask*(backdrop, source: uint8): uint8 {.inline.} =
  ## Mask blend masks
  ((backdrop.uint32 * source) div 255).uint8

proc maskBlendSubtract*(backdrop, source: uint8): uint8 {.inline.} =
  ## Subtract blend masks
  ((backdrop.uint32 * (255 - source)) div 255).uint8

proc maskBlendExclude*(backdrop, source: uint8): uint8 {.inline.} =
  ## Exclude blend masks
  max(backdrop, source) - min(backdrop, source)

proc maskBlendNormalMasker(backdrop, source: uint8): uint8 =
  maskBlendNormal(backdrop, source)

proc maskBlendMaskMasker(backdrop, source: uint8): uint8 =
  maskBlendMask(backdrop, source)

proc maskBlendSubtractMasker(backdrop, source: uint8): uint8 =
  maskBlendSubtract(backdrop, source)

proc maskBlendExcludeMasker(backdrop, source: uint8): uint8 =
  maskBlendExclude(backdrop, source)

proc maskBlendOverwriteMasker(backdrop, source: uint8): uint8 =
  source

proc masker*(blendMode: BlendMode): Masker {.raises: [PixieError].} =
  ## Returns a blend masking function for a given blend masking mode.
  case blendMode:
  of NormalBlend: maskBlendNormalMasker
  of MaskBlend: maskBlendMaskMasker
  of OverwriteBlend: maskBlendOverwriteMasker
  of SubtractMaskBlend: maskBlendSubtractMasker
  of ExcludeMaskBlend: maskBlendExcludeMasker
  else:
    raise newException(PixieError, "No masker for " & $blendMode)

when defined(amd64) and allowSimd:
  type
    BlenderSimd* = proc(blackdrop, source: M128i): M128i {.gcsafe, raises: [].}
      ## Function signature returned by blenderSimd.
    MaskerSimd* = proc(blackdrop, source: M128i): M128i {.gcsafe, raises: [].}
      ## Function signature returned by maskerSimd.

  proc blendNormalSimd*(backdrop, source: M128i): M128i {.inline.} =
    let
      alphaMask = mm_set1_epi32(cast[int32](0xff000000))
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))

    var
      sourceAlpha = mm_and_si128(source, alphaMask)
      backdropEven = mm_slli_epi16(backdrop, 8)
      backdropOdd = mm_and_si128(backdrop, oddMask)

    sourceAlpha = mm_or_si128(sourceAlpha, mm_srli_epi32(sourceAlpha, 16))

    let k = mm_sub_epi32(
      mm_set1_epi32(cast[int32]([0.uint8, 255, 0, 255])),
      sourceAlpha
    )

    backdropEven = mm_mulhi_epu16(backdropEven, k)
    backdropOdd = mm_mulhi_epu16(backdropOdd, k)

    backdropEven = mm_srli_epi16(mm_mulhi_epu16(backdropEven, div255), 7)
    backdropOdd = mm_srli_epi16(mm_mulhi_epu16(backdropOdd, div255), 7)

    mm_add_epi8(
      source,
      mm_or_si128(backdropEven, mm_slli_epi16(backdropOdd, 8))
    )

  proc blendMaskSimd*(backdrop, source: M128i): M128i {.inline.} =
    let
      alphaMask = mm_set1_epi32(cast[int32](0xff000000))
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))

    var
      sourceAlpha = mm_and_si128(source, alphaMask)
      backdropEven = mm_slli_epi16(backdrop, 8)
      backdropOdd = mm_and_si128(backdrop, oddMask)

    sourceAlpha = mm_or_si128(sourceAlpha, mm_srli_epi32(sourceAlpha, 16))

    backdropEven = mm_mulhi_epu16(backdropEven, sourceAlpha)
    backdropOdd = mm_mulhi_epu16(backdropOdd, sourceAlpha)

    backdropEven = mm_srli_epi16(mm_mulhi_epu16(backdropEven, div255), 7)
    backdropOdd = mm_srli_epi16(mm_mulhi_epu16(backdropOdd, div255), 7)

    mm_or_si128(backdropEven, mm_slli_epi16(backdropOdd, 8))

  proc normalSimdBlender(backdrop, source: M128i): M128i =
    blendNormalSimd(backdrop, source)

  proc maskSimdBlender(backdrop, source: M128i): M128i =
    blendMaskSimd(backdrop, source)

  proc overwriteSimdBlender(backdrop, source: M128i): M128i =
    source

  proc blenderSimd*(blendMode: BlendMode): BlenderSimd {.raises: [PixieError].} =
    ## Returns a blend function for a given blend mode with SIMD support.
    case blendMode:
    of NormalBlend: normalSimdBlender
    of MaskBlend: maskSimdBlender
    of OverwriteBlend: overwriteSimdBlender
    else:
      raise newException(PixieError, "No SIMD blender for " & $blendMode)

  proc hasSimdBlender*(blendMode: BlendMode): bool {.inline, raises: [].} =
    ## Is there a blend function for a given blend mode with SIMD support?
    blendMode in {NormalBlend, MaskBlend, OverwriteBlend}

  proc maskBlendNormalSimd*(backdrop, source: M128i): M128i {.inline.} =
    ## Blending masks
    let
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      v255high = mm_set1_epi16(cast[int16](255.uint16 shl 8))
      div255 = mm_set1_epi16(cast[int16](0x8081))

    var
      sourceEven = mm_slli_epi16(source, 8)
      sourceOdd = mm_and_si128(source, oddMask)

    let
      evenK = mm_sub_epi16(v255high, sourceEven)
      oddK = mm_sub_epi16(v255high, sourceOdd)

    var
      backdropEven = mm_slli_epi16(backdrop, 8)
      backdropOdd = mm_and_si128(backdrop, oddMask)

    # backdrop * k
    backdropEven = mm_mulhi_epu16(backdropEven, evenK)
    backdropOdd = mm_mulhi_epu16(backdropOdd, oddK)

    # div 255
    backdropEven = mm_srli_epi16(mm_mulhi_epu16(backdropEven, div255), 7)
    backdropOdd = mm_srli_epi16(mm_mulhi_epu16(backdropOdd, div255), 7)

    # Shift from high to low bits
    sourceEven = mm_srli_epi16(sourceEven, 8)
    sourceOdd = mm_srli_epi16(sourceOdd, 8)

    let
      blendedEven = mm_add_epi16(sourceEven, backdropEven)
      blendedOdd = mm_add_epi16(sourceOdd, backdropOdd)

    mm_or_si128(blendedEven, mm_slli_epi16(blendedOdd, 8))

  proc maskBlendMaskSimd*(backdrop, source: M128i): M128i =
    let
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))
      sourceEven = mm_slli_epi16(source, 8)
      sourceOdd = mm_and_si128(source, oddMask)

    var
      backdropEven = mm_slli_epi16(backdrop, 8)
      backdropOdd = mm_and_si128(backdrop, oddMask)

    # backdrop * source
    backdropEven = mm_mulhi_epu16(backdropEven, sourceEven)
    backdropOdd = mm_mulhi_epu16(backdropOdd, sourceOdd)

    # div 255
    backdropEven = mm_srli_epi16(mm_mulhi_epu16(backdropEven, div255), 7)
    backdropOdd = mm_srli_epi16(mm_mulhi_epu16(backdropOdd, div255), 7)

    mm_or_si128(backdropEven, mm_slli_epi16(backdropOdd, 8))

  proc maskBlendNormalSimdMasker(backdrop, source: M128i): M128i =
    maskBlendNormalSimd(backdrop, source)

  proc maskBlendMaskSimdMasker(backdrop, source: M128i): M128i =
    maskBlendMaskSimd(backdrop, source)

  proc maskerSimd*(blendMode: BlendMode): MaskerSimd {.raises: [PixieError].} =
    ## Returns a blend masking function with SIMD support.
    case blendMode:
    of NormalBlend: maskBlendNormalSimdMasker
    of MaskBlend: maskBlendMaskSimdMasker
    of OverwriteBlend: overwriteSimdBlender
    else:
      raise newException(PixieError, "No SIMD masker for " & $blendMode)

  proc hasSimdMasker*(blendMode: BlendMode): bool {.inline, raises: [].} =
    ## Is there a blend masking function with SIMD support?
    blendMode in {NormalBlend, MaskBlend, OverwriteBlend}

when defined(release):
  {.pop.}
