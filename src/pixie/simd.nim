import chroma

when defined(amd64):
  import nimsimd/runtimecheck, nimsimd/sse2, runtimechecked/avx, runtimechecked/avx2

  let
    cpuHasAvx* = checkInstructionSets({AVX})
    cpuHasAvx2* = checkInstructionSets({AVX, AVX2})

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

  proc fillUnsafeSimd*(
    data: ptr UncheckedArray[ColorRGBX],
    len: int,
    rgbx: ColorRGBX
  ) =
    if cpuHasAvx and len >= 64:
      fillUnsafeAvx(data, len, rgbx)
    else:
      var i: int
      while i < len and (cast[uint](data[i].addr) and 15) != 0: # Align to 16 bytes
        data[i] = rgbx
        inc i

      let
        colorVec = mm_set1_epi32(cast[int32](rgbx))
        iterations = (len - i) div 8
      for _ in 0 ..< iterations:
        mm_store_si128(data[i].addr, colorVec)
        mm_store_si128(data[i + 4].addr, colorVec)
        i += 8

      for i in i ..< len:
        data[i] = rgbx

  proc isOneColorSimd*(data: ptr UncheckedArray[ColorRGBX], len: int): bool =
    if cpuHasAvx2:
      return isOneColorAvx2(data, len)

    result = true

    let color = data[0]

    var i: int
    while i < len and (cast[uint](data[i].addr) and 15) != 0: # Align to 16 bytes
      if data[i] != color:
        return false
      inc i

    let
      colorVec = mm_set1_epi32(cast[int32](color))
      iterations = (len - i) div 16
    for _ in 0 ..< iterations:
      let
        values0 = mm_load_si128(data[i].addr)
        values1 = mm_load_si128(data[i + 4].addr)
        values2 = mm_load_si128(data[i + 8].addr)
        values3 = mm_load_si128(data[i + 12].addr)
        eq0 = mm_cmpeq_epi8(values0, colorVec)
        eq1 = mm_cmpeq_epi8(values1, colorVec)
        eq2 = mm_cmpeq_epi8(values2, colorVec)
        eq3 = mm_cmpeq_epi8(values3, colorVec)
        eq0123 = mm_and_si128(mm_and_si128(eq0, eq1), mm_and_si128(eq2, eq3))
      if mm_movemask_epi8(eq0123) != 0xffff:
        return false
      i += 16

    for i in i ..< len:
      if data[i] != color:
        return false

  proc isTransparentSimd*(data: ptr UncheckedArray[ColorRGBX], len: int): bool =
    if cpuHasAvx2:
      return isTransparentAvx2(data, len)

    var i: int
    while i < len and (cast[uint](data[i].addr) and 15) != 0: # Align to 16 bytes
      if data[i].a != 0:
        return false
      inc i

    result = true

    let
      vecZero = mm_setzero_si128()
      iterations = (len - i) div 16
    for _ in 0 ..< iterations:
      let
        values0 = mm_load_si128(data[i].addr)
        values1 = mm_load_si128(data[i + 4].addr)
        values2 = mm_load_si128(data[i + 8].addr)
        values3 = mm_load_si128(data[i + 12].addr)
        values01 = mm_or_si128(values0, values1)
        values23 = mm_or_si128(values2, values3)
        values0123 = mm_or_si128(values01, values23)
      if mm_movemask_epi8(mm_cmpeq_epi8(values0123, vecZero)) != 0xffff:
        return false
      i += 16

    for i in i ..< len:
      if data[i].a != 0:
        return false

  proc isOpaqueSimd*(data: ptr UncheckedArray[ColorRGBX], len: int): bool =
    if cpuHasAvx2:
      return isOpaqueAvx2(data, len)

    result = true

    var i: int
    while i < len and (cast[uint](data[i].addr) and 15) != 0: # Align to 16 bytes
      if data[i].a != 255:
        return false
      inc i

    let
      vec255 = mm_set1_epi8(255)
      iterations = (len - i) div 16
    for _ in 0 ..< iterations:
      let
        values0 = mm_load_si128(data[i].addr)
        values1 = mm_load_si128(data[i + 4].addr)
        values2 = mm_load_si128(data[i + 8].addr)
        values3 = mm_load_si128(data[i + 12].addr)
        values01 = mm_and_si128(values0, values1)
        values23 = mm_and_si128(values2, values3)
        values0123 = mm_and_si128(values01, values23)
        eq = mm_cmpeq_epi8(values0123, vec255)
      if (mm_movemask_epi8(eq) and 0x00008888) != 0x00008888:
        return false
      i += 16

    for i in i ..< len:
      if data[i].a != 255:
        return false

  proc toPremultipliedAlphaSimd*(data: ptr UncheckedArray[uint32], len: int) =
    var i: int
    if cpuHasAvx2:
      i = toPremultipliedAlphaAvx2(data, len)
    else:
      let
        alphaMask = mm_set1_epi32(cast[int32](0xff000000))
        oddMask = mm_set1_epi16(cast[int16](0xff00))
        div255 = mm_set1_epi16(cast[int16](0x8081))
      for _ in 0 ..< len div 4:
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
          colorsEven = mm_srli_epi16(mm_mulhi_epu16(colorsEven, div255), 7)
          colorsOdd = mm_srli_epi16(mm_mulhi_epu16(colorsOdd, div255), 7)
          mm_storeu_si128(
            data[i].addr,
            mm_or_si128(colorsEven, mm_slli_epi16(colorsOdd, 8))
          )
        i += 4

    for i in i ..< len:
      var c: ColorRGBX
      copyMem(c.addr, data[i].addr, 4)
      c.r = ((c.r.uint32 * c.a) div 255).uint8
      c.g = ((c.g.uint32 * c.a) div 255).uint8
      c.b = ((c.b.uint32 * c.a) div 255).uint8
      copyMem(data[i].addr, c.addr, 4)

  proc newImageFromMaskSimd*(
    dst: ptr UncheckedArray[ColorRGBX],
    src: ptr UncheckedArray[uint8],
    len: int
  ) =
    var i: int
    for _ in 0 ..< len div 16:
      var alphas = mm_loadu_si128(src[i].addr)
      for j in 0 ..< 4:
        var unpacked = unpackAlphaValues(alphas)
        unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 8))
        unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 16))
        mm_storeu_si128(dst[i + j * 4].addr, unpacked)
        alphas = mm_srli_si128(alphas, 4)
      i += 16

    for i in i ..< len:
      let v = src[i]
      dst[i] = rgbx(v, v, v, v)

  proc newMaskFromImageSimd*(
    dst: ptr UncheckedArray[uint8],
    src: ptr UncheckedArray[ColorRGBX],
    len: int
  ) =
    var i: int
    for _ in 0 ..< len div 16:
      let
        a = mm_loadu_si128(src[i + 0].addr)
        b = mm_loadu_si128(src[i + 4].addr)
        c = mm_loadu_si128(src[i + 8].addr)
        d = mm_loadu_si128(src[i + 12].addr)
      mm_storeu_si128(
        dst[i].addr,
        pack4xAlphaValues(a, b, c, d)
      )
      i += 16

    for i in i ..< len:
      dst[i] = src[i].a

  proc invertImageSimd*(data: ptr UncheckedArray[ColorRGBX], len: int) =
    var i: int
    let vec255 = mm_set1_epi8(cast[int8](255))
    for _ in 0 ..< len div 16:
      let
        a = mm_loadu_si128(data[i + 0].addr)
        b = mm_loadu_si128(data[i + 4].addr)
        c = mm_loadu_si128(data[i + 8].addr)
        d = mm_loadu_si128(data[i + 12].addr)
      mm_storeu_si128(data[i + 0].addr, mm_sub_epi8(vec255, a))
      mm_storeu_si128(data[i + 4].addr, mm_sub_epi8(vec255, b))
      mm_storeu_si128(data[i + 8].addr, mm_sub_epi8(vec255, c))
      mm_storeu_si128(data[i + 12].addr, mm_sub_epi8(vec255, d))
      i += 16

    for i in i ..< len:
      var rgbx = data[i]
      rgbx.r = 255 - rgbx.r
      rgbx.g = 255 - rgbx.g
      rgbx.b = 255 - rgbx.b
      rgbx.a = 255 - rgbx.a
      data[i] = rgbx

    toPremultipliedAlphaSimd(cast[ptr UncheckedArray[uint32]](data), len)

  proc invertMaskSimd*(data: ptr UncheckedArray[uint8], len: int) =
    var i: int
    let vec255 = mm_set1_epi8(255)
    for _ in 0 ..< len div 16:
      var values = mm_loadu_si128(data[i].addr)
      values = mm_sub_epi8(vec255, values)
      mm_storeu_si128(data[i].addr, values)
      i += 16

    for j in i ..< len:
      data[j] = 255 - data[j]
