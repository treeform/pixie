import chroma, system/memory, vmath

const allowSimd* = not defined(pixieNoSimd) and not defined(tcc)

when allowSimd:
  when defined(amd64):
    import nimsimd/ssse3
  elif defined(arm64):
    import nimsimd/neon

template currentExceptionAsPixieError*(): untyped =
  ## Gets the current exception and returns it as a PixieError with stack trace.
  let e = getCurrentException()
  newException(PixieError, e.getStackTrace & e.msg, e)

proc gaussianKernel*(radius: int): seq[uint16] {.raises: [].} =
  ## Compute lookup table for 1d Gaussian kernel.
  ## Values are [0, 255] * 256.
  result.setLen(radius * 2 + 1)

  var
    floats = newSeq[float32](result.len)
    total = 0.0
  for step in -radius .. radius:
    let
      s = radius.float32 / 2.2 # 2.2 matches Figma.
      a = 1 / sqrt(2 * PI * s^2) * exp(-1 * step.float32^2 / (2 * s^2))
    floats[step + radius] = a
    total += a
  for step in -radius .. radius:
    floats[step + radius] = floats[step + radius] / total
  for i, f in floats:
    result[i] = round(f * 255 * 256).uint16

proc `*`*(color: ColorRGBX, opacity: float32): ColorRGBX {.raises: [].} =
  if opacity == 0:
    rgbx(0, 0, 0, 0)
  else:
    let
      x = round(opacity * 255).uint32
      r = ((color.r * x) div 255).uint8
      g = ((color.g * x) div 255).uint8
      b = ((color.b * x) div 255).uint8
      a = ((color.a * x) div 255).uint8
    rgbx(r, g, b, a)

proc fillUnsafe*(
  data: var seq[uint8], value: uint8, start, len: int
) {.raises: [].} =
  ## Fills the mask data with the value starting at index start and
  ## continuing for len indices.
  nimSetMem(data[start].addr, value.cint, len)

proc fillUnsafe*(
  data: var seq[ColorRGBX], color: SomeColor, start, len: int
) {.raises: [].} =
  ## Fills the image data with the color starting at index start and
  ## continuing for len indices.

  let rgbx = color.asRgbx()

  # Use memset when every byte has the same value
  if rgbx.r == rgbx.g and rgbx.r == rgbx.b and rgbx.r == rgbx.a:
    nimSetMem(data[start].addr, rgbx.r.cint, len * 4)
  else:
    var i = start
    when allowSimd and defined(amd64):
      # When supported, SIMD fill until we run out of room
      let colorVec = mm_set1_epi32(cast[int32](rgbx))
      for _ in 0 ..< len div 8:
        mm_storeu_si128(data[i + 0].addr, colorVec)
        mm_storeu_si128(data[i + 4].addr, colorVec)
        i += 8
    elif allowSimd and defined(arm64):
      let
        colors = vmovq_n_u32(cast[uint32](rgbx))
        x4 = vld4q_dup_u32(colors.unsafeAddr)
      for _ in 0 ..< len div 16:
        vst1q_u32_x4(data[i + 0].addr, x4)
        i += 16
    else:
      when sizeof(int) == 8:
        # Fill 8 bytes at a time when possible
        let
          u32 = cast[uint32](rgbx)
          u64 = cast[uint64]([u32, u32])
        for _ in 0 ..< len div 2:
          cast[ptr uint64](data[i].addr)[] = u64
          i += 2
    # Fill whatever is left the slow way
    for j in i ..< start + len:
      data[j] = rgbx

const straightAlphaTable = block:
  var table: array[256, array[256, uint8]]
  for a in 0 ..< 256:
    let multiplier = if a > 0: (255 / a.float32) else: 0
    for c in 0 ..< 256:
      table[a][c] = min(round((c.float32 * multiplier)), 255).uint8
  table

proc toStraightAlpha*(data: var seq[ColorRGBA | ColorRGBX]) {.raises: [].} =
  ## Converts an image from premultiplied alpha to straight alpha.
  ## This is expensive for large images.

  # This SIMD works but is currently slower
  # var i: int
  # when defined(amd64) and allowSimd:
  #   let
  #     v255 = mm_set1_epi32(255)
  #     v255f = mm_cvtepi32_ps(v255)
  #     alphaMask = mm_set1_epi32(cast[int32](0xff000000))

  #   proc unpackColor(v: M128i): M128i {.inline.} =
  #     result = mm_unpacklo_epi8(v, mm_setzero_si128())
  #     result = mm_unpacklo_epi8(result, mm_setzero_si128())

  #   proc packColor(v: M128i): M128i {.inline.} =
  #     result = mm_packs_epi32(v, mm_setzero_si128())
  #     result = mm_packus_epi16(result, mm_setzero_si128())

  #   for _ in 0 ..< data.len div 4:
  #     let
  #       v = mm_loadu_si128(data[i].addr)
  #       alphas = mm_cvtepi32_ps(mm_srli_si128(mm_and_si128(v, alphaMask), 3))
  #       multipliers = mm_div_ps(v255f, alphas)
  #       m0 = mm_shuffle_ps(multipliers, multipliers, MM_SHUFFLE(0, 0, 0, 0))
  #       m1 = mm_shuffle_ps(multipliers, multipliers, MM_SHUFFLE(1, 1, 1, 1))
  #       m2 = mm_shuffle_ps(multipliers, multipliers, MM_SHUFFLE(2, 2, 2, 2))
  #       m3 = mm_shuffle_ps(multipliers, multipliers, MM_SHUFFLE(3, 3, 3, 3))
  #       c0 = unpackColor(v)
  #       c1 = unpackColor(mm_srli_si128(v, 4))
  #       c2 = unpackColor(mm_srli_si128(v, 8))
  #       c3 = unpackColor(mm_srli_si128(v, 12))
  #       f0 = mm_cvtepi32_ps(c0)
  #       f1 = mm_cvtepi32_ps(c1)
  #       f2 = mm_cvtepi32_ps(c2)
  #       f3 = mm_cvtepi32_ps(c3)
  #       fs0 = mm_mul_ps(f0, m0)
  #       fs1 = mm_mul_ps(f1, m1)
  #       fs2 = mm_mul_ps(f2, m2)
  #       fs3 = mm_mul_ps(f3, m3)
  #       s0 = mm_cvtps_epi32(fs0)
  #       s1 = mm_cvtps_epi32(fs1)
  #       s2 = mm_cvtps_epi32(fs2)
  #       s3 = mm_cvtps_epi32(fs3)
  #       gt0 = mm_cmpgt_epi32(s0, v255)
  #       gt1 = mm_cmpgt_epi32(s1, v255)
  #       gt2 = mm_cmpgt_epi32(s2, v255)
  #       gt3 = mm_cmpgt_epi32(s3, v255)
  #       s0c = mm_or_si128(mm_andnot_si128(gt0, s0), mm_and_si128(gt0, v255))
  #       s1c = mm_or_si128(mm_andnot_si128(gt1, s1), mm_and_si128(gt1, v255))
  #       s2c = mm_or_si128(mm_andnot_si128(gt2, s2), mm_and_si128(gt2, v255))
  #       s3c = mm_or_si128(mm_andnot_si128(gt3, s3), mm_and_si128(gt3, v255))
  #       p0 = packColor(s0c)
  #       p1 = packColor(s1c)
  #       p2 = packColor(s2c)
  #       p3 = packColor(s3c)
  #       p01 = mm_or_si128(p0, mm_slli_si128(p1, 4))
  #       p23 = mm_or_si128(mm_slli_si128(p2, 8), mm_slli_si128(p3, 12))
  #       p = mm_or_si128(p01, p23)
  #       pp = mm_or_si128(mm_andnot_si128(alphaMask, p), mm_and_si128(v, alphaMask))
  #     mm_storeu_si128(data[i].addr, pp)
  #     i += 4

  for i in 0 ..< data.len:
    var c = data[i]
    c.r = straightAlphaTable[c.a][c.r]
    c.g = straightAlphaTable[c.a][c.g]
    c.b = straightAlphaTable[c.a][c.b]
    data[i] = c

proc toPremultipliedAlpha*(data: var seq[ColorRGBA | ColorRGBX]) {.raises: [].} =
  ## Converts an image to premultiplied alpha from straight alpha.
  var i: int
  when defined(amd64) and allowSimd:
    # When supported, SIMD convert as much as possible
    let
      alphaMask = mm_set1_epi32(cast[int32](0xff000000))
      notAlphaMask = mm_set1_epi32(0x00ffffff)
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))
    for _ in 0 ..< data.len div 4:
      var
        color = mm_loadu_si128(data[i].addr)
        alpha = mm_and_si128(color, alphaMask)
      if mm_movemask_epi8(mm_cmpeq_epi16(alpha, alphaMask)) != 0xffff:
        # If not all of the alpha values are 255, premultiply
        var
          colorEven = mm_slli_epi16(color, 8)
          colorOdd = mm_and_si128(color, oddMask)

        alpha = mm_or_si128(alpha, mm_srli_epi32(alpha, 16))

        colorEven = mm_mulhi_epu16(colorEven, alpha)
        colorOdd = mm_mulhi_epu16(colorOdd, alpha)

        colorEven = mm_srli_epi16(mm_mulhi_epu16(colorEven, div255), 7)
        colorOdd = mm_srli_epi16(mm_mulhi_epu16(colorOdd, div255), 7)

        color = mm_or_si128(colorEven, mm_slli_epi16(colorOdd, 8))
        color = mm_or_si128(
          mm_and_si128(alpha, alphaMask), mm_and_si128(color, notAlphaMask)
        )

        mm_storeu_si128(data[i].addr, color)

      i += 4

  # Convert whatever is left
  for j in i ..< data.len:
    var c = data[j]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a.uint32) div 255).uint8
      c.g = ((c.g.uint32 * c.a.uint32) div 255).uint8
      c.b = ((c.b.uint32 * c.a.uint32) div 255).uint8
      data[j] = c

proc isOpaque*(data: var seq[ColorRGBX], start, len: int): bool =
  result = true

  var i = start
  when allowSimd:
    when defined(amd64):
      let
        vec255 = mm_set1_epi32(cast[int32](uint32.high))
        colorMask = mm_set1_epi32(cast[int32]([255.uint8, 255, 255, 0]))
      for _ in start ..< (start + len) div 16:
        let
          values0 = mm_loadu_si128(data[i + 0].addr)
          values1 = mm_loadu_si128(data[i + 4].addr)
          values2 = mm_loadu_si128(data[i + 8].addr)
          values3 = mm_loadu_si128(data[i + 12].addr)
          values01 = mm_and_si128(values0, values1)
          values23 = mm_and_si128(values2, values3)
          values = mm_or_si128(mm_and_si128(values01, values23), colorMask)
        if mm_movemask_epi8(mm_cmpeq_epi8(values, vec255)) != 0xffff:
          return false
        i += 16
    elif defined(arm64):
      for _ in start ..< (start + len) div 16:
        let
          alphas = vld4q_u8(data[i].addr).val[3]
          eq = vceqq_u64(cast[uint64x2](alphas), vmovq_n_u64(uint64.high))
          mask = vget_low_u64(eq) and vget_high_u64(eq)
        if mask != uint64.high:
          return false
        i += 16

  for j in i ..< start + len:
    if data[j].a != 255:
      return false

when defined(amd64) and allowSimd:
  proc packAlphaValues*(v: M128i): M128i {.inline, raises: [].} =
    ## Shuffle the alpha values for these 4 colors to the first 4 bytes
    let
      mask = mm_set1_epi32(cast[int32]([0.uint8, 0, 0, uint8.high]))
      control = mm_set_epi8(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 15, 11, 7, 3)
    result = mm_and_si128(v, mask)
    result = mm_shuffle_epi8(result, control)

  proc pack4xAlphaValues*(a, b, c, d: M128i): M128i {.inline, raises: [].} =
    let
      a = packAlphaValues(a)
      b = mm_slli_si128(packAlphaValues(b), 4)
      c = mm_slli_si128(packAlphaValues(c), 8)
      d = mm_slli_si128(packAlphaValues(d), 12)
    mm_or_si128(mm_or_si128(a, b), mm_or_si128(c, d))

  proc unpackAlphaValues*(v: M128i): M128i {.inline, raises: [].} =
    ## Unpack the first 32 bits into 4 rgba(0, 0, 0, value)
    let
      mask = mm_set_epi32(0, 0, 0, cast[int32](uint32.high))
      control = mm_set_epi8(3, 4, 4, 4, 2, 4, 4, 4, 1, 4, 4, 4, 0, 4, 4, 4)
    result = mm_shuffle_epi8(mm_and_si128(v, mask), control)
