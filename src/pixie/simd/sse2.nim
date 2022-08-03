import chroma, nimsimd/hassimd, nimsimd/sse2, pixie/blends, pixie/common, vmath

when defined(release):
  {.push checks: off.}

proc applyOpacity*(color: M128, opacity: float32): ColorRGBX {.inline.} =
  let opacityVec = mm_set1_ps(opacity)
  var finalColor = mm_cvtps_epi32(mm_mul_ps(color, opacityVec))
  finalColor = mm_packus_epi16(finalColor, mm_setzero_si128())
  finalColor = mm_packus_epi16(finalColor, mm_setzero_si128())
  cast[ColorRGBX](mm_cvtsi128_si32(finalColor))

template blendNormalSimd(backdrop, source: M128i): M128i =
  var
    sourceAlpha = mm_and_si128(source, alphaMask)
    backdropEven = mm_slli_epi16(backdrop, 8)
    backdropOdd = mm_and_si128(backdrop, oddMask)

  sourceAlpha = mm_or_si128(sourceAlpha, mm_srli_epi32(sourceAlpha, 16))

  let multiplier = mm_sub_epi32(vecAlpha255, sourceAlpha)

  backdropEven = mm_mulhi_epu16(backdropEven, multiplier)
  backdropOdd = mm_mulhi_epu16(backdropOdd, multiplier)
  backdropEven = mm_srli_epi16(mm_mulhi_epu16(backdropEven, div255), 7)
  backdropOdd = mm_srli_epi16(mm_mulhi_epu16(backdropOdd, div255), 7)

  mm_add_epi8(
    source,
    mm_or_si128(backdropEven, mm_slli_epi16(backdropOdd, 8))
  )

template blendMaskSimd(backdrop, source: M128i): M128i =
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

  # Not worth aligning

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
    var rgbx = data[i]
    if rgbx.a != 255:
      rgbx.r = ((rgbx.r.uint32 * rgbx.a + 127) div 255).uint8
      rgbx.g = ((rgbx.g.uint32 * rgbx.a + 127) div 255).uint8
      rgbx.b = ((rgbx.b.uint32 * rgbx.a + 127) div 255).uint8
      data[i] = rgbx

proc invertSse2*(image: Image) {.simd.} =
  var
    i: int
    p = cast[uint](image.data[0].addr)
  # Align to 16 bytes
  while i < image.data.len and (p and 15) != 0:
    var rgbx = image.data[i]
    rgbx.r = 255 - rgbx.r
    rgbx.g = 255 - rgbx.g
    rgbx.b = 255 - rgbx.b
    rgbx.a = 255 - rgbx.a
    image.data[i] = rgbx
    inc i
    p += 4

  let
    vec255 = mm_set1_epi8(255)
    iterations = (image.data.len - i) div 16
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
  i += 16 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = 255 - rgbx.r
    rgbx.g = 255 - rgbx.g
    rgbx.b = 255 - rgbx.b
    rgbx.a = 255 - rgbx.a
    image.data[i] = rgbx

  toPremultipliedAlphaSse2(image.data)

proc applyOpacitySse2*(image: Image, opacity: float32) {.simd.} =
  let opacity = round(255 * opacity).uint16
  if opacity == 255:
    return

  if opacity == 0:
    fillUnsafeSse2(image.data, rgbx(0, 0, 0, 0), 0, image.data.len)
    return

  var
    i: int
    p = cast[uint](image.data[0].addr)
  # Align to 16 bytes
  while i < image.data.len and (p and 15) != 0:
    var rgbx = image.data[i]
    rgbx.r = ((rgbx.r * opacity) div 255).uint8
    rgbx.g = ((rgbx.g * opacity) div 255).uint8
    rgbx.b = ((rgbx.b * opacity) div 255).uint8
    rgbx.a = ((rgbx.a * opacity) div 255).uint8
    image.data[i] = rgbx
    inc i
    p += 4

  let
    oddMask = mm_set1_epi16(0xff00)
    div255 = mm_set1_epi16(0x8081)
    zeroVec = mm_setzero_si128()
    opacityVec = mm_slli_epi16(mm_set1_epi16(opacity), 8)
    iterations = (image.data.len - i) div 4
  for _ in 0 ..< iterations:
    let values = mm_loadu_si128(cast[pointer](p))
    if mm_movemask_epi8(mm_cmpeq_epi16(values, zeroVec)) != 0xffff:
      var
        valuesEven = mm_slli_epi16(values, 8)
        valuesOdd = mm_and_si128(values, oddMask)
      valuesEven = mm_mulhi_epu16(valuesEven, opacityVec)
      valuesOdd = mm_mulhi_epu16(valuesOdd, opacityVec)
      valuesEven = mm_srli_epi16(mm_mulhi_epu16(valuesEven, div255), 7)
      valuesOdd = mm_srli_epi16(mm_mulhi_epu16(valuesOdd, div255), 7)
      mm_store_si128(
        cast[pointer](p),
        mm_or_si128(valuesEven, mm_slli_epi16(valuesOdd, 8))
      )
    p += 16
  i += 4 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = ((rgbx.r * opacity) div 255).uint8
    rgbx.g = ((rgbx.g * opacity) div 255).uint8
    rgbx.b = ((rgbx.b * opacity) div 255).uint8
    rgbx.a = ((rgbx.a * opacity) div 255).uint8
    image.data[i] = rgbx

proc ceilSse2*(image: Image) {.simd.} =
  var
    i: int
    p = cast[uint](image.data[0].addr)
  # Align to 16 bytes
  while i < image.data.len and (p and 15) != 0:
    var rgbx = image.data[i]
    rgbx.r = if rgbx.r == 0: 0 else: 255
    rgbx.g = if rgbx.g == 0: 0 else: 255
    rgbx.b = if rgbx.b == 0: 0 else: 255
    rgbx.a = if rgbx.a == 0: 0 else: 255
    image.data[i] = rgbx
    inc i
    p += 4

  let
    vecZero = mm_setzero_si128()
    vec255 = mm_set1_epi8(255)
    iterations = (image.data.len - i) div 8
  for _ in 0 ..< iterations:
    var
      values0 = mm_loadu_si128(cast[pointer](p))
      values1 = mm_loadu_si128(cast[pointer](p + 16))
    values0 = mm_cmpeq_epi8(values0, vecZero)
    values1 = mm_cmpeq_epi8(values1, vecZero)
    values0 = mm_andnot_si128(values0, vec255)
    values1 = mm_andnot_si128(values1, vec255)
    mm_store_si128(cast[pointer](p), values0)
    mm_store_si128(cast[pointer](p + 16), values1)
    p += 32
  i += 8 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = if rgbx.r == 0: 0 else: 255
    rgbx.g = if rgbx.g == 0: 0 else: 255
    rgbx.b = if rgbx.b == 0: 0 else: 255
    rgbx.a = if rgbx.a == 0: 0 else: 255
    image.data[i] = rgbx

proc minifyBy2Sse2*(image: Image, power = 1): Image {.simd.} =
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
      oddMask = mm_set1_epi16(0xff00)
      loMask = mm_set_epi32(0, 0, uint32.high, uint32.high)
      hiMask = mm_set_epi32(uint32.high, uint32.high, 0, 0)
      vec2 = mm_set1_epi16(2)
    for y in 0 ..< resultEvenHeight:
      let
        topRowStart = src.dataIndex(0, y * 2)
        bottomRowStart = src.dataIndex(0, y * 2 + 1)

      template loadEven(src: Image, idx: int): M128i =
        var
          a = mm_loadu_si128(src.data[idx].addr)
          b = mm_loadu_si128(src.data[idx + 4].addr)
        a = mm_shuffle_epi32(a, MM_SHUFFLE(3, 3, 2, 0))
        b = mm_shuffle_epi32(b, MM_SHUFFLE(2, 0, 3, 3))
        a = mm_and_si128(a, loMask)
        b = mm_and_si128(b, hiMask)
        mm_or_si128(a, b)

      var x: int
      while x <= resultEvenWidth - 9:
        let
          top = loadEven(src, topRowStart + x * 2)
          bottom = loadEven(src, bottomRowStart + x * 2)
          topShifted = loadEven(src, topRowStart + x * 2 + 1)
          bottomShifted = loadEven(src, bottomRowStart + x * 2 + 1)
          topEven = mm_andnot_si128(oddMask, top)
          topOdd = mm_srli_epi16(top, 8)
          bottomEven = mm_andnot_si128(oddMask, bottom)
          bottomOdd = mm_srli_epi16(bottom, 8)
          topShiftedEven = mm_andnot_si128(oddMask, topShifted)
          topShiftedOdd = mm_srli_epi16(topShifted, 8)
          bottomShiftedEven = mm_andnot_si128(oddMask, bottomShifted)
          bottomShiftedOdd = mm_srli_epi16(bottomShifted, 8)
          topAddedEven = mm_add_epi16(topEven, topShiftedEven)
          bottomAddedEven = mm_add_epi16(bottomEven, bottomShiftedEven)
          topAddedOdd = mm_add_epi16(topOdd, topShiftedOdd)
          bottomAddedOdd = mm_add_epi16(bottomOdd, bottomShiftedOdd)
          addedEven = mm_add_epi16(topAddedEven, bottomAddedEven)
          addedOdd = mm_add_epi16(topAddedOdd, bottomAddedOdd)
          addedEvenRounding = mm_add_epi16(addedEven, vec2)
          addedOddRounding = mm_add_epi16(addedOdd, vec2)
          addedEvenDiv4 = mm_srli_epi16(addedEvenRounding, 2)
          addedOddDiv4 = mm_srli_epi16(addedOddRounding, 2)
          merged = mm_or_si128(addedEvenDiv4, mm_slli_epi16(addedOddDiv4, 8))
        mm_storeu_si128(result.data[result.dataIndex(x, y)].addr, merged)
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

proc magnifyBy2Sse2*(image: Image, power = 1): Image {.simd.} =
  ## Scales image up by 2 ^ power.
  if power < 0:
    raise newException(PixieError, "Cannot magnifyBy2 with negative power")

  let scale = 2 ^ power
  result = newImage(image.width * scale, image.height * scale)

  for y in 0 ..< image.height:
    # Write one row of pixels duplicated by scale
    let
      sourceRowStart = image.dataIndex(0, y)
      resultRowStart = result.dataIndex(0, y * scale)
    var x: int
    if scale == 2:
      while x <= image.width - 4:
        let values = mm_loadu_si128(image.data[sourceRowStart + x].addr)
        mm_storeu_si128(
          result.data[resultRowStart + x * scale].addr,
          mm_unpacklo_epi32(values, values)
        )
        mm_storeu_si128(
          result.data[resultRowStart + x * scale + 4].addr,
          mm_unpackhi_epi32(values, values)
        )
        x += 4
    for x in x ..< image.width:
      let
        rgbx = image.data[sourceRowStart + x]
        resultIdx = resultRowStart + x * scale
      for i in 0 ..< scale:
        result.data[resultIdx + i] = rgbx
    # Copy that row of pixels into (scale - 1) more rows
    for i in 1 ..< scale:
      copyMem(
        result.data[resultRowStart + result.width * i].addr,
        result.data[resultRowStart].addr,
        result.width * 4
      )

template applyCoverage(rgbxVec, coverage: M128i): M128i =
  ## Unpack the first 4 coverage bytes.
  var unpacked = mm_unpacklo_epi8(mm_setzero_si128(), coverage)
  unpacked = mm_unpacklo_epi8(mm_setzero_si128(), unpacked)
  unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 16))

  var
    rgbxEven = mm_slli_epi16(rgbxVec, 8)
    rgbxOdd = mm_and_si128(rgbxVec, oddMask)
  rgbxEven = mm_mulhi_epu16(rgbxEven, unpacked)
  rgbxOdd = mm_mulhi_epu16(rgbxOdd, unpacked)
  rgbxEven = mm_srli_epi16(mm_mulhi_epu16(rgbxEven, div255), 7)
  rgbxOdd = mm_srli_epi16(mm_mulhi_epu16(rgbxOdd, div255), 7)

  mm_or_si128(rgbxEven, mm_slli_epi16(rgbxOdd, 8))

proc blendLineCoverageOverwriteSse2*(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 15) != 0:
    let coverage = coverages[i]
    if coverage != 0:
      line[i] = rgbx * coverage
    inc i

  let
    rgbxVec = mm_set1_epi32(cast[uint32](rgbx))
    vecZero = mm_setzero_si128()
    vec255 = mm_set1_epi8(255)
    oddMask = mm_set1_epi16(0xff00)
    div255 = mm_set1_epi16(0x8081)
  while i < len - 16:
    let
      coverage = mm_loadu_si128(coverages[i].addr)
      eqZero = mm_cmpeq_epi8(coverage, vecZero)
      eq255 = mm_cmpeq_epi8(coverage, vec255)
    if mm_movemask_epi8(eqZero) == 0xffff:
      i += 16
    elif mm_movemask_epi8(eq255) == 0xffff:
      for _ in 0 ..< 4:
        mm_store_si128(line[i].addr, rgbxVec)
        i += 4
    else:
      var coverage = coverage
      for _ in 0 ..< 4:
        mm_store_si128(line[i].addr, rgbxVec.applyCoverage(coverage))
        coverage = mm_srli_si128(coverage, 4)
        i += 4

  for i in i ..< len:
    let coverage = coverages[i]
    if coverage != 0:
      line[i] = rgbx * coverage

proc blendLineNormalSse2*(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 15) != 0:
    line[i] = blendNormal(line[i], rgbx)
    inc i

  let
    source = mm_set1_epi32(cast[uint32](rgbx))
    alphaMask = mm_set1_epi32(cast[int32](0xff000000))
    oddMask = mm_set1_epi16(cast[int16](0xff00))
    div255 = mm_set1_epi16(cast[int16](0x8081))
    vecAlpha255 = mm_set1_epi32(cast[int32]([0.uint8, 255, 0, 255]))
  while i < len - 4:
    let backdrop = mm_load_si128(line[i].addr)
    mm_store_si128(line[i].addr, blendNormalSimd(backdrop, source))
    i += 4

  for i in i ..< len:
    line[i] = blendNormal(line[i], rgbx)

proc blendLineNormalSse2*(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](a[i].addr) and 15) != 0:
    a[i] = blendNormal(a[i], b[i])
    inc i

  let
    alphaMask = mm_set1_epi32(cast[int32](0xff000000))
    oddMask = mm_set1_epi16(cast[int16](0xff00))
    div255 = mm_set1_epi16(cast[int16](0x8081))
    vec255 = mm_set1_epi8(255)
    vecAlpha255 = mm_set1_epi32(cast[int32]([0.uint8, 255, 0, 255]))
  while i < len - 4:
    let
      source = mm_loadu_si128(b[i].addr)
      eq255 = mm_cmpeq_epi8(source, vec255)
    if (mm_movemask_epi8(eq255) and 0x00008888) == 0x00008888: # Opaque source
      mm_store_si128(a[i].addr, source)
    else:
      let backdrop = mm_load_si128(a[i].addr)
      mm_store_si128(a[i].addr, blendNormalSimd(backdrop, source))
    i += 4

  for i in i ..< len:
    a[i] = blendNormal(a[i], b[i])

proc blendLineCoverageNormalSse2*(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 15) != 0:
    let coverage = coverages[i]
    if coverage == 0:
      discard
    else:
      line[i] = blendNormal(line[i], rgbx * coverage)
    inc i

  let
    rgbxVec = mm_set1_epi32(cast[uint32](rgbx))
    vecZero = mm_setzero_si128()
    vec255 = mm_set1_epi8(255)
    alphaMask = mm_set1_epi32(cast[int32](0xff000000))
    oddMask = mm_set1_epi16(cast[int16](0xff00))
    div255 = mm_set1_epi16(cast[int16](0x8081))
    vecAlpha255 = mm_set1_epi32(cast[int32]([0.uint8, 255, 0, 255]))
  while i < len - 16:
    let
      coverage = mm_loadu_si128(coverages[i].addr)
      eqZero = mm_cmpeq_epi8(coverage, vecZero)
      eq255 = mm_cmpeq_epi8(coverage, vec255)
    if mm_movemask_epi8(eqZero) == 0xffff:
      i += 16
    elif mm_movemask_epi8(eq255) == 0xffff and rgbx.a == 255:
      for _ in 0 ..< 4:
        mm_store_si128(line[i].addr, rgbxVec)
        i += 4
    else:
      var coverage = coverage
      for _ in 0 ..< 4:
        let
          backdrop = mm_loadu_si128(line[i].addr)
          source = rgbxVec.applyCoverage(coverage)
        mm_store_si128(line[i].addr, blendNormalSimd(backdrop, source))
        coverage = mm_srli_si128(coverage, 4)
        i += 4

  for i in i ..< len:
    let coverage = coverages[i]
    if coverage == 0:
      discard
    else:
      line[i] = blendNormal(line[i], rgbx * coverage)

proc blendLineMaskSse2*(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 15) != 0:
    line[i] = blendMask(line[i], rgbx)
    inc i

  let
    source = mm_set1_epi32(cast[uint32](rgbx))
    alphaMask = mm_set1_epi32(cast[int32](0xff000000))
    oddMask = mm_set1_epi16(cast[int16](0xff00))
    div255 = mm_set1_epi16(cast[int16](0x8081))
  while i < len - 4:
    let backdrop = mm_load_si128(line[i].addr)
    mm_store_si128(line[i].addr, blendMaskSimd(backdrop, source))
    i += 4

  for i in i ..< len:
    line[i] = blendMask(line[i], rgbx)

proc blendLineMaskSse2*(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](a[i].addr) and 15) != 0:
    a[i] = blendMask(a[i], b[i])
    inc i

  let
    alphaMask = mm_set1_epi32(cast[int32](0xff000000))
    oddMask = mm_set1_epi16(cast[int16](0xff00))
    div255 = mm_set1_epi16(cast[int16](0x8081))
    vec255 = mm_set1_epi8(255)
  while i < len - 4:
    let
      source = mm_loadu_si128(b[i].addr)
      eq255 = mm_cmpeq_epi8(source, vec255)
    if (mm_movemask_epi8(eq255) and 0x00008888) == 0x00008888: # Opaque source
      discard
    else:
      let backdrop = mm_load_si128(a[i].addr)
      mm_store_si128(a[i].addr, blendMaskSimd(backdrop, source))
    i += 4

  for i in i ..< len:
    a[i] = blendMask(a[i], b[i])

proc blendLineCoverageMaskSse2*(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 15) != 0:
    let coverage = coverages[i]
    if coverage == 0:
      line[i] = rgbx(0, 0, 0, 0)
    elif coverage == 255:
      discard
    else:
      line[i] = blendMask(line[i], rgbx * coverage)
    inc i

  let
    rgbxVec = mm_set1_epi32(cast[uint32](rgbx))
    vecZero = mm_setzero_si128()
    vec255 = mm_set1_epi8(255)
    alphaMask = mm_set1_epi32(cast[int32](0xff000000))
    oddMask = mm_set1_epi16(cast[int16](0xff00))
    div255 = mm_set1_epi16(cast[int16](0x8081))
  while i < len - 16:
    let
      coverage = mm_loadu_si128(coverages[i].addr)
      eqZero = mm_cmpeq_epi8(coverage, vecZero)
      eq255 = mm_cmpeq_epi8(coverage, vec255)
    if mm_movemask_epi8(eqZero) == 0xffff:
      for _ in 0 ..< 4:
        mm_store_si128(line[i].addr, vecZero)
        i += 4
    elif mm_movemask_epi8(eq255) == 0xffff and rgbx.a == 255:
      i += 16
    else:
      var coverage = coverage
      for _ in 0 ..< 4:
        let
          backdrop = mm_loadu_si128(line[i].addr)
          source = rgbxVec.applyCoverage(coverage)
        mm_store_si128(line[i].addr, blendMaskSimd(backdrop, source))
        coverage = mm_srli_si128(coverage, 4)
        i += 4

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
