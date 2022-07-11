import chroma, internal, nimsimd/neon, pixie/common

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

when defined(release):
  {.pop.}
