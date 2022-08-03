import chroma, nimsimd/hassimd, nimsimd/neon, pixie/blends, pixie/common, vmath

when defined(release):
  {.push checks: off.}

template multiplyDiv255(c, a: uint8x8): uint8x8 =
  let ca = vmull_u8(c, a)
  vraddhn_u16(ca, vrshrq_n_u16(ca, 8))

template multiplyDiv255(c, a: uint8x16): uint8x16 =
  vcombine_u8(
    multiplyDiv255(vget_low_u8(c), vget_low_u8(a)),
    multiplyDiv255(vget_high_u8(c), vget_high_u8(a))
  )

template blendNormalSimd(backdrop, source: uint8x16x4): uint8x16x4 =
  let multiplier = vsubq_u8(vec255, source.val[3])

  var blended: uint8x16x4
  blended.val[0] = multiplyDiv255(backdrop.val[0], multiplier)
  blended.val[1] = multiplyDiv255(backdrop.val[1], multiplier)
  blended.val[2] = multiplyDiv255(backdrop.val[2], multiplier)
  blended.val[3] = multiplyDiv255(backdrop.val[3], multiplier)
  blended.val[0] = vaddq_u8(blended.val[0], source.val[0])
  blended.val[1] = vaddq_u8(blended.val[1], source.val[1])
  blended.val[2] = vaddq_u8(blended.val[2], source.val[2])
  blended.val[3] = vaddq_u8(blended.val[3], source.val[3])
  blended

proc fillUnsafeNeon*(
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
    colors = vmovq_n_u32(cast[uint32](rgbx))
    x4 = vld4q_dup_u32(colors.unsafeAddr)
    iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    vst1q_u32_x4(data[i].addr, x4)
    i += 16

  for i in i ..< start + len:
    data[i] = rgbx

proc isOneColorNeon*(image: Image): bool {.simd.} =
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
    colorVecs = vld4q_dup_u8(color.unsafeAddr)
    iterations = (image.data.len - i) div 16
  for _ in 0 ..< iterations:
    let
      deinterleved = vld4q_u8(image.data[i].addr)
      rEq = vceqq_u8(deinterleved.val[0], colorVecs.val[0])
      gEq = vceqq_u8(deinterleved.val[1], colorVecs.val[1])
      bEq = vceqq_u8(deinterleved.val[2], colorVecs.val[2])
      aEq = vceqq_u8(deinterleved.val[3], colorVecs.val[3])
      rgEq = vandq_u8(rEq, gEq)
      baEq = vandq_u8(bEq, aEq)
      rgbaEq = vandq_u8(rgEq, baEq)
      mask = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(rgbaEq), vget_high_u8(rgbaEq)
      )), 0)
    if mask != uint64.high:
      return false
    i += 16

  for i in i ..< image.data.len:
    if image.data[i] != color:
      return false

proc isTransparentNeon*(image: Image): bool {.simd.} =
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
    vecZero = vmovq_n_u8(0)
    iterations = (image.data.len - i) div 16
  for _ in 0 ..< iterations:
    let
      alphas = vld4q_u8(image.data[i].addr).val[3]
      eq = vceqq_u8(alphas, vecZero)
      mask = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eq), vget_high_u8(eq)
      )), 0)
    if mask != uint64.high:
      return false
    i += 16

  for i in i ..< image.data.len:
    if image.data[i].a != 0:
      return false

proc isOpaqueNeon*(data: var seq[ColorRGBX], start, len: int): bool {.simd.} =
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
    vec255 = vmovq_n_u8(255)
    iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    let
      alphas = vld4q_u8(data[i].addr).val[3]
      eq = vceqq_u8(alphas, vec255)
      mask = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eq), vget_high_u8(eq)
      )), 0)
    if mask != uint64.high:
      return false
    i += 16

  for i in i ..< start + len:
    if data[i].a != 255:
      return false

proc toPremultipliedAlphaNeon*(data: var seq[ColorRGBA | ColorRGBX]) {.simd.} =
  var
    i: int
    p = cast[uint](data[0].addr)
  # Align to 16 bytes
  while i < data.len and (p and 15) != 0:
    var c = data[i]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a + 127) div 255).uint8
      c.g = ((c.g.uint32 * c.a + 127) div 255).uint8
      c.b = ((c.b.uint32 * c.a + 127) div 255).uint8
      data[i] = c
    inc i
    p += 4

  let iterations = (data.len - i) div 16
  for _ in 0 ..< iterations:
    var channels = vld4q_u8(cast[pointer](p))
    channels.val[0] = multiplyDiv255(channels.val[0], channels.val[3])
    channels.val[1] = multiplyDiv255(channels.val[1], channels.val[3])
    channels.val[2] = multiplyDiv255(channels.val[2], channels.val[3])
    vst4q_u8(cast[pointer](p), channels)
    p += 64
  i += 16 * iterations

  for i in i ..< data.len:
    var c = data[i]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a + 127) div 255).uint8
      c.g = ((c.g.uint32 * c.a + 127) div 255).uint8
      c.b = ((c.b.uint32 * c.a + 127) div 255).uint8
      data[i] = c

proc invertNeon*(image: Image) {.simd.} =
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
    vec255 = vmovq_n_u8(255)
    iterations = image.data.len div 16
  for _ in 0 ..< iterations:
    var channels = vld4q_u8(cast[pointer](p))
    channels.val[0] = vsubq_u8(vec255, channels.val[0])
    channels.val[1] = vsubq_u8(vec255, channels.val[1])
    channels.val[2] = vsubq_u8(vec255, channels.val[2])
    channels.val[3] = vsubq_u8(vec255, channels.val[3])
    vst4q_u8(cast[pointer](p), channels)
    p += 64
  i += 16 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = 255 - rgbx.r
    rgbx.g = 255 - rgbx.g
    rgbx.b = 255 - rgbx.b
    rgbx.a = 255 - rgbx.a
    image.data[i] = rgbx

  toPremultipliedAlphaNeon(image.data)

proc applyOpacityNeon*(image: Image, opacity: float32) {.simd.} =
  let opacity = round(255 * opacity).uint8
  if opacity == 255:
    return

  if opacity == 0:
    fillUnsafeNeon(image.data, rgbx(0, 0, 0, 0), 0, image.data.len)
    return

  var
    i: int
    p = cast[uint](image.data[0].addr)

  let
    opacityVec = vmov_n_u8(opacity)
    iterations = image.data.len div 8
  for _ in 0 ..< iterations:
    var channels = vld4_u8(cast[pointer](p))
    channels.val[0] = multiplyDiv255(channels.val[0], opacityVec)
    channels.val[1] = multiplyDiv255(channels.val[1], opacityVec)
    channels.val[2] = multiplyDiv255(channels.val[2], opacityVec)
    channels.val[3] = multiplyDiv255(channels.val[3], opacityVec)
    vst4_u8(cast[pointer](p), channels)
    p += 32
  i += 8 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = ((rgbx.r * opacity) div 255).uint8
    rgbx.g = ((rgbx.g * opacity) div 255).uint8
    rgbx.b = ((rgbx.b * opacity) div 255).uint8
    rgbx.a = ((rgbx.a * opacity) div 255).uint8
    image.data[i] = rgbx

proc ceilNeon*(image: Image) {.simd.} =
  var
    i: int
    p = cast[uint](image.data[0].addr)

  let
    zeroVec = vmovq_n_u8(0)
    vec255 = vmovq_n_u8(255)
    iterations = image.data.len div 4
  for _ in 0 ..< iterations:
    var values = vld1q_u8(cast[pointer](p))
    values = vceqq_u8(values, zeroVec)
    values = vbicq_u8(vec255, values)
    vst1q_u8(cast[pointer](p), values)
    p += 16
  i += 4 * iterations

  for i in i ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = if rgbx.r == 0: 0 else: 255
    rgbx.g = if rgbx.g == 0: 0 else: 255
    rgbx.b = if rgbx.b == 0: 0 else: 255
    rgbx.a = if rgbx.a == 0: 0 else: 255
    image.data[i] = rgbx

proc minifyBy2Neon*(image: Image, power = 1): Image {.simd.} =
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
      evenLanes = [0.uint8, 2, 4, 6, 255, 255, 255, 255]
      tblIdx = vld1_u8(evenLanes.unsafeAddr)
    for y in 0 ..< resultEvenHeight:
      let
        topRowStart = src.dataIndex(0, y * 2)
        bottomRowStart = src.dataIndex(0, y * 2 + 1)

      var x: int
      while x <= resultEvenWidth - 9:
        let
          top = vld4_u8(src.data[topRowStart + x * 2].addr)
          topNext = vld4_u8(src.data[topRowStart + x * 2 + 1].addr)
          bottom = vld4_u8(src.data[bottomRowStart + x * 2].addr)
          bottomNext = vld4_u8(src.data[bottomRowStart + x * 2 + 1].addr)
          r = vrshrn_n_u16(vaddq_u16(
            vaddl_u8(top.val[0], topNext.val[0]),
            vaddl_u8(bottom.val[0], bottomNext.val[0])
          ), 2)
          g = vrshrn_n_u16(vaddq_u16(
            vaddl_u8(top.val[1], topNext.val[1]),
            vaddl_u8(bottom.val[1], bottomNext.val[1])
          ), 2)
          b = vrshrn_n_u16(vaddq_u16(
            vaddl_u8(top.val[2], topNext.val[2]),
            vaddl_u8(bottom.val[2], bottomNext.val[2])
          ), 2)
          a = vrshrn_n_u16(vaddq_u16(
            vaddl_u8(top.val[3], topNext.val[3]),
            vaddl_u8(bottom.val[3], bottomNext.val[3])
          ), 2)
        # The correct values are in the even lanes 0, 2, 4, 6
        var correct: uint8x8x4
        correct.val[0] = vtbl1_u8(r, tblIdx)
        correct.val[1] = vtbl1_u8(g, tblIdx)
        correct.val[2] = vtbl1_u8(b, tblIdx)
        correct.val[3] = vtbl1_u8(a, tblIdx)
        vst4_u8(result.data[result.dataIndex(x, y)].addr, correct)
        x += 4

      for x in x ..< resultEvenWidth:
        let
          a = src.data[topRowStart + x * 2]
          b = src.data[topRowStart + x * 2 + 1]
          c = src.data[bottomRowStart + x * 2 + 1]
          d = src.data[bottomRowStart + x * 2]
          mixed = rgbx(
            ((a.r.uint32 + b.r + c.r + d.r) div 4).uint8,
            ((a.g.uint32 + b.g + c.g + d.g) div 4).uint8,
            ((a.b.uint32 + b.b + c.b + d.b) div 4).uint8,
            ((a.a.uint32 + b.a + c.a + d.a) div 4).uint8
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

proc magnifyBy2Neon*(image: Image, power = 1): Image {.simd.} =
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
      template duplicate(vec: uint8x8): uint8x16 =
        let duplicated = vzip_u8(vec, vec)
        vcombine_u8(duplicated.val[0], duplicated.val[1])
      while x <= image.width - 8:
        let values = vld4_u8(image.data[sourceRowStart + x].addr)
        var duplicated: uint8x16x4
        duplicated.val[0] = duplicate(values.val[0])
        duplicated.val[1] = duplicate(values.val[1])
        duplicated.val[2] = duplicate(values.val[2])
        duplicated.val[3] = duplicate(values.val[3])
        vst4q_u8(result.data[resultRowStart + x * scale].addr, duplicated)
        x += 8
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

proc blendLineCoverageOverwriteNeon*(
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

  var vecRgbx: uint8x16x4
  vecRgbx.val[0] = vmovq_n_u8(rgbx.r)
  vecRgbx.val[1] = vmovq_n_u8(rgbx.g)
  vecRgbx.val[2] = vmovq_n_u8(rgbx.b)
  vecRgbx.val[3] = vmovq_n_u8(rgbx.a)

  let
    vecZero = vmovq_n_u8(0)
    vec255 = vmovq_n_u8(255)
  while i < len - 16:
    let
      coverage = vld1q_u8(coverages[i].addr)
      eqZero = vceqq_u8(coverage, vecZero)
      eq255 = vceqq_u8(coverage, vec255)
      maskZero = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eqZero), vget_high_u8(eqZero)
      )), 0)
      mask255 = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eq255), vget_high_u8(eq255)
      )), 0)
    if maskZero == uint64.high:
      discard
    elif mask255 == uint64.high:
      vst4q_u8(line[i].addr, vecRgbx)
    else:
      var source: uint8x16x4
      source.val[0] = multiplyDiv255(vecRgbx.val[0], coverage)
      source.val[1] = multiplyDiv255(vecRgbx.val[1], coverage)
      source.val[2] = multiplyDiv255(vecRgbx.val[2], coverage)
      source.val[3] = multiplyDiv255(vecRgbx.val[3], coverage)
      vst4q_u8(line[i].addr, source)

    i += 16

  for i in i ..< len:
    let coverage = coverages[i]
    if coverage != 0:
      line[i] = rgbx * coverage

proc blendLineNormalNeon*(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 15) != 0:
    line[i] = blendNormal(line[i], rgbx)
    inc i

  var vecRgbx: uint8x16x4
  vecRgbx.val[0] = vmovq_n_u8(rgbx.r)
  vecRgbx.val[1] = vmovq_n_u8(rgbx.g)
  vecRgbx.val[2] = vmovq_n_u8(rgbx.b)
  vecRgbx.val[3] = vmovq_n_u8(rgbx.a)

  let vec255 = vmovq_n_u8(255)
  while i < len - 16:
    let backdrop = vld4q_u8(line[i].addr)
    vst4q_u8(line[i].addr, blendNormalSimd(backdrop, vecRgbx))
    i += 16

  for i in i ..< len:
    line[i] = blendNormal(line[i], rgbx)

proc blendLineNormalNeon*(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](a[i].addr) and 15) != 0:
    a[i] = blendNormal(a[i], b[i])
    inc i

  let vec255 = vmovq_n_u8(255)
  while i < len - 16:
    let
      source = vld4q_u8(b[i].addr)
      eq255 = vceqq_u8(source.val[3], vec255)
      mask = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eq255), vget_high_u8(eq255)
      )), 0)
    if mask == uint64.high:
      vst4q_u8(a[i].addr, source)
    else:
      let backdrop = vld4q_u8(a[i].addr)
      vst4q_u8(a[i].addr, blendNormalSimd(backdrop, source))

    i += 16

  for i in i ..< len:
    a[i] = blendNormal(a[i], b[i])

proc blendLineCoverageNormalNeon*(
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

  var vecRgbx: uint8x16x4
  vecRgbx.val[0] = vmovq_n_u8(rgbx.r)
  vecRgbx.val[1] = vmovq_n_u8(rgbx.g)
  vecRgbx.val[2] = vmovq_n_u8(rgbx.b)
  vecRgbx.val[3] = vmovq_n_u8(rgbx.a)

  let
    vecZero = vmovq_n_u8(0)
    vec255 = vmovq_n_u8(255)
  while i < len - 16:
    let
      coverage = vld1q_u8(coverages[i].addr)
      eqZero = vceqq_u8(coverage, vecZero)
      eq255 = vceqq_u8(coverage, vec255)
      maskZero = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eqZero), vget_high_u8(eqZero)
      )), 0)
      mask255 = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eq255), vget_high_u8(eq255)
      )), 0)
    if maskZero == uint64.high:
      discard
    elif mask255 == uint64.high and rgbx.a == 255:
      vst4q_u8(line[i].addr, vecRgbx)
    else:
      var source: uint8x16x4
      source.val[0] = multiplyDiv255(vecRgbx.val[0], coverage)
      source.val[1] = multiplyDiv255(vecRgbx.val[1], coverage)
      source.val[2] = multiplyDiv255(vecRgbx.val[2], coverage)
      source.val[3] = multiplyDiv255(vecRgbx.val[3], coverage)

      let backdrop = vld4q_u8(line[i].addr)
      vst4q_u8(line[i].addr, blendNormalSimd(backdrop, source))

    i += 16

  for i in i ..< len:
    let coverage = coverages[i]
    if coverage == 0:
      discard
    else:
      line[i] = blendNormal(line[i], rgbx * coverage)

proc blendLineMaskNeon*(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](line[i].addr) and 15) != 0:
    line[i] = blendMask(line[i], rgbx)
    inc i

  let alpha = vmovq_n_u8(rgbx.a)
  while i < len - 16:
    let backdrop = vld4q_u8(line[i].addr)
    var blended: uint8x16x4
    blended.val[0] = multiplyDiv255(backdrop.val[0], alpha)
    blended.val[1] = multiplyDiv255(backdrop.val[1], alpha)
    blended.val[2] = multiplyDiv255(backdrop.val[2], alpha)
    blended.val[3] = multiplyDiv255(backdrop.val[3], alpha)
    vst4q_u8(line[i].addr, blended)
    i += 16

  for i in i ..< len:
    line[i] = blendMask(line[i], rgbx)

proc blendLineMaskNeon*(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.simd.} =
  var i: int
  while i < len and (cast[uint](a[i].addr) and 15) != 0:
    a[i] = blendMask(a[i], b[i])
    inc i

  let vec255 = vmovq_n_u8(255)
  while i < len - 16:
    let
      source = vld4q_u8(b[i].addr)
      eq255 = vceqq_u8(source.val[3], vec255)
      mask = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eq255), vget_high_u8(eq255)
      )), 0)
    if mask == uint64.high:
      discard
    else:
      let backdrop = vld4q_u8(a[i].addr)
      var blended: uint8x16x4
      blended.val[0] = multiplyDiv255(backdrop.val[0], source.val[3])
      blended.val[1] = multiplyDiv255(backdrop.val[1], source.val[3])
      blended.val[2] = multiplyDiv255(backdrop.val[2], source.val[3])
      blended.val[3] = multiplyDiv255(backdrop.val[3], source.val[3])
      vst4q_u8(a[i].addr, blended)

    i += 16

  for i in i ..< len:
    a[i] = blendMask(a[i], b[i])

proc blendLineCoverageMaskNeon*(
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
    alpha = vmovq_n_u8(rgbx.a)
    vecZero = vmovq_n_u8(0)
    vec255 = vmovq_n_u8(255)
  while i < len - 16:
    let
      coverage = vld1q_u8(coverages[i].addr)
      eqZero = vceqq_u8(coverage, vecZero)
      eq255 = vceqq_u8(coverage, vec255)
      maskZero = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eqZero), vget_high_u8(eqZero)
      )), 0)
      mask255 = vget_lane_u64(cast[uint64x1](
        vand_u8(vget_low_u8(eq255), vget_high_u8(eq255)
      )), 0)
    if maskZero == uint64.high:
      vst1q_u8(line[i].addr, vecZero)
      vst1q_u8(line[i + 4].addr, vecZero)
      vst1q_u8(line[i + 8].addr, vecZero)
      vst1q_u8(line[i + 12].addr, vecZero)
    elif mask255 == uint64.high and rgbx.a == 255:
      discard
    else:
      let
        backdrop = vld4q_u8(line[i].addr)
        alpha = multiplyDiv255(alpha, coverage)
      var blended: uint8x16x4
      blended.val[0] = multiplyDiv255(backdrop.val[0], alpha)
      blended.val[1] = multiplyDiv255(backdrop.val[1], alpha)
      blended.val[2] = multiplyDiv255(backdrop.val[2], alpha)
      blended.val[3] = multiplyDiv255(backdrop.val[3], alpha)
      vst4q_u8(line[i].addr, blended)

    i += 16

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
