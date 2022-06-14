import common, internal, vmath

when defined(amd64) and allowSimd:
  import nimsimd/sse2

type
  Mask* = ref object
    ## Mask object that holds mask opacity data.
    width*, height*: int
    data*: seq[uint8]

  UnsafeMask = distinct Mask

when defined(release):
  {.push checks: off.}

proc newMask*(width, height: int): Mask {.raises: [PixieError].} =
  ## Creates a new mask with the parameter dimensions.
  if width <= 0 or height <= 0:
    raise newException(PixieError, "Mask width and height must be > 0")

  result = Mask()
  result.width = width
  result.height = height
  result.data = newSeq[uint8](width * height)

proc copy*(mask: Mask): Mask {.raises: [PixieError].} =
  ## Copies the image data into a new image.
  result = newMask(mask.width, mask.height)
  result.data = mask.data

proc `$`*(mask: Mask): string {.raises: [].} =
  ## Prints the mask size.
  "<Mask " & $mask.width & "x" & $mask.height & ">"

proc inside*(mask: Mask, x, y: int): bool {.inline, raises: [].} =
  ## Returns true if (x, y) is inside the mask.
  x >= 0 and x < mask.width and y >= 0 and y < mask.height

proc dataIndex*(mask: Mask, x, y: int): int {.inline, raises: [].} =
  mask.width * y + x

template unsafe*(src: Mask): UnsafeMask =
  cast[UnsafeMask](src)

template `[]`*(view: UnsafeMask, x, y: int): uint8 =
  ## Gets a value from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory reads.
  cast[Mask](view).data[cast[Mask](view).dataIndex(x, y)]

template `[]=`*(view: UnsafeMask, x, y: int, color: uint8) =
  ## Sets a value from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory writes.
  cast[Mask](view).data[cast[Mask](view).dataIndex(x, y)] = color

proc `[]`*(mask: Mask, x, y: int): uint8 {.inline, raises: [].} =
  ## Gets a value at (x, y) or returns transparent black if outside of bounds.
  if mask.inside(x, y):
    return mask.unsafe[x, y]

proc `[]=`*(mask: Mask, x, y: int, value: uint8) {.inline, raises: [].} =
  ## Sets a value at (x, y) or does nothing if outside of bounds.
  if mask.inside(x, y):
    mask.unsafe[x, y] = value

proc getValue*(mask: Mask, x, y: int): uint8 {.inline, raises: [].} =
  ## Gets a value at (x, y) or returns transparent black if outside of bounds.
  mask[x, y]

proc setValue*(mask: Mask, x, y: int, value: uint8) {.inline, raises: [].} =
  ## Sets a value at (x, y) or does nothing if outside of bounds.
  mask[x, y] = value

proc minifyBy2*(mask: Mask, power = 1): Mask {.raises: [PixieError].} =
  ## Scales the mask down by an integer scale.
  if power < 0:
    raise newException(PixieError, "Cannot minifyBy2 with negative power")
  if power == 0:
    return mask.copy()

  var src = mask
  for i in 1 .. power:
    result = newMask(src.width div 2, src.height div 2)
    for y in 0 ..< result.height:
      var x: int
      when defined(amd64) and allowSimd:
        let
          oddMask = mm_set1_epi16(cast[int16](0xff00))
          firstByte = cast[M128i](
            [uint8.high, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
          )
        for _ in countup(0, result.width - 16, 8):
          let
            top = mm_loadu_si128(src.data[src.dataIndex(x * 2, y * 2 + 0)].addr)
            btm = mm_loadu_si128(src.data[src.dataIndex(x * 2, y * 2 + 1)].addr)
            topShifted = mm_srli_si128(top, 1)
            btmShifted = mm_srli_si128(btm, 1)

            topEven = mm_andnot_si128(oddMask, top)
            topOdd = mm_srli_epi16(mm_and_si128(top, oddMask), 8)
            btmEven = mm_andnot_si128(oddMask, btm)
            btmOdd = mm_srli_epi16(mm_and_si128(btm, oddMask), 8)

            topShiftedEven = mm_andnot_si128(oddMask, topShifted)
            topShiftedOdd = mm_srli_epi16(mm_and_si128(topShifted, oddMask), 8)
            btmShiftedEven = mm_andnot_si128(oddMask, btmShifted)
            btmShiftedOdd = mm_srli_epi16(mm_and_si128(btmShifted, oddMask), 8)

            topAddedEven = mm_add_epi16(topEven, topShiftedEven)
            btmAddedEven = mm_add_epi16(btmEven, btmShiftedEven)
            topAddedOdd = mm_add_epi16(topOdd, topShiftedOdd)
            bottomAddedOdd = mm_add_epi16(btmOdd, btmShiftedOdd)

            addedEven = mm_add_epi16(topAddedEven, btmAddedEven)
            addedOdd = mm_add_epi16(topAddedOdd, bottomAddedOdd)

            addedEvenDiv4 = mm_srli_epi16(addedEven, 2)
            addedOddDiv4 = mm_srli_epi16(addedOdd, 2)

            merged = mm_or_si128(addedEvenDiv4, mm_slli_epi16(addedOddDiv4, 8))

            # merged has the correct values in the even indices

            a = mm_and_si128(merged, firstByte)
            b = mm_and_si128(mm_srli_si128(merged, 2), firstByte)
            c = mm_and_si128(mm_srli_si128(merged, 4), firstByte)
            d = mm_and_si128(mm_srli_si128(merged, 6), firstByte)
            e = mm_and_si128(mm_srli_si128(merged, 8), firstByte)
            f = mm_and_si128(mm_srli_si128(merged, 10), firstByte)
            g = mm_and_si128(mm_srli_si128(merged, 12), firstByte)
            h = mm_and_si128(mm_srli_si128(merged, 14), firstByte)

            ab = mm_or_si128(a, mm_slli_si128(b, 1))
            cd = mm_or_si128(c, mm_slli_si128(d, 1))
            ef = mm_or_si128(e, mm_slli_si128(f, 1))
            gh = mm_or_si128(g, mm_slli_si128(h, 1))

            abcd = mm_or_si128(ab, mm_slli_si128(cd, 2))
            efgh = mm_or_si128(ef, mm_slli_si128(gh, 2))

            abcdefgh = mm_or_si128(abcd, mm_slli_si128(efgh, 4))

          mm_storeu_si128(result.data[result.dataIndex(x, y)].addr, abcdefgh)
          x += 8

      for x in x ..< result.width:
        let value =
          src.unsafe[x * 2 + 0, y * 2 + 0].uint32 +
          src.unsafe[x * 2 + 1, y * 2 + 0] +
          src.unsafe[x * 2 + 1, y * 2 + 1] +
          src.unsafe[x * 2 + 0, y * 2 + 1]
        result.unsafe[x, y] = (value div 4).uint8

    # Set src as this result for if we do another power
    src = result

proc magnifyBy2*(mask: Mask, power = 1): Mask {.raises: [PixieError].} =
  ## Scales mask up by 2 ^ power.
  if power < 0:
    raise newException(PixieError, "Cannot magnifyBy2 with negative power")

  let scale = 2 ^ power
  result = newMask(mask.width * scale, mask.height * scale)

  for y in 0 ..< mask.height:
    # Write one row of values duplicated by scale
    var x: int
    when defined(amd64) and allowSimd:
      if scale == 2:
        while x <= mask.width - 16:
          let
            values = mm_loadu_si128(mask.data[mask.dataIndex(x, y)].addr)
            lo = mm_unpacklo_epi8(values, mm_setzero_si128())
            hi = mm_unpacklo_epi8(values, mm_setzero_si128())
          mm_storeu_si128(
            result.data[result.dataIndex(x * scale + 0, y * scale)].addr,
            mm_or_si128(lo, mm_slli_si128(lo, 1))
          )
          mm_storeu_si128(
            result.data[result.dataIndex(x * scale + 16, y * scale)].addr,
            mm_or_si128(hi, mm_slli_si128(hi, 1))
          )
          x += 16
    for x in x ..< mask.width:
      let
        value = mask.unsafe[x, y div scale]
        scaledX = x * scale
        idx = result.dataIndex(scaledX, y)
      for i in 0 ..< scale:
        result.data[idx + i] = value
    # Copy that row of values into (scale - 1) more rows
    let rowStart = result.dataIndex(0, y * scale)
    for i in 1 ..< scale:
      copyMem(
        result.data[rowStart + result.width * i].addr,
        result.data[rowStart].addr,
        result.width * 4
      )

proc fill*(mask: Mask, value: uint8) {.inline, raises: [].} =
  ## Fills the mask with the value.
  fillUnsafe(mask.data, value, 0, mask.data.len)

proc getValueSmooth*(mask: Mask, x, y: float32): uint8 {.raises: [].} =
  ## Gets a interpolated value with float point coordinates.
  let
    x0 = x.int
    y0 = y.int
    x1 = x0 + 1
    y1 = y0 + 1
    xFractional = x.fractional
    yFractional = y.fractional

    x0y0 = mask[x0, y0]
    x1y0 = mask[x1, y0]
    x0y1 = mask[x0, y1]
    x1y1 = mask[x1, y1]

  var topMix = x0y0
  if xFractional > 0 and x0y0 != x1y0:
    topMix = mix(x0y0, x1y0, xFractional)

  var bottomMix = x0y1
  if xFractional > 0 and x0y1 != x1y1:
    bottomMix = mix(x0y1, x1y1, xFractional)

  if yFractional != 0 and topMix != bottomMix:
    mix(topMix, bottomMix, yFractional)
  else:
    topMix

proc invert*(mask: Mask) {.raises: [].} =
  ## Inverts all of the values - creates a negative of the mask.
  var i: int
  when defined(amd64) and allowSimd:
    let vec255 = mm_set1_epi8(cast[int8](255))
    let byteLen = mask.data.len
    for _ in 0 ..< byteLen div 16:
      let index = i
      var values = mm_loadu_si128(mask.data[index].addr)
      values = mm_sub_epi8(vec255, values)
      mm_storeu_si128(mask.data[index].addr, values)
      i += 16

  for j in i ..< mask.data.len:
    mask.data[j] = (255 - mask.data[j]).uint8

proc spread*(mask: Mask, spread: float32) {.raises: [PixieError].} =
  ## Grows the mask by spread.
  let spread = round(spread).int
  if spread == 0:
    return

  if spread > 0:

    # Spread in the X direction. Store with dimensions swapped for reading later.
    let spreadX = newMask(mask.height, mask.width)
    for y in 0 ..< mask.height:
      for x in 0 ..< mask.width:
        var maxValue: uint8
        for xx in max(x - spread, 0) .. min(x + spread, mask.width - 1):
          let value = mask.unsafe[xx, y]
          if value > maxValue:
            maxValue = value
          if maxValue == 255:
            break
        spreadX.unsafe[y, x] = maxValue

    # Spread in the Y direction and modify mask.
    for y in 0 ..< mask.height:
      for x in 0 ..< mask.width:
        var maxValue: uint8
        for yy in max(y - spread, 0) .. min(y + spread, mask.height - 1):
          let value = spreadX.unsafe[yy, x]
          if value > maxValue:
            maxValue = value
          if maxValue == 255:
            break
        mask.unsafe[x, y] = maxValue

  elif spread < 0:

    # Spread in the X direction. Store with dimensions swapped for reading later.
    let spread = -spread
    let spreadX = newMask(mask.height, mask.width)
    for y in 0 ..< mask.height:
      for x in 0 ..< mask.width:
        var maxValue: uint8 = 255
        for xx in max(x - spread, 0) .. min(x + spread, mask.width - 1):
          let value = mask.unsafe[xx, y]
          if value < maxValue:
            maxValue = value
          if maxValue == 0:
            break
        spreadX.unsafe[y, x] = maxValue

    # Spread in the Y direction and modify mask.
    for y in 0 ..< mask.height:
      for x in 0 ..< mask.width:
        var maxValue: uint8 = 255
        for yy in max(y - spread, 0) .. min(y + spread, mask.height - 1):
          let value = spreadX.unsafe[yy, x]
          if value < maxValue:
            maxValue = value
          if maxValue == 0:
            break
        mask.unsafe[x, y] = maxValue

proc ceil*(mask: Mask) {.raises: [].} =
  ## A value of 0 stays 0. Anything else turns into 255.
  var i: int
  when defined(amd64) and allowSimd:
    let
      zeroVec = mm_setzero_si128()
      vec255 = mm_set1_epi32(cast[int32](uint32.high))
    for _ in 0 ..< mask.data.len div 16:
      var values = mm_loadu_si128(mask.data[i].addr)
      values = mm_cmpeq_epi8(values, zeroVec)
      values = mm_andnot_si128(values, vec255)
      mm_storeu_si128(mask.data[i].addr, values)
      i += 16

  for j in i ..< mask.data.len:
    if mask.data[j] != 0:
      mask.data[j] = 255

proc blur*(mask: Mask, radius: float32, outOfBounds: uint8 = 0) {.raises: [PixieError].} =
  ## Applies Gaussian blur to the image given a radius.
  let radius = round(radius).int
  if radius == 0:
    return
  if radius < 0:
    raise newException(PixieError, "Cannot apply negative blur")

  let kernel = gaussianKernel(radius)

  # Blur in the X direction. Store with dimensions swapped for reading later.
  let blurX = newMask(mask.height, mask.width)
  for y in 0 ..< mask.height:
    for x in 0 ..< mask.width:
      var value: uint32
      for xx in x - radius ..< min(x + radius, 0):
        value += outOfBounds * kernel[xx - x + radius].uint32
      for xx in max(x - radius, 0) .. min(x + radius, mask.width - 1):
        value += mask.unsafe[xx, y] * kernel[xx - x + radius].uint32
      for xx in max(x - radius, mask.width) .. x + radius:
        value += outOfBounds * kernel[xx - x + radius].uint32
      blurX.unsafe[y, x] = (value div 256 div 255).uint8

  # Blur in the Y direction and modify image.
  for y in 0 ..< mask.height:
    for x in 0 ..< mask.width:
      var value: uint32
      for yy in y - radius ..< min(y + radius, 0):
        value += outOfBounds * kernel[yy - y + radius].uint32
      for yy in max(y - radius, 0) .. min(y + radius, mask.height - 1):
        value += blurX.unsafe[yy, x] * kernel[yy - y + radius].uint32
      for yy in max(y - radius, mask.height) .. y + radius:
        value += outOfBounds * kernel[yy - y + radius].uint32
      mask.unsafe[x, y] = (value div 256 div 255).uint8

when defined(release):
  {.pop.}
