import avx, chroma, internal, nimsimd/avx2, pixie/common, vmath

when defined(gcc) or defined(clang):
  {.localPassc: "-mavx2".}

when defined(release):
  {.push checks: off.}

proc isOneColorAvx2*(image: Image): bool {.simd.} =
  result = true

  let color = image.data[0]

  var i: int
  # Align to 32 bytes
  while i < image.data.len and (cast[uint](image.data[i].addr) and 31) != 0:
    if image.data[i] != color:
      return false
    inc i

  let
    colorVec = mm256_set1_epi32(cast[int32](color))
    iterations = (image.data.len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm256_load_si256(image.data[i].addr)
      values1 = mm256_load_si256(image.data[i + 8].addr)
      eq0 = mm256_cmpeq_epi8(values0, colorVec)
      eq1 = mm256_cmpeq_epi8(values1, colorVec)
      eq01 = mm256_and_si256(eq0, eq1)
    if mm256_movemask_epi8(eq01) != cast[int32](0xffffffff):
      return false
    i += 16

  for i in i ..< image.data.len:
    if image.data[i] != color:
      return false

proc isTransparentAvx2*(image: Image): bool {.simd.} =
  result = true

  var i: int
  # Align to 32 bytes
  while i < image.data.len and (cast[uint](image.data[i].addr) and 31) != 0:
    if image.data[i].a != 0:
      return false
    inc i

  let
    vecZero = mm256_setzero_si256()
    iterations = (image.data.len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm256_load_si256(image.data[i].addr)
      values1 = mm256_load_si256(image.data[i + 8].addr)
      values01 = mm256_or_si256(values0, values1)
      eq = mm256_cmpeq_epi8(values01, vecZero)
    if mm256_movemask_epi8(eq) != cast[int32](0xffffffff):
      return false
    i += 16

  for i in i ..< image.data.len:
    if image.data[i].a != 0:
      return false

proc isOpaqueAvx2*(data: var seq[ColorRGBX], start, len: int): bool {.simd.} =
  result = true

  var i = start
  # Align to 32 bytes
  while i < (start + len) and (cast[uint](data[i].addr) and 31) != 0:
    if data[i].a != 255:
      return false
    inc i

  let
    vec255 = mm256_set1_epi8(255)
    iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm256_load_si256(data[i].addr)
      values1 = mm256_load_si256(data[i + 8].addr)
      values01 = mm256_and_si256(values0, values1)
      eq = mm256_cmpeq_epi8(values01, vec255)
    if (mm256_movemask_epi8(eq) and 0x88888888) != 0x88888888:
      return false
    i += 16

  for i in i ..< start + len:
    if data[i].a != 255:
      return false

proc toPremultipliedAlphaAvx2*(data: var seq[ColorRGBA | ColorRGBX]) {.simd.} =
  var i: int

  let
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    oddMask = mm256_set1_epi16(0xff00)
    vec128 = mm256_set1_epi16(128)
    hiMask = mm256_set1_epi16(255 shl 8)
    iterations = data.len div 8
  for _ in 0 ..< iterations:
    let
      values = mm256_loadu_si256(data[i].addr)
      alpha = mm256_and_si256(values, alphaMask)
      eq = mm256_cmpeq_epi8(values, alphaMask)
    if (mm256_movemask_epi8(eq) and 0x88888888) != 0x88888888:
      let
        evenMultiplier = mm256_or_si256(alpha, mm256_srli_epi32(alpha, 16))
        oddMultiplier = mm256_or_si256(evenMultiplier, alphaMask)
      var
        colorsEven = mm256_slli_epi16(values, 8)
        colorsOdd = mm256_and_si256(values, oddMask)
      colorsEven = mm256_mulhi_epu16(colorsEven, evenMultiplier)
      colorsOdd = mm256_mulhi_epu16(colorsOdd, oddMultiplier)
      let
        tmpEven = mm256_add_epi16(colorsEven, vec128)
        tmpOdd = mm256_add_epi16(colorsOdd, vec128)
      colorsEven = mm256_srli_epi16(tmpEven, 8)
      colorsOdd = mm256_srli_epi16(tmpOdd, 8)
      colorsEven = mm256_add_epi16(colorsEven, tmpEven)
      colorsOdd = mm256_add_epi16(colorsOdd, tmpOdd)
      colorsEven = mm256_srli_epi16(colorsEven, 8)
      colorsOdd = mm256_and_si256(colorsOdd, hiMask)
      mm256_storeu_si256(data[i].addr, mm256_or_si256(colorsEven, colorsOdd))
    i += 8

  for i in i ..< data.len:
    var c = data[i]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a + 127) div 255).uint8
      c.g = ((c.g.uint32 * c.a + 127) div 255).uint8
      c.b = ((c.b.uint32 * c.a + 127) div 255).uint8
      data[i] = c

proc invertAvx2*(image: Image) {.simd.} =
  var
    i: int
    p = cast[uint](image.data[0].addr)
  # Align to 32 bytes
  while i < image.data.len and (p and 31) != 0:
    var rgbx = image.data[i]
    rgbx.r = 255 - rgbx.r
    rgbx.g = 255 - rgbx.g
    rgbx.b = 255 - rgbx.b
    rgbx.a = 255 - rgbx.a
    image.data[i] = rgbx
    inc i
    p += 4

  let
    vec255 = mm256_set1_epi8(255)
    iterations = image.data.len div 16
  for _ in 0 ..< iterations:
    let
      a = mm256_load_si256(cast[pointer](p))
      b = mm256_load_si256(cast[pointer](p + 32))
    mm256_store_si256(cast[pointer](p), mm256_sub_epi8(vec255, a))
    mm256_store_si256(cast[pointer](p + 32), mm256_sub_epi8(vec255, b))
    p += 64
  i += 16 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = 255 - rgbx.r
    rgbx.g = 255 - rgbx.g
    rgbx.b = 255 - rgbx.b
    rgbx.a = 255 - rgbx.a
    image.data[i] = rgbx

  toPremultipliedAlphaAvx2(image.data)

proc applyOpacityAvx2*(image: Image, opacity: float32) {.simd.} =
  let opacity = round(255 * opacity).uint16
  if opacity == 255:
    return

  if opacity == 0:
    fillUnsafeAvx(image.data, rgbx(0, 0, 0, 0), 0, image.data.len)
    return

  var
    i: int
    p = cast[uint](image.data[0].addr)

  let
    oddMask = mm256_set1_epi16(0xff00)
    div255 = mm256_set1_epi16(0x8081)
    zeroVec = mm256_setzero_si256()
    opacityVec = mm256_slli_epi16(mm256_set1_epi16(opacity), 8)
    iterations = image.data.len div 8
  for _ in 0 ..< iterations:
    let
      values = mm256_loadu_si256(cast[pointer](p))
      eqZero = mm256_cmpeq_epi16(values, zeroVec)
    if mm256_movemask_epi8(eqZero) != cast[int32](0xffffffff):
      var
        valuesEven = mm256_slli_epi16(values, 8)
        valuesOdd = mm256_and_si256(values, oddMask)
      valuesEven = mm256_mulhi_epu16(valuesEven, opacityVec)
      valuesOdd = mm256_mulhi_epu16(valuesOdd, opacityVec)
      valuesEven = mm256_srli_epi16(mm256_mulhi_epu16(valuesEven, div255), 7)
      valuesOdd = mm256_srli_epi16(mm256_mulhi_epu16(valuesOdd, div255), 7)
      mm256_storeu_si256(
        cast[pointer](p),
        mm256_or_si256(valuesEven, mm256_slli_epi16(valuesOdd, 8))
      )
    p += 32
  i += 8 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = ((rgbx.r * opacity) div 255).uint8
    rgbx.g = ((rgbx.g * opacity) div 255).uint8
    rgbx.b = ((rgbx.b * opacity) div 255).uint8
    rgbx.a = ((rgbx.a * opacity) div 255).uint8
    image.data[i] = rgbx

when defined(release):
  {.pop.}
