import chroma, internal, nimsimd/sse2, pixie/common, vmath

when defined(release):
  {.push checks: off.}

proc applyOpacity*(color: M128, opacity: float32): ColorRGBX {.inline.} =
  let opacityVec = mm_set1_ps(opacity)
  var finalColor = mm_cvtps_epi32(mm_mul_ps(color, opacityVec))
  finalColor = mm_packus_epi16(finalColor, mm_setzero_si128())
  finalColor = mm_packus_epi16(finalColor, mm_setzero_si128())
  cast[ColorRGBX](mm_cvtsi128_si32(finalColor))

proc packAlphaValues(v: M128i): M128i {.inline.} =
  ## Shuffle the alpha values for these 4 colors to the first 4 bytes.
  result = mm_srli_epi32(v, 24)
  result = mm_packus_epi16(result, mm_setzero_si128())
  result = mm_packus_epi16(result, mm_setzero_si128())

proc pack4xAlphaValues*(i, j, k, l: M128i): M128i {.inline.} =
  let
    i = packAlphaValues(i)
    j = mm_slli_si128(packAlphaValues(j), 4)
    k = mm_slli_si128(packAlphaValues(k), 8)
    l = mm_slli_si128(packAlphaValues(l), 12)
  mm_or_si128(mm_or_si128(i, j), mm_or_si128(k, l))

proc unpackAlphaValues*(v: M128i): M128i {.inline, raises: [].} =
  ## Unpack the first 32 bits into 4 rgba(0, 0, 0, value).
  result = mm_unpacklo_epi8(mm_setzero_si128(), v)
  result = mm_unpacklo_epi8(mm_setzero_si128(), result)

proc fillUnsafeSse2*(
  data: var seq[ColorRGBX],
  color: SomeColor,
  start, len: int
) {.simd.} =
  let rgbx = color.asRgbx()

  var
    i = start
    p = cast[uint](data[i].addr)
  # Align to 16 bytes
  while i < (start + len) and (p and 15) != 0:
    data[i] = rgbx
    inc i
    p += 4

  let
    colorVec = mm_set1_epi32(cast[int32](rgbx))
    iterations = (start + len - i) div 8
  for _ in 0 ..< iterations:
    mm_store_si128(cast[pointer](p), colorVec)
    mm_store_si128(cast[pointer](p + 16), colorVec)
    p += 32
  i += iterations * 8

  for i in i ..< start + len:
    data[i] = rgbx

proc isOneColorSse2*(image: Image): bool {.simd.} =
  result = true

  let color = image.data[0]

  var
    i: int
    p = cast[uint](image.data[0].addr)
  # Align to 16 bytes
  while i < image.data.len and (p and 15) != 0:
    if image.data[i] != color:
      return false
    inc i
    p += 4

  let
    colorVec = mm_set1_epi32(cast[int32](color))
    iterations = (image.data.len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm_load_si128(cast[pointer](p))
      values1 = mm_load_si128(cast[pointer](p + 16))
      values2 = mm_load_si128(cast[pointer](p + 32))
      values3 = mm_load_si128(cast[pointer](p + 48))
      eq0 = mm_cmpeq_epi8(values0, colorVec)
      eq1 = mm_cmpeq_epi8(values1, colorVec)
      eq2 = mm_cmpeq_epi8(values2, colorVec)
      eq3 = mm_cmpeq_epi8(values3, colorVec)
      eq0123 = mm_and_si128(mm_and_si128(eq0, eq1), mm_and_si128(eq2, eq3))
    if mm_movemask_epi8(eq0123) != 0xffff:
      return false
    p += 64
  i += 16 * iterations

  for i in i ..< image.data.len:
    if image.data[i] != color:
      return false

proc isTransparentSse2*(image: Image): bool {.simd.} =
  var
    i: int
    p = cast[uint](image.data[0].addr)
  # Align to 16 bytes
  while i < image.data.len and (p and 15) != 0:
    if image.data[i].a != 0:
      return false
    inc i
    p += 4

  result = true

  let
    vecZero = mm_setzero_si128()
    iterations = (image.data.len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm_load_si128(cast[pointer](p))
      values1 = mm_load_si128(cast[pointer](p + 16))
      values2 = mm_load_si128(cast[pointer](p + 32))
      values3 = mm_load_si128(cast[pointer](p + 48))
      values01 = mm_or_si128(values0, values1)
      values23 = mm_or_si128(values2, values3)
      values0123 = mm_or_si128(values01, values23)
    if mm_movemask_epi8(mm_cmpeq_epi8(values0123, vecZero)) != 0xffff:
      return false
    p += 64
  i += 16 * iterations

  for i in i ..< image.data.len:
    if image.data[i].a != 0:
      return false

proc isOpaqueSse2*(data: var seq[ColorRGBX], start, len: int): bool {.simd.} =
  result = true

  var
    i = start
    p = cast[uint](data[0].addr)
  # Align to 16 bytes
  while i < (start + len) and (p and 15) != 0:
    if data[i].a != 255:
      return false
    inc i
    p += 4

  let
    vec255 = mm_set1_epi8(255)
    iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm_load_si128(cast[pointer](p))
      values1 = mm_load_si128(cast[pointer](p + 16))
      values2 = mm_load_si128(cast[pointer](p + 32))
      values3 = mm_load_si128(cast[pointer](p + 48))
      values01 = mm_and_si128(values0, values1)
      values23 = mm_and_si128(values2, values3)
      values0123 = mm_and_si128(values01, values23)
      eq = mm_cmpeq_epi8(values0123, vec255)
    if (mm_movemask_epi8(eq) and 0x00008888) != 0x00008888:
      return false
    p += 64
  i += 16 * iterations

  for i in i ..< start + len:
    if data[i].a != 255:
      return false

proc toPremultipliedAlphaSse2*(data: var seq[ColorRGBA | ColorRGBX]) {.simd.} =
  var i: int

  let
    alphaMask = mm_set1_epi32(cast[int32](0xff000000))
    oddMask = mm_set1_epi16(0xff00)
    vec128 = mm_set1_epi16(128)
    hiMask = mm_set1_epi16(255 shl 8)
    iterations = data.len div 4
  for _ in 0 ..< iterations:
    let
      values = mm_loadu_si128(data[i].addr)
      alpha = mm_and_si128(values, alphaMask)
      eq = mm_cmpeq_epi8(values, alphaMask)
    if (mm_movemask_epi8(eq) and 0x00008888) != 0x00008888:
      let
        evenMultiplier = mm_or_si128(alpha, mm_srli_epi32(alpha, 16))
        oddMultiplier = mm_or_si128(evenMultiplier, alphaMask)
      var
        colorsEven = mm_slli_epi16(values, 8)
        colorsOdd = mm_and_si128(values, oddMask)
      colorsEven = mm_mulhi_epu16(colorsEven, evenMultiplier)
      colorsOdd = mm_mulhi_epu16(colorsOdd, oddMultiplier)
      let
        tmpEven = mm_add_epi16(colorsEven, vec128)
        tmpOdd = mm_add_epi16(colorsOdd, vec128)
      colorsEven = mm_srli_epi16(tmpEven, 8)
      colorsOdd = mm_srli_epi16(tmpOdd, 8)
      colorsEven = mm_add_epi16(colorsEven, tmpEven)
      colorsOdd = mm_add_epi16(colorsOdd, tmpOdd)
      colorsEven = mm_srli_epi16(colorsEven, 8)
      colorsOdd = mm_and_si128(colorsOdd, hiMask)
      mm_storeu_si128(data[i].addr, mm_or_si128(colorsEven, colorsOdd))
    i += 4

  for i in i ..< data.len:
    var c = data[i]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a + 127) div 255).uint8
      c.g = ((c.g.uint32 * c.a + 127) div 255).uint8
      c.b = ((c.b.uint32 * c.a + 127) div 255).uint8
      data[i] = c

proc newImageSse2*(mask: Mask): Image {.simd.} =
  result = newImage(mask.width, mask.height)

  var i: int
  for _ in 0 ..< mask.data.len div 16:
    var alphas = mm_loadu_si128(mask.data[i].addr)
    for j in 0 ..< 4:
      var unpacked = unpackAlphaValues(alphas)
      unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 8))
      unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 16))
      mm_storeu_si128(result.data[i + j * 4].addr, unpacked)
      alphas = mm_srli_si128(alphas, 4)
    i += 16

  for i in i ..< mask.data.len:
    let v = mask.data[i]
    result.data[i] = rgbx(v, v, v, v)

proc newMaskSse2*(image: Image): Mask {.simd.} =
  result = newMask(image.width, image.height)

  var i: int
  for _ in 0 ..< image.data.len div 16:
    let
      a = mm_loadu_si128(image.data[i + 0].addr)
      b = mm_loadu_si128(image.data[i + 4].addr)
      c = mm_loadu_si128(image.data[i + 8].addr)
      d = mm_loadu_si128(image.data[i + 12].addr)
    mm_storeu_si128(
      result.data[i].addr,
      pack4xAlphaValues(a, b, c, d)
    )
    i += 16

  for i in i ..< image.data.len:
    result.data[i] = image.data[i].a

proc invertSse2*(target: Image | Mask) {.simd.} =
  var
    i: int
    p = cast[uint](target.data[0].addr)
  # Align to 16 bytes
  while i < target.data.len and (p and 15) != 0:
    when target is Image:
      var rgbx = target.data[i]
      rgbx.r = 255 - rgbx.r
      rgbx.g = 255 - rgbx.g
      rgbx.b = 255 - rgbx.b
      rgbx.a = 255 - rgbx.a
      target.data[i] = rgbx
      inc i
      p += 4
    else:
      target.data[i] = 255 - target.data[i]
      inc i
      inc p

  let vec255 = mm_set1_epi8(255)

  when target is Image:
    let iterations = target.data.len div 16
  else:
    let iterations = target.data.len div 64

  for _ in 0 ..< iterations:
    let
      a = mm_load_si128(cast[pointer](p))
      b = mm_load_si128(cast[pointer](p + 16))
      c = mm_load_si128(cast[pointer](p + 32))
      d = mm_load_si128(cast[pointer](p + 48))
    mm_store_si128(cast[pointer](p), mm_sub_epi8(vec255, a))
    mm_store_si128(cast[pointer](p + 16), mm_sub_epi8(vec255, b))
    mm_store_si128(cast[pointer](p + 32), mm_sub_epi8(vec255, c))
    mm_store_si128(cast[pointer](p + 48), mm_sub_epi8(vec255, d))
    p += 64

  when target is Image:
    i += 16 * iterations

    for i in i ..< target.data.len:
      var rgbx = target.data[i]
      rgbx.r = 255 - rgbx.r
      rgbx.g = 255 - rgbx.g
      rgbx.b = 255 - rgbx.b
      rgbx.a = 255 - rgbx.a
      target.data[i] = rgbx

    toPremultipliedAlphaSse2(target.data)
  else:
    i += 64 * iterations

    for i in i ..< target.data.len:
      target.data[i] = 255 - target.data[i]

proc ceilSse2*(mask: Mask) {.simd.} =
  var
    i: int
    p = cast[uint](mask.data[0].addr)

  let
    zeroVec = mm_setzero_si128()
    vec255 = mm_set1_epi8(255)
    iterations = mask.data.len div 16
  for _ in 0 ..< iterations:
    var values = mm_loadu_si128(cast[pointer](p))
    values = mm_cmpeq_epi8(values, zeroVec)
    values = mm_andnot_si128(values, vec255)
    mm_storeu_si128(cast[pointer](p), values)
    p += 16
  i += 16 * iterations

  for i in i ..< mask.data.len:
    if mask.data[i] != 0:
      mask.data[i] = 255

proc applyOpacitySse2*(target: Image | Mask, opacity: float32) {.simd.} =
  let opacity = round(255 * opacity).uint16
  if opacity == 255:
    return

  if opacity == 0:
    when target is Image:
      target.fill(rgbx(0, 0, 0, 0))
    else:
      target.fill(0)
    return

  var
    i: int
    p = cast[uint](target.data[0].addr)
    len =
      when target is Image:
        target.data.len * 4
      else:
        target.data.len

  let
    oddMask = mm_set1_epi16(0xff00)
    div255 = mm_set1_epi16(0x8081)
    zeroVec = mm_setzero_si128()
    opacityVec = mm_slli_epi16(mm_set1_epi16(opacity), 8)
    iterations = len div 16
  for _ in 0 ..< len div 16:
    let values = mm_loadu_si128(cast[pointer](p))
    if mm_movemask_epi8(mm_cmpeq_epi16(values, zeroVec)) != 0xffff:
      var
        valuesEven = mm_slli_epi16(values, 8)
        valuesOdd = mm_and_si128(values, oddMask)
      valuesEven = mm_mulhi_epu16(valuesEven, opacityVec)
      valuesOdd = mm_mulhi_epu16(valuesOdd, opacityVec)
      valuesEven = mm_srli_epi16(mm_mulhi_epu16(valuesEven, div255), 7)
      valuesOdd = mm_srli_epi16(mm_mulhi_epu16(valuesOdd, div255), 7)
      mm_storeu_si128(
        cast[pointer](p),
        mm_or_si128(valuesEven, mm_slli_epi16(valuesOdd, 8))
      )
    p += 16
  i += 16 * iterations

  when target is Image:
    for i in i div 4 ..< target.data.len:
      var rgbx = target.data[i]
      rgbx.r = ((rgbx.r * opacity) div 255).uint8
      rgbx.g = ((rgbx.g * opacity) div 255).uint8
      rgbx.b = ((rgbx.b * opacity) div 255).uint8
      rgbx.a = ((rgbx.a * opacity) div 255).uint8
      target.data[i] = rgbx
  else:
    for i in i ..< target.data.len:
      target.data[i] = ((target.data[i] * opacity) div 255).uint8

when defined(release):
  {.pop.}
