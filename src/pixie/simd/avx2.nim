import avx, chroma, nimsimd/hassimd, nimsimd/avx2, pixie/blends, pixie/common, vmath

when defined(gcc) or defined(clang):
  {.localPassc: "-mavx2".}

when defined(release):
  {.push checks: off.}

template blendNormalSimd(backdrop, source: M256i): M256i =
  var
    sourceAlpha = mm256_and_si256(source, alphaMask)
    backdropEven = mm256_slli_epi16(backdrop, 8)
    backdropOdd = mm256_and_si256(backdrop, oddMask)

  sourceAlpha = mm256_shuffle_epi8(sourceAlpha, shuffleControl)

  let multiplier = mm256_sub_epi32(vecAlpha255, sourceAlpha)

  backdropEven = mm256_mulhi_epu16(backdropEven, multiplier)
  backdropOdd = mm256_mulhi_epu16(backdropOdd, multiplier)
  backdropEven = mm256_srli_epi16(mm256_mulhi_epu16(backdropEven, div255), 7)
  backdropOdd = mm256_srli_epi16(mm256_mulhi_epu16(backdropOdd, div255), 7)

  mm256_add_epi8(
    source,
    mm256_or_si256(backdropEven, mm256_slli_epi16(backdropOdd, 8))
  )

template blendMaskSimd(backdrop, source: M256i): M256i =
  var
    sourceAlpha = mm256_and_si256(source, alphaMask)
    backdropEven = mm256_slli_epi16(backdrop, 8)
    backdropOdd = mm256_and_si256(backdrop, oddMask)

  sourceAlpha = mm256_shuffle_epi8(sourceAlpha, shuffleControl)

  backdropEven = mm256_mulhi_epu16(backdropEven, sourceAlpha)
  backdropOdd = mm256_mulhi_epu16(backdropOdd, sourceAlpha)
  backdropEven = mm256_srli_epi16(mm256_mulhi_epu16(backdropEven, div255), 7)
  backdropOdd = mm256_srli_epi16(mm256_mulhi_epu16(backdropOdd, div255), 7)

  mm256_or_si256(backdropEven, mm256_slli_epi16(backdropOdd, 8))

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
  var
    i: int
    p = cast[uint](data[0].addr)
  # Align to 32 bytes
  while i < data.len and (p and 31) != 0:
    var rgbx = data[i]
    if rgbx.a != 255:
      rgbx.r = ((rgbx.r.uint32 * rgbx.a + 127) div 255).uint8
      rgbx.g = ((rgbx.g.uint32 * rgbx.a + 127) div 255).uint8
      rgbx.b = ((rgbx.b.uint32 * rgbx.a + 127) div 255).uint8
      data[i] = rgbx
    inc i
    p += 4

  let
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    shuffleControl = mm256_set_epi8(
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1,
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1
    )
    oddMask = mm256_set1_epi16(0xff00)
    vec128 = mm256_set1_epi16(128)
    hiMask = mm256_set1_epi16(255 shl 8)
    iterations = (data.len - i) div 8
  for _ in 0 ..< iterations:
    let
      values = mm256_load_si256(cast[pointer](p))
      alpha = mm256_and_si256(values, alphaMask)
      eq = mm256_cmpeq_epi8(values, alphaMask)
    if (mm256_movemask_epi8(eq) and 0x88888888) != 0x88888888:
      let
        evenMultiplier = mm256_shuffle_epi8(alpha, shuffleControl)
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
      mm256_store_si256(cast[pointer](p), mm256_or_si256(colorsEven, colorsOdd))
    p += 32
  i += 8 * iterations

  for i in i ..< data.len:
    var rgbx = data[i]
    if rgbx.a != 255:
      rgbx.r = ((rgbx.r.uint32 * rgbx.a + 127) div 255).uint8
      rgbx.g = ((rgbx.g.uint32 * rgbx.a + 127) div 255).uint8
      rgbx.b = ((rgbx.b.uint32 * rgbx.a + 127) div 255).uint8
      data[i] = rgbx

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
    iterations = (image.data.len - i) div 16
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
  # Align to 32 bytes
  while i < image.data.len and (p and 31) != 0:
    var rgbx = image.data[i]
    rgbx.r = ((rgbx.r * opacity) div 255).uint8
    rgbx.g = ((rgbx.g * opacity) div 255).uint8
    rgbx.b = ((rgbx.b * opacity) div 255).uint8
    rgbx.a = ((rgbx.a * opacity) div 255).uint8
    image.data[i] = rgbx
    inc i
    p += 4

  let
    oddMask = mm256_set1_epi16(0xff00)
    div255 = mm256_set1_epi16(0x8081)
    zeroVec = mm256_setzero_si256()
    opacityVec = mm256_slli_epi16(mm256_set1_epi16(opacity), 8)
    iterations = (image.data.len - i) div 8
  for _ in 0 ..< iterations:
    let
      values = mm256_load_si256(cast[pointer](p))
      eqZero = mm256_cmpeq_epi16(values, zeroVec)
    if mm256_movemask_epi8(eqZero) != cast[int32](0xffffffff):
      var
        valuesEven = mm256_slli_epi16(values, 8)
        valuesOdd = mm256_and_si256(values, oddMask)
      valuesEven = mm256_mulhi_epu16(valuesEven, opacityVec)
      valuesOdd = mm256_mulhi_epu16(valuesOdd, opacityVec)
      valuesEven = mm256_srli_epi16(mm256_mulhi_epu16(valuesEven, div255), 7)
      valuesOdd = mm256_srli_epi16(mm256_mulhi_epu16(valuesOdd, div255), 7)
      mm256_store_si256(
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

proc ceilAvx2*(image: Image) {.simd.} =
  var
    i: int
    p = cast[uint](image.data[0].addr)
  # Align to 32 bytes
  while i < image.data.len and (p and 31) != 0:
    var rgbx = image.data[i]
    rgbx.r = if rgbx.r == 0: 0 else: 255
    rgbx.g = if rgbx.g == 0: 0 else: 255
    rgbx.b = if rgbx.b == 0: 0 else: 255
    rgbx.a = if rgbx.a == 0: 0 else: 255
    image.data[i] = rgbx
    inc i
    p += 4

  let
    vecZero = mm256_setzero_si256()
    vec255 = mm256_set1_epi8(255)
    iterations = (image.data.len - i) div 8
  for _ in 0 ..< iterations:
    var values = mm256_load_si256(cast[pointer](p))
    values = mm256_cmpeq_epi8(values, vecZero)
    values = mm256_andnot_si256(values, vec255)
    mm256_store_si256(cast[pointer](p), values)
    p += 32
  i += 8 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = if rgbx.r == 0: 0 else: 255
    rgbx.g = if rgbx.g == 0: 0 else: 255
    rgbx.b = if rgbx.b == 0: 0 else: 255
    rgbx.a = if rgbx.a == 0: 0 else: 255
    image.data[i] = rgbx

proc minifyBy2Avx2*(image: Image, power = 1): Image {.simd.} =
  ## Scales the image down by an integer scale.
  if power < 0:
    raise newException(PixieError, "Cannot minifyBy2 with negative power")
  if power == 0:
    return image.copy()

  var src = image
  for _ in 1 .. power:
    # When minifying an image of odd size, round the result image size up
    # so a 99 x 99 src image returns a 50 x 50 image.
    let
      srcWidthIsOdd = (src.width mod 2) != 0
      srcHeightIsOdd = (src.height mod 2) != 0
      resultEvenWidth = src.width div 2
      resultEvenHeight = src.height div 2
    result = newImage(
      if srcWidthIsOdd: resultEvenWidth + 1 else: resultEvenWidth,
      if srcHeightIsOdd: resultEvenHeight + 1 else: resultEvenHeight
    )
    let
      oddMask = mm256_set1_epi16(0xff00)
      vec2 = mm256_set1_epi16(2)
      permuteControl = mm256_set_epi32(7, 7, 7, 7, 6, 4, 2, 0)
    for y in 0 ..< resultEvenHeight:
      let
        topRowStart = src.dataIndex(0, y * 2)
        bottomRowStart = src.dataIndex(0, y * 2 + 1)

      var x: int
      while x <= resultEvenWidth - 8:
        let
          top = mm256_loadu_si256(src.data[topRowStart + x * 2].addr)
          bottom = mm256_loadu_si256(src.data[bottomRowStart + x * 2].addr)
          topShifted = mm256_srli_si256(top, 4)
          bottomShifted = mm256_srli_si256(bottom, 4)
          topEven = mm256_andnot_si256(oddMask, top)
          topOdd = mm256_srli_epi16(top, 8)
          bottomEven = mm256_andnot_si256(oddMask, bottom)
          bottomOdd = mm256_srli_epi16(bottom, 8)
          topShiftedEven = mm256_andnot_si256(oddMask, topShifted)
          topShiftedOdd = mm256_srli_epi16(topShifted, 8)
          bottomShiftedEven = mm256_andnot_si256(oddMask, bottomShifted)
          bottomShiftedOdd = mm256_srli_epi16(bottomShifted, 8)
          topAddedEven = mm256_add_epi16(topEven, topShiftedEven)
          bottomAddedEven = mm256_add_epi16(bottomEven, bottomShiftedEven)
          topAddedOdd = mm256_add_epi16(topOdd, topShiftedOdd)
          bottomAddedOdd = mm256_add_epi16(bottomOdd, bottomShiftedOdd)
          addedEven = mm256_add_epi16(topAddedEven, bottomAddedEven)
          addedOdd = mm256_add_epi16(topAddedOdd, bottomAddedOdd)
          addedEvenRounding = mm256_add_epi16(addedEven, vec2)
          addedOddRounding = mm256_add_epi16(addedOdd, vec2)
          addedEvenDiv4 = mm256_srli_epi16(addedEvenRounding, 2)
          addedOddDiv4 = mm256_srli_epi16(addedOddRounding, 2)
          merged = mm256_or_si256(addedEvenDiv4, mm256_slli_epi16(addedOddDiv4, 8))
          # Merged has the correct values for the next two pixels at
          # index 0, 2, 4, 6 so permute into position and store
          permuted = mm_256_permutevar8x32_epi32(merged, permuteControl)
        mm_storeu_si128(
          result.data[result.dataIndex(x, y)].addr,
          mm256_castsi256_si128(permuted)
        )
        x += 4

      for x in x ..< resultEvenWidth:
        let
          a = src.data[topRowStart + x * 2]
          b = src.data[topRowStart + x * 2 + 1]
          c = src.data[bottomRowStart + x * 2 + 1]
          d = src.data[bottomRowStart + x * 2]
          mixed = rgbx(
            ((a.r.uint32 + b.r + c.r + d.r + 2) div 4).uint8,
            ((a.g.uint32 + b.g + c.g + d.g + 2) div 4).uint8,
            ((a.b.uint32 + b.b + c.b + d.b + 2) div 4).uint8,
            ((a.a.uint32 + b.a + c.a + d.a + 2) div 4).uint8
          )
        result.data[result.dataIndex(x, y)] = mixed

      if srcWidthIsOdd:
        let rgbx = mix(
          src.data[src.dataIndex(src.width - 1, y * 2 + 0)],
          src.data[src.dataIndex(src.width - 1, y * 2 + 1)],
          0.5
        ) * 0.5
        result.data[result.dataIndex(result.width - 1, y)] = rgbx

    if srcHeightIsOdd:
      for x in 0 ..< resultEvenWidth:
        let rgbx = mix(
          src.data[src.dataIndex(x * 2 + 0, src.height - 1)],
          src.data[src.dataIndex(x * 2 + 1, src.height - 1)],
          0.5
        ) * 0.5
        result.data[result.dataIndex(x, result.height - 1)] = rgbx

      if srcWidthIsOdd:
        result.data[result.dataIndex(result.width - 1, result.height - 1)] =
          src.data[src.dataIndex(src.width - 1, src.height - 1)] * 0.25

    # Set src as this result for if we do another power
    src = result

template applyCoverage(rgbxVec: M256i, coverage: M128i): M256i =
  ## Unpack the first 8 coverage bytes.
  let
    unpacked0 = mm_shuffle_epi8(coverage, coverageShuffle)
    unpacked1 = mm_shuffle_epi8(mm_srli_si128(coverage, 4), coverageShuffle)
    unpacked =
      mm256_insertf128_si256(mm256_castsi128_si256(unpacked0), unpacked1, 1)

  var
    rgbxEven = mm256_slli_epi16(rgbxVec, 8)
    rgbxOdd = mm256_and_si256(rgbxVec, oddMask)
  rgbxEven = mm256_mulhi_epu16(rgbxEven, unpacked)
  rgbxOdd = mm256_mulhi_epu16(rgbxOdd, unpacked)
  rgbxEven = mm256_srli_epi16(mm256_mulhi_epu16(rgbxEven, div255), 7)
  rgbxOdd = mm256_srli_epi16(mm256_mulhi_epu16(rgbxOdd, div255), 7)

  mm256_or_si256(rgbxEven, mm256_slli_epi16(rgbxOdd, 8))

proc blendLineCoverageOverwriteAvx2*(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 31) != 0:
    let coverage = coverages[i]
    if coverage != 0:
      line[i] = rgbx * coverage
    inc i

  let
    rgbxVec = mm256_set1_epi32(cast[uint32](rgbx))
    vecZero = mm256_setzero_si256()
    vec255 = mm256_set1_epi8(255)
    oddMask = mm256_set1_epi16(0xff00)
    div255 = mm256_set1_epi16(0x8081)
    coverageShuffle = mm_set_epi8(
      3, -1, 3, -1, 2, -1, 2, -1, 1, -1, 1, -1, 0, -1, 0, -1
    )
  while i < len - 32:
    let
      coverage = mm256_loadu_si256(coverages[i].addr)
      eqZero = mm256_cmpeq_epi8(coverage, vecZero)
      eq255 = mm256_cmpeq_epi8(coverage, vec255)
    if mm256_movemask_epi8(eqZero) == cast[int32](0xffffffff):
      i += 32
    elif mm256_movemask_epi8(eq255) == cast[int32](0xffffffff):
      for _ in 0 ..< 4:
        mm256_store_si256(line[i].addr, rgbxVec)
        i += 8
    else:
      let
        coverageLo = mm256_castsi256_si128(coverage)
        coverageHi = mm256_extractf128_si256(coverage, 1)
        coverages = [
          coverageLo,
          mm_srli_si128(coverageLo, 8),
          coverageHi,
          mm_srli_si128(coverageHi, 8),
        ]
      for j in 0 ..< 4:
        mm256_store_si256(line[i].addr, rgbxVec.applyCoverage(coverages[j]))
        i += 8

  for i in i ..< len:
    let coverage = coverages[i]
    if coverage != 0:
      line[i] = rgbx * coverage

proc blendLineNormalAvx2*(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 31) != 0:
    line[i] = blendNormal(line[i], rgbx)
    inc i

  let
    source = mm256_set1_epi32(cast[uint32](rgbx))
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    oddMask = mm256_set1_epi16(cast[int16](0xff00))
    div255 = mm256_set1_epi16(cast[int16](0x8081))
    vecAlpha255 = mm256_set1_epi32(cast[int32]([0.uint8, 255, 0, 255]))
    shuffleControl = mm256_set_epi8(
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1,
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1
    )
  while i < len - 8:
    let backdrop = mm256_load_si256(line[i].addr)
    mm256_store_si256(line[i].addr, blendNormalSimd(backdrop, source))
    i += 8

  for i in i ..< len:
    line[i] = blendNormal(line[i], rgbx)

proc blendLineNormalAvx2*(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](a[i].addr) and 31) != 0:
    a[i] = blendNormal(a[i], b[i])
    inc i

  let
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    oddMask = mm256_set1_epi16(cast[int16](0xff00))
    div255 = mm256_set1_epi16(cast[int16](0x8081))
    vec255 = mm256_set1_epi8(255)
    vecAlpha255 = mm256_set1_epi32(cast[int32]([0.uint8, 255, 0, 255]))
    shuffleControl = mm256_set_epi8(
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1,
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1
    )
  while i < len - 8:
    let
      source = mm256_loadu_si256(b[i].addr)
      eq255 = mm256_cmpeq_epi8(source, vec255)
    if (mm256_movemask_epi8(eq255) and 0x88888888) == 0x88888888: # Opaque source
      mm256_store_si256(a[i].addr, source)
    else:
      let backdrop = mm256_load_si256(a[i].addr)
      mm256_store_si256(a[i].addr, blendNormalSimd(backdrop, source))
    i += 8

  for i in i ..< len:
    a[i] = blendNormal(a[i], b[i])

proc blendLineCoverageNormalAvx2*(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 31) != 0:
    let coverage = coverages[i]
    if coverage == 0:
      discard
    else:
      line[i] = blendNormal(line[i], rgbx * coverage)
    inc i

  let
    rgbxVec = mm256_set1_epi32(cast[uint32](rgbx))
    vecZero = mm256_setzero_si256()
    vec255 = mm256_set1_epi8(255)
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    oddMask = mm256_set1_epi16(cast[int16](0xff00))
    div255 = mm256_set1_epi16(cast[int16](0x8081))
    vecAlpha255 = mm256_set1_epi32(cast[int32]([0.uint8, 255, 0, 255]))
    coverageShuffle = mm_set_epi8(
      3, -1, 3, -1, 2, -1, 2, -1, 1, -1, 1, -1, 0, -1, 0, -1
    )
    shuffleControl = mm256_set_epi8(
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1,
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1
    )
  while i < len - 32:
    let
      coverage = mm256_loadu_si256(coverages[i].addr)
      eqZero = mm256_cmpeq_epi8(coverage, vecZero)
      eq255 = mm256_cmpeq_epi8(coverage, vec255)
    if mm256_movemask_epi8(eqZero) == cast[int32](0xffffffff):
      i += 32
    elif mm256_movemask_epi8(eq255) == cast[int32](0xffffffff) and rgbx.a == 255:
      for _ in 0 ..< 4:
        mm256_store_si256(line[i].addr, rgbxVec)
        i += 8
    else:
      let
        coverageLo = mm256_castsi256_si128(coverage)
        coverageHi = mm256_extractf128_si256(coverage, 1)
        coverages = [
          coverageLo,
          mm_srli_si128(coverageLo, 8),
          coverageHi,
          mm_srli_si128(coverageHi, 8),
        ]
      for j in 0 ..< 4:
        let
          backdrop = mm256_loadu_si256(line[i].addr)
          source = rgbxVec.applyCoverage(coverages[j])
        mm256_store_si256(line[i].addr, blendNormalSimd(backdrop, source))
        i += 8

  for i in i ..< len:
    let coverage = coverages[i]
    if coverage == 0:
      discard
    else:
      line[i] = blendNormal(line[i], rgbx * coverage)

proc blendLineMaskAvx2*(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 31) != 0:
    line[i] = blendMask(line[i], rgbx)
    inc i

  let
    source = mm256_set1_epi32(cast[uint32](rgbx))
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    oddMask = mm256_set1_epi16(cast[int16](0xff00))
    div255 = mm256_set1_epi16(cast[int16](0x8081))
    shuffleControl = mm256_set_epi8(
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1,
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1
    )
  while i < len - 8:
    let backdrop = mm256_load_si256(line[i].addr)
    mm256_store_si256(line[i].addr, blendMaskSimd(backdrop, source))
    i += 8

  for i in i ..< len:
    line[i] = blendMask(line[i], rgbx)

proc blendLineMaskAvx2*(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](a[i].addr) and 31) != 0:
    a[i] = blendMask(a[i], b[i])
    inc i

  let
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    oddMask = mm256_set1_epi16(cast[int16](0xff00))
    div255 = mm256_set1_epi16(cast[int16](0x8081))
    vec255 = mm256_set1_epi8(255)
    shuffleControl = mm256_set_epi8(
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1,
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1
    )
  while i < len - 8:
    let
      source = mm256_loadu_si256(b[i].addr)
      eq255 = mm256_cmpeq_epi8(source, vec255)
    if (mm256_movemask_epi8(eq255) and 0x88888888) == 0x88888888: # Opaque source
      discard
    else:
      let backdrop = mm256_load_si256(a[i].addr)
      mm256_store_si256(a[i].addr, blendMaskSimd(backdrop, source))
    i += 8

  for i in i ..< len:
    a[i] = blendMask(a[i], b[i])

proc blendLineCoverageMaskAvx2*(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 31) != 0:
    let coverage = coverages[i]
    if coverage == 0:
      line[i] = rgbx(0, 0, 0, 0)
    elif coverage == 255:
      discard
    else:
      line[i] = blendMask(line[i], rgbx * coverage)
    inc i

  let
    rgbxVec = mm256_set1_epi32(cast[uint32](rgbx))
    vecZero = mm256_setzero_si256()
    vec255 = mm256_set1_epi8(255)
    alphaMask = mm256_set1_epi32(cast[int32](0xff000000))
    oddMask = mm256_set1_epi16(cast[int16](0xff00))
    div255 = mm256_set1_epi16(cast[int16](0x8081))
    coverageShuffle = mm_set_epi8(
      3, -1, 3, -1, 2, -1, 2, -1, 1, -1, 1, -1, 0, -1, 0, -1
    )
    shuffleControl = mm256_set_epi8(
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1,
      15, -1, 15, -1, 11, -1, 11, -1, 7, -1, 7, -1, 3, -1, 3, -1
    )
  while i < len - 16:
    let
      coverage = mm256_loadu_si256(coverages[i].addr)
      eqZero = mm256_cmpeq_epi8(coverage, vecZero)
      eq255 = mm256_cmpeq_epi8(coverage, vec255)
    if mm256_movemask_epi8(eqZero) == cast[int32](0xffffffff):
      for _ in 0 ..< 4:
        mm256_store_si256(line[i].addr, vecZero)
        i += 8
    elif mm256_movemask_epi8(eq255) == cast[int32](0xffffffff) and rgbx.a == 255:
      i += 32
    else:
      let
        coverageLo = mm256_castsi256_si128(coverage)
        coverageHi = mm256_extractf128_si256(coverage, 1)
        coverages = [
          coverageLo,
          mm_srli_si128(coverageLo, 8),
          coverageHi,
          mm_srli_si128(coverageHi, 8),
        ]
      for j in 0 ..< 4:
        let
          backdrop = mm256_loadu_si256(line[i].addr)
          source = rgbxVec.applyCoverage(coverages[j])
        mm256_store_si256(line[i].addr, blendMaskSimd(backdrop, source))
        i += 8

  for i in i ..< len:
    let coverage = coverages[i]
    if coverage == 0:
      line[i] = rgbx(0, 0, 0, 0)
    elif coverage == 255:
      discard
    else:
      line[i] = blendMask(line[i], rgbx * coverage)

when defined(release):
  {.pop.}
