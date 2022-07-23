import chroma, internal, nimsimd/neon, pixie/common, system/memory, vmath

when defined(release):
  {.push checks: off.}

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
      mask =
        cast[uint64](vget_low_u64(cast[uint64x2](rgbaEq))) and
        cast[uint64](vget_high_u64(cast[uint64x2](rgbaEq)))
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

  let iterations = (image.data.len - i) div 16
  for _ in 0 ..< iterations:
    let
      alphas = vld4q_u8(image.data[i].addr).val[3]
      eq = vceqq_u64(cast[uint64x2](alphas), vmovq_n_u64(0))
      mask = cast[uint64](vget_low_u64(eq)) and cast[uint64](vget_high_u64(eq))
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

  let iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    let
      alphas = vld4q_u8(data[i].addr).val[3]
      eq = vceqq_u64(cast[uint64x2](alphas), vmovq_n_u64(uint64.high))
      mask = cast[uint64](vget_low_u64(eq)) and cast[uint64](vget_high_u64(eq))
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

  proc premultiply(c, a: uint8x8): uint8x8 {.inline.} =
    let ca = vmull_u8(c, a)
    vraddhn_u16(ca, vrshrq_n_u16(ca, 8))

  let iterations = (data.len - i) div 8
  for _ in 0 ..< iterations:
    var channels = vld4_u8(cast[pointer](p))
    channels.val[0] = premultiply(channels.val[0], channels.val[3])
    channels.val[1] = premultiply(channels.val[1], channels.val[3])
    channels.val[2] = premultiply(channels.val[2], channels.val[3])
    vst4_u8(cast[pointer](p), channels)
    p += 32
  i += 8 * iterations

  for i in i ..< data.len:
    var c = data[i]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a + 127) div 255).uint8
      c.g = ((c.g.uint32 * c.a + 127) div 255).uint8
      c.b = ((c.b.uint32 * c.a + 127) div 255).uint8
      data[i] = c

proc newImageNeon*(mask: Mask): Image {.simd.} =
  result = newImage(mask.width, mask.height)

  var i: int
  for _ in 0 ..< mask.data.len div 16:
    let alphas = vld1q_u8(mask.data[i].addr)
    template doLane(lane: int) =
      let packed = vgetq_lane_u32(cast[uint32x4](alphas), lane)
      var unpacked = cast[uint8x16](vmovq_n_u32(packed))
      unpacked = vzip1q_u8(unpacked, unpacked)
      unpacked = vzip1q_u8(unpacked, unpacked)
      vst1q_u8(result.data[i + lane * 4].addr, unpacked)
    doLane(0)
    doLane(1)
    doLane(2)
    doLane(3)
    i += 16

  for i in i ..< mask.data.len:
    let v = mask.data[i]
    result.data[i] = rgbx(v, v, v, v)

proc newMaskNeon*(image: Image): Mask {.simd.} =
  result = newMask(image.width, image.height)

  var i: int
  for _ in 0 ..< image.data.len div 16:
    let alphas = vld4q_u8(image.data[i].addr).val[3]
    vst1q_u8(result.data[i].addr, alphas)
    i += 16

  for i in i ..< image.data.len:
    result.data[i] = image.data[i].a

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

proc invertNeon*(mask: Mask) {.simd.} =
  var
    i: int
    p = cast[uint](mask.data[0].addr)
  # Align to 16 bytes
  while i < mask.data.len and (p and 15) != 0:
    mask.data[i] = 255 - mask.data[i]
    inc i
    inc p

  let
    vec255 = vmovq_n_u8(255)
    iterations = mask.data.len div 16
  for _ in 0 ..< iterations:
    let values = vld1q_u8(cast[pointer](p))
    vst1q_u8(cast[pointer](p), vsubq_u8(vec255, values))
    p += 16
  i += 16 * iterations

  for i in i ..< mask.data.len:
    mask.data[i] = 255 - mask.data[i]

proc ceilNeon*(mask: Mask) {.simd.} =
  var
    i: int
    p = cast[uint](mask.data[0].addr)

  let
    zeroVec = vmovq_n_u8(0)
    vec255 = vmovq_n_u8(255)
    iterations = mask.data.len div 16
  for _ in 0 ..< iterations:
    var values = vld1q_u8(cast[pointer](p))
    values = vceqq_u8(values, zeroVec)
    values = vbicq_u8(vec255, values)
    vst1q_u8(cast[pointer](p), values)
    p += 16
  i += 16 * iterations

  for i in i ..< mask.data.len:
    if mask.data[i] != 0:
      mask.data[i] = 255

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

  proc apply(c, o: uint8x8): uint8x8 {.inline.} =
    let co = vmull_u8(c, o)
    vraddhn_u16(co, vrshrq_n_u16(co, 8))

  let
    opacityVec = vmov_n_u8(opacity)
    iterations = image.data.len div 8
  for _ in 0 ..< iterations:
    var channels = vld4_u8(cast[pointer](p))
    channels.val[0] = apply(channels.val[0], opacityVec)
    channels.val[1] = apply(channels.val[1], opacityVec)
    channels.val[2] = apply(channels.val[2], opacityVec)
    channels.val[3] = apply(channels.val[3], opacityVec)
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

proc applyOpacityNeon*(mask: Mask, opacity: float32) {.simd.} =
  let opacity = round(255 * opacity).uint8
  if opacity == 255:
    return

  if opacity == 0:
    nimSetMem(mask.data[0].addr, 0.cint, mask.data.len)

  var
    i: int
    p = cast[uint](mask.data[0].addr)

  let
    opacityVec = vmov_n_u8(opacity)
    iterations = mask.data.len div 8
  for _ in 0 ..< iterations:
    let
      values = vld1_u8(cast[pointer](p))
      multiplied = vmull_u8(values, opacityVec)
      rounded = vraddhn_u16(multiplied, vrshrq_n_u16(multiplied, 8))
    vst1_u8(cast[pointer](p), rounded)
    p += 8
  i += 8 * iterations

  for i in i ..< mask.data.len:
    mask.data[i] = ((mask.data[i] * opacity) div 255).uint8

when defined(release):
  {.pop.}
