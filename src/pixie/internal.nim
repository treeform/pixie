import chroma, common, system/memory, vmath

const allowSimd* = not defined(pixieNoSimd) and not defined(tcc)

when defined(amd64) and allowSimd:
  import nimsimd/sse2

template currentExceptionAsPixieError*(): untyped =
  ## Gets the current exception and returns it as a PixieError with stack trace.
  let e = getCurrentException()
  newException(PixieError, e.getStackTrace & e.msg, e)

template failUnsupportedBlendMode*(blendMode: BlendMode) =
  raise newException(
    PixieError,
    "Blend mode " & $blendMode & " not supported here"
  )

when defined(release):
  {.push checks: off.}

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
    when defined(amd64) and allowSimd:
      # Align to 16 bytes
      while i < (start + len) and (cast[uint](data[i].addr) and 15) != 0:
        data[i] = rgbx
        inc i
      # When supported, SIMD fill until we run out of room
      let
        colorVec = mm_set1_epi32(cast[int32](rgbx))
        remaining = start + len - i
      for _ in 0 ..< remaining div 8:
        mm_store_si128(data[i + 0].addr, colorVec)
        mm_store_si128(data[i + 4].addr, colorVec)
        i += 8
    else:
      when sizeof(int) == 8:
        # Fill 8 bytes at a time when possible
        var
          u32 = cast[uint32](rgbx)
          u64 = cast[uint64]([u32, u32])
        for _ in 0 ..< len div 2:
          copyMem(data[i].addr, u64.addr, 8)
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
  when defined(amd64) and allowSimd:
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

  for j in i ..< start + len:
    if data[j].a != 255:
      return false

when defined(amd64) and allowSimd:
  proc packAlphaValues*(v: M128i): M128i {.inline, raises: [].} =
    ## Shuffle the alpha values for these 4 colors to the first 4 bytes
    let mask = mm_set1_epi32(cast[int32](0xff000000))
    result = mm_and_si128(v, mask)
    result = mm_srli_epi32(result, 24)
    result = mm_packus_epi16(result, result)
    result = mm_packus_epi16(result, result)
    result = mm_srli_si128(result, 12)

  proc pack4xAlphaValues*(i, j, k, l: M128i): M128i {.inline, raises: [].} =
    let
      i = packAlphaValues(i)
      j = mm_slli_si128(packAlphaValues(j), 4)
      k = mm_slli_si128(packAlphaValues(k), 8)
      l = mm_slli_si128(packAlphaValues(l), 12)
    mm_or_si128(mm_or_si128(i, j), mm_or_si128(k, l))

  proc unpackAlphaValues*(v: M128i): M128i {.inline, raises: [].} =
    ## Unpack the first 32 bits into 4 rgba(0, 0, 0, value)
    let
      a = mm_unpacklo_epi8(v, mm_setzero_si128())
      b = mm_unpacklo_epi8(a, mm_setzero_si128())
    result = mm_slli_epi32(b, 24) # Shift the values to uint32 `a`

when defined(release):
  {.pop.}
