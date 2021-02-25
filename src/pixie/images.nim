import blends, bumpy, chroma, common, masks, system/memory, vmath

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

const h = 0.5.float32

type
  Image* = ref object
    ## Image object that holds bitmap data in RGBA format.
    width*, height*: int
    data*: seq[ColorRGBA]

when defined(release):
  {.push checks: off.}

proc newImage*(width, height: int): Image =
  ## Creates a new image with the parameter dimensions.
  if width <= 0 or height <= 0:
    raise newException(PixieError, "Image width and height must be > 0")

  result = Image()
  result.width = width
  result.height = height
  result.data = newSeq[ColorRGBA](width * height)

proc wh*(image: Image): Vec2 {.inline.} =
  ## Return with and height as a size vector.
  vec2(image.width.float32, image.height.float32)

proc copy*(image: Image): Image =
  ## Copies the image data into a new image.
  result = newImage(image.width, image.height)
  result.data = image.data

proc `$`*(image: Image): string =
  ## Prints the image size.
  "<Image " & $image.width & "x" & $image.height & ">"

proc inside*(image: Image, x, y: int): bool {.inline.} =
  ## Returns true if (x, y) is inside the image.
  x >= 0 and x < image.width and y >= 0 and y < image.height

proc dataIndex*(image: Image, x, y: int): int {.inline.} =
  image.width * y + x

proc getRgbaUnsafe*(image: Image, x, y: int): ColorRGBA {.inline.} =
  ## Gets a color from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory reads.
  result = image.data[image.width * y + x]

proc `[]`*(image: Image, x, y: int): ColorRGBA {.inline.} =
  ## Gets a pixel at (x, y) or returns transparent black if outside of bounds.
  if image.inside(x, y):
    return image.getRgbaUnsafe(x, y)

proc setRgbaUnsafe*(image: Image, x, y: int, rgba: ColorRGBA) {.inline.} =
  ## Sets a color from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory writes.
  image.data[image.dataIndex(x, y)] = rgba

proc `[]=`*(image: Image, x, y: int, rgba: ColorRGBA) {.inline.} =
  ## Sets a pixel at (x, y) or does nothing if outside of bounds.
  if image.inside(x, y):
    image.setRgbaUnsafe(x, y, rgba)

proc fillUnsafe*(data: var seq[ColorRGBA], rgba: ColorRGBA, start, len: int) =
  ## Fills the image data with the parameter color starting at index start and
  ## continuing for len indices.

  # Use memset when every byte has the same value
  if rgba.r == rgba.g and rgba.r == rgba.b and rgba.r == rgba.a:
    nimSetMem(data[start].addr, rgba.r.cint, len * 4)
  else:
    var i = start
    when defined(amd64) and not defined(pixieNoSimd):
      # When supported, SIMD fill until we run out of room
      let m = mm_set1_epi32(cast[int32](rgba))
      for j in countup(i, start + len - 8, 8):
        mm_storeu_si128(data[j].addr, m)
        mm_storeu_si128(data[j + 4].addr, m)
        i += 8
    else:
      when sizeof(int) == 8:
        # Fill 8 bytes at a time when possible
        let
          u32 = cast[uint32](rgba)
          u64 = cast[uint64]([u32, u32])
        for j in countup(i, start + len - 2, 2):
          cast[ptr uint64](data[j].addr)[] = u64
          i += 2
    # Fill whatever is left the slow way
    for j in i ..< start + len:
      data[j] = rgba

proc fill*(image: Image, rgba: ColorRgba) {.inline.} =
  ## Fills the image with the parameter color.
  fillUnsafe(image.data, rgba, 0, image.data.len)

proc flipHorizontal*(image: Image) =
  ## Flips the image around the Y axis.
  let w = image.width div 2
  for y in 0 ..< image.height:
    for x in 0 ..< w:
      let
        rgba1 = image.getRgbaUnsafe(x, y)
        rgba2 = image.getRgbaUnsafe(image.width - x - 1, y)
      image.setRgbaUnsafe(image.width - x - 1, y, rgba1)
      image.setRgbaUnsafe(x, y, rgba2)

proc flipVertical*(image: Image) =
  ## Flips the image around the X axis.
  let h = image.height div 2
  for y in 0 ..< h:
    for x in 0 ..< image.width:
      let
        rgba1 = image.getRgbaUnsafe(x, y)
        rgba2 = image.getRgbaUnsafe(x, image.height - y - 1)
      image.setRgbaUnsafe(x, image.height - y - 1, rgba1)
      image.setRgbaUnsafe(x, y, rgba2)

proc subImage*(image: Image, x, y, w, h: int): Image =
  ## Gets a sub image from this image.

  if x < 0 or x + w > image.width:
    raise newException(
      PixieError,
      "Params x: " & $x & " w: " & $w & " invalid, image width is " & $image.width
    )
  if y < 0 or y + h > image.height:
    raise newException(
      PixieError,
      "Params y: " & $y & " h: " & $h & " invalid, image height is " & $image.height
    )

  result = newImage(w, h)
  for y2 in 0 ..< h:
    copyMem(
      result.data[result.dataIndex(0, y2)].addr,
      image.data[image.dataIndex(x, y + y2)].addr,
      w * 4
    )

proc superImage*(image: Image, x, y, w, h: int): Image =
  ## Either cuts a sub image or returns a super image with padded transparency.
  if x >= 0 and x + w <= image.width and y >= 0 and y + h <= image.height:
    result = image.subImage(x, y, w, h)
  elif abs(x) >= image.width or abs(y) >= image.height:
    # Nothing to copy, just an empty new image
    result = newImage(w, h)
  else:
    let
      readOffsetX = max(x, 0)
      readOffsetY = max(y, 0)
      writeOffsetX = max(0 - x, 0)
      writeOffsetY = max(0 - y, 0)
      copyWidth = max(min(image.width, w) - abs(x), 0)
      copyHeight = max(min(image.height, h) - abs(y), 0)

    result = newImage(w, h)
    for y2 in 0 ..< copyHeight:
      copyMem(
        result.data[result.dataIndex(writeOffsetX, writeOffsetY + y2)].addr,
        image.data[image.dataIndex(readOffsetX, readOffsetY + y2)].addr,
        copyWidth * 4
      )

proc minifyBy2*(image: Image, power = 1): Image =
  ## Scales the image down by an integer scale.
  if power < 0:
    raise newException(PixieError, "Cannot minifyBy2 with negative power")
  if power == 0:
    return image.copy()

  var src = image
  for i in 1 .. power:
    result = newImage(src.width div 2, src.height div 2)
    for y in 0 ..< result.height:
      for x in 0 ..< result.width:
        let
          a = src.getRgbaUnsafe(x * 2 + 0, y * 2 + 0)
          b = src.getRgbaUnsafe(x * 2 + 1, y * 2 + 0)
          c = src.getRgbaUnsafe(x * 2 + 1, y * 2 + 1)
          d = src.getRgbaUnsafe(x * 2 + 0, y * 2 + 1)

        let color = rgba(
          ((a.r.uint32 + b.r + c.r + d.r) div 4).uint8,
          ((a.g.uint32 + b.g + c.g + d.g) div 4).uint8,
          ((a.b.uint32 + b.b + c.b + d.b) div 4).uint8,
          ((a.a.uint32 + b.a + c.a + d.a) div 4).uint8
        )

        result.setRgbaUnsafe(x, y, color)

    # Set src as this result for if we do another power
    src = result

proc magnifyBy2*(image: Image, power = 1): Image =
  ## Scales image image up by 2 ^ power.
  if power < 0:
    raise newException(PixieError, "Cannot magnifyBy2 with negative power")

  let scale = 2 ^ power
  result = newImage(image.width * scale, image.height * scale)
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      var rgba = image.getRgbaUnsafe(x div scale, y div scale)
      result.setRgbaUnsafe(x, y, rgba)

proc toPremultipliedAlpha*(image: Image) =
  ## Converts an image to premultiplied alpha from straight alpha.
  var i: int
  when defined(amd64) and not defined(pixieNoSimd):
    # When supported, SIMD convert as much as possible
    let
      alphaMask = mm_set1_epi32(cast[int32](0xff000000))
      alphaMaskComp = mm_set1_epi32(0x00ffffff)
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))

    for j in countup(i, image.data.len - 4, 4):
      var
        color = mm_loadu_si128(image.data[j].addr)
        alpha = mm_and_si128(color, alphaMask)
        colorEven = mm_slli_epi16(color, 8)
        colorOdd = mm_and_si128(color, oddMask)

      alpha = mm_or_si128(alpha, mm_srli_epi32(alpha, 16))

      colorEven = mm_mulhi_epu16(colorEven, alpha)
      colorOdd = mm_mulhi_epu16(colorOdd, alpha)

      colorEven = mm_srli_epi16(mm_mulhi_epu16(colorEven, div255), 7)
      colorOdd = mm_srli_epi16(mm_mulhi_epu16(colorOdd, div255), 7)

      color = mm_or_si128(colorEven, mm_slli_epi16(colorOdd, 8))
      color = mm_or_si128(
        mm_and_si128(alpha, alphaMask), mm_and_si128(color, alphaMaskComp)
      )

      mm_storeu_si128(image.data[j].addr, color)
      i += 4
  # Convert whatever is left
  for j in i ..< image.data.len:
    var c = image.data[j]
    c.r = ((c.r.uint32 * c.a.uint32) div 255).uint8
    c.g = ((c.g.uint32 * c.a.uint32) div 255).uint8
    c.b = ((c.b.uint32 * c.a.uint32) div 255).uint8
    image.data[j] = c

proc toStraightAlpha*(image: Image) =
  ## Converts an image from premultiplied alpha to straight alpha.
  ## This is expensive for large images.
  for c in image.data.mitems:
    if c.a == 0 or c.a == 255:
      continue
    let multiplier = ((255 / c.a.float32) * 255).uint32
    c.r = ((c.r.uint32 * multiplier) div 255).uint8
    c.g = ((c.g.uint32 * multiplier) div 255).uint8
    c.b = ((c.b.uint32 * multiplier) div 255).uint8

proc applyOpacity*(target: Image | Mask, opacity: float32) =
  ## Multiplies alpha of the image by opacity.
  let opacity = round(255 * opacity).uint16

  if opacity == 0:
    when type(target) is Image:
      target.fill(rgba(0, 0, 0, 0))
    else:
      target.fill(0)
    return

  var i: int
  when defined(amd64) and not defined(pixieNoSimd):
    when type(target) is Image:
      let byteLen = target.data.len * 4
    else:
      let byteLen = target.data.len

    let
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))
      vOpacity = mm_slli_epi16(mm_set1_epi16(cast[int16](opacity)), 8)

    for _ in countup(0, byteLen - 16, 16):
      when type(target) is Image:
        let index = i div 4
      else:
        let index = i

      var values = mm_loadu_si128(target.data[index].addr)

      let eqZero = mm_cmpeq_epi16(values, mm_setzero_si128())
      if mm_movemask_epi8(eqZero) != 0xffff:
        var
          valuesEven = mm_slli_epi16(mm_andnot_si128(oddMask, values), 8)
          valuesOdd = mm_and_si128(values, oddMask)

        # values * opacity
        valuesEven = mm_mulhi_epu16(valuesEven, vOpacity)
        valuesOdd = mm_mulhi_epu16(valuesOdd, vOpacity)

        # div 255
        valuesEven = mm_srli_epi16(mm_mulhi_epu16(valuesEven, div255), 7)
        valuesOdd = mm_srli_epi16(mm_mulhi_epu16(valuesOdd, div255), 7)

        valuesOdd = mm_slli_epi16(valuesOdd, 8)

        mm_storeu_si128(
          target.data[index].addr,
          mm_or_si128(valuesEven, valuesOdd)
        )

      i += 16

  when type(target) is Image:
    for j in i div 4 ..< target.data.len:
      var rgba = target.data[j]
      rgba.r = ((rgba.r * opacity) div 255).uint8
      rgba.g = ((rgba.g * opacity) div 255).uint8
      rgba.b = ((rgba.b * opacity) div 255).uint8
      rgba.a = ((rgba.a * opacity) div 255).uint8
      target.data[j] = rgba
  else:
    for j in i ..< target.data.len:
      target.data[j] = ((target.data[j] * opacity) div 255).uint8

proc invert*(target: Image | Mask) =
  ## Inverts all of the colors and alpha.
  var i: int
  when defined(amd64) and not defined(pixieNoSimd):
    let v255 = mm_set1_epi8(cast[int8](255))

    when type(target) is Image:
      let byteLen = target.data.len * 4
    else:
      let byteLen = target.data.len

    for _ in countup(0, byteLen - 16, 16):
      when type(target) is Image:
        let index = i div 4
      else:
        let index = i

      var values = mm_loadu_si128(target.data[index].addr)
      values = mm_sub_epi8(v255, values)
      mm_storeu_si128(target.data[index].addr, values)

      i += 16

  when type(target) is Image:
    for j in i div 4 ..< target.data.len:
      var rgba = target.data[j]
      rgba.r = 255 - rgba.r
      rgba.g = 255 - rgba.g
      rgba.b = 255 - rgba.b
      rgba.a = 255 - rgba.a
      target.data[j] = rgba

    # Inverting rgba(50, 100, 150, 200) becomes rgba(205, 155, 105, 55). This
    # is not a valid premultiplied alpha color.
    # We need to convert back to premultiplied alpha after inverting.
    target.toPremultipliedAlpha()
  else:
    for j in i ..< target.data.len:
      target.data[j] = (255 - target.data[j]).uint8

proc blur*(target: Image | Mask, radius: float32, offBounds: uint32 = 0) =
  ## Applies Gaussian blur to the image given a radius.
  let radius = round(radius).int
  if radius == 0:
    return

  proc gaussianLookup(radius: int): seq[uint32] =
    ## Compute lookup table for 1d Gaussian kernel.
    ## Values are [0, 255] * 1024.
    result.setLen(radius * 2 + 1)

    var
      floats = newSeq[float32](result.len)
      total = 0.0
    for xb in -radius .. radius:
      let
        s = radius.float32 / 2.2 # 2.2 matches Figma.
        x = xb.float32
        a = 1 / sqrt(2 * PI * s^2) * exp(-1 * x^2 / (2 * s^2))
      floats[xb + radius] = a
      total += a
    for xb in -radius .. radius:
      floats[xb + radius] = floats[xb + radius] / total

    for i, f in floats:
      result[i] = round(f * 255 * 1024).uint32

  let lookup = gaussianLookup(radius)

  when type(target) is Image:
    # TODO support offBounds for images.
    doAssert offBounds == 0

    template `*`(sample: ColorRGBA, a: uint32): array[4, uint32] =
      [
        sample.r * a,
        sample.g * a,
        sample.b * a,
        sample.a * a
      ]

    template `+=`(values: var array[4, uint32], sample: array[4, uint32]) =
      values[0] += sample[0]
      values[1] += sample[1]
      values[2] += sample[2]
      values[3] += sample[3]

    template rgba(values: array[4, uint32]): ColorRGBA =
      rgba(
        (values[0] div 1024 div 255).uint8,
        (values[1] div 1024 div 255).uint8,
        (values[2] div 1024 div 255).uint8,
        (values[3] div 1024 div 255).uint8
      )

    # Blur in the X direction.
    var blurX = newImage(target.width, target.height)
    for y in 0 ..< target.height:
      for x in 0 ..< target.width:
        var values: array[4, uint32]
        for xb in -radius .. radius:
          let
            sample = target[x + xb, y]
            a = lookup[xb + radius].uint32
          values += sample * a
        blurX.setRgbaUnsafe(x, y, values.rgba())

    # Blur in the Y direction.
    for y in 0 ..< target.height:
      for x in 0 ..< target.width:
        var values: array[4, uint32]
        for yb in -radius .. radius:
          let
            sample = blurX[x, y + yb]
            a = lookup[yb + radius].uint32
          values += sample * a
        target.setRgbaUnsafe(x, y, values.rgba())

  else: # target is a Mask

    # Blur in the X direction.
    var blurX = newMask(target.width, target.height)
    for y in 0 ..< target.height:
      for x in 0 ..< target.width:
        var value: uint32
        for xb in -radius .. radius:
          var sample: uint32
          if target.inside(x + xb, y):
            sample = target.getValueUnsafe(x + xb, y)
          else:
            sample = offBounds
          let a = lookup[xb + radius].uint32
          value += sample * a
        blurX.setValueUnsafe(x, y, (value div 1024 div 255).uint8)

    # Blur in the Y direction and modify image.
    for y in 0 ..< target.height:
      for x in 0 ..< target.width:
        var value: uint32
        for yb in -radius .. radius:
          var sample: uint32
          if blurX.inside(x, y + yb):
            sample = blurX.getValueUnsafe(x, y + yb)
          else:
            sample = offBounds
          let a = lookup[yb + radius].uint32
          value += sample * a
        target.setValueUnsafe(x, y, (value div 1024 div 255).uint8)

proc newMask*(image: Image): Mask =
  ## Returns a new mask using the alpha values of the parameter image.
  result = newMask(image.width, image.height)

  var i: int
  when defined(amd64) and not defined(pixieNoSimd):
    for _ in countup(0, image.data.len - 16, 16):
      var
        a = mm_loadu_si128(image.data[i + 0].addr)
        b = mm_loadu_si128(image.data[i + 4].addr)
        c = mm_loadu_si128(image.data[i + 8].addr)
        d = mm_loadu_si128(image.data[i + 12].addr)

      a = packAlphaValues(a)
      b = packAlphaValues(b)
      c = packAlphaValues(c)
      d = packAlphaValues(d)

      b = mm_slli_si128(b, 4)
      c = mm_slli_si128(c, 8)
      d = mm_slli_si128(d, 12)

      mm_storeu_si128(
        result.data[i].addr,
        mm_or_si128(mm_or_si128(a, b), mm_or_si128(c, d))
      )

      i += 16

  for j in i ..< image.data.len:
    result.data[j] = image.data[j].a

proc getRgbaSmooth*(image: Image, x, y: float32): ColorRGBA =
  let
    minX = floor(x)
    minY = floor(y)
    diffX = x - minX
    diffY = y - minY
    x = minX.int
    y = minY.int

    x0y0 = image[x + 0, y + 0]
    x1y0 = image[x + 1, y + 0]
    x0y1 = image[x + 0, y + 1]
    x1y1 = image[x + 1, y + 1]

    bottomMix = lerp(x0y0, x1y0, diffX)
    topMix = lerp(x0y1, x1y1, diffX)

  lerp(bottomMix, topMix, diffY)

proc getRgbaSmoothWrapped*(image: Image, x, y: float32): ColorRGBA =
  let
    minX = floor(x)
    minY = floor(y)
    diffX = x - minX
    diffY = y - minY
    x = minX.int
    y = minY.int

    x0y0 = image[(x + 0) mod image.width, (y + 0) mod image.height]
    x1y0 = image[(x + 1) mod image.width, (y + 0) mod image.height]
    x0y1 = image[(x + 0) mod image.width, (y + 1) mod image.height]
    x1y1 = image[(x + 1) mod image.width, (y + 1) mod image.height]

    bottomMix = lerp(x0y0, x1y0, diffX)
    topMix = lerp(x0y1, x1y1, diffX)

  lerp(bottomMix, topMix, diffY)

proc drawCorrect(a, b: Image | Mask, mat = mat3(), blendMode = bmNormal) =
  ## Draws one image onto another using matrix with color blending.

  when type(a) is Image:
    let blender = blendMode.blender()
  else: # a is a Mask
    let masker = blendMode.masker()

  var
    matInv = mat.inverse()
    b = b

  block: # Shrink by 2 as needed
    var
      p = matInv * vec2(0 + h, 0 + h)
      dx = matInv * vec2(1 + h, 0 + h) - p
      dy = matInv * vec2(0 + h, 1 + h) - p
      minFilterBy2 = max(dx.length, dy.length)

    while minFilterBy2 > 2:
      b = b.minifyBy2()
      dx /= 2
      dy /= 2
      minFilterBy2 /= 2
      matInv = matInv * scale(vec2(0.5, 0.5))

  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      let
        samplePos = matInv * vec2(x.float32 + h, y.float32 + h)
        xFloat = samplePos.x - h
        yFloat = samplePos.y - h

      when type(a) is Image:
        let backdrop = a.getRgbaUnsafe(x, y)
        when type(b) is Image:
          let
            sample = b.getRgbaSmooth(xFloat, yFloat)
            blended = blender(backdrop, sample)
        else: # b is a Mask
          let
            sample = b.getValueSmooth(xFloat, yFloat)
            blended = blender(backdrop, rgba(0, 0, 0, sample))
        a.setRgbaUnsafe(x, y, blended)
      else: # a is a Mask
        let backdrop = a.getValueUnsafe(x, y)
        when type(b) is Image:
          let sample = b.getRgbaSmooth(xFloat, yFloat).a
        else: # b is a Mask
          let sample = b.getValueSmooth(xFloat, yFloat)
        a.setValueUnsafe(x, y, masker(backdrop, sample))

proc drawUber(a, b: Image | Mask, mat = mat3(), blendMode = bmNormal) =
  let
    corners = [
      mat * vec2(0, 0),
      mat * vec2(b.width.float32, 0),
      mat * vec2(b.width.float32, b.height.float32),
      mat * vec2(0, b.height.float32)
    ]
    perimeter = [
      segment(corners[0], corners[1]),
      segment(corners[1], corners[2]),
      segment(corners[2], corners[3]),
      segment(corners[3], corners[0])
    ]

  var
    matInv = mat.inverse()
    # Compute movement vectors
    p = matInv * vec2(0 + h, 0 + h)
    dx = matInv * vec2(1 + h, 0 + h) - p
    dy = matInv * vec2(0 + h, 1 + h) - p
    minFilterBy2 = max(dx.length, dy.length)
    b = b

  while minFilterBy2 > 2.0:
    b = b.minifyBy2()
    p /= 2
    dx /= 2
    dy /= 2
    minFilterBy2 /= 2
    matInv = matInv * scale(vec2(0.5, 0.5))

  let smooth = not(
    dx.length == 1.0 and
    dy.length == 1.0 and
    mat[2, 0].fractional == 0.0 and
    mat[2, 1].fractional == 0.0
  )

  when type(a) is Image:
    let blender = blendMode.blender()
  else: # a is a Mask
    let masker = blendMode.masker()

  # Determine where we should start and stop drawing in the y dimension
  var yMin, yMax: int
  if blendMode == bmIntersectMask:
    yMin = 0
    yMax = a.height
  else:
    yMin = a.height
    yMax = 0
    for segment in perimeter:
      yMin = min(yMin, segment.at.y.floor.int)
      yMax = max(yMax, segment.at.y.ceil.int)

  yMin = yMin.clamp(0, a.height)
  yMax = yMax.clamp(0, a.height)

  for y in yMin ..< yMax:
    # Determine where we should start and stop drawing in the x dimension
    var
      xMin = a.width
      xMax = 0
    for yOffset in [0.float32, 1]:
      let scanLine = Line(
        a: vec2(-1000, y.float32 + yOffset),
        b: vec2(1000, y.float32 + yOffset)
      )
      for segment in perimeter:
        var at: Vec2
        if scanline.intersects(segment, at) and segment.to != at:
          xMin = min(xMin, at.x.floor.int)
          xMax = max(xMax, at.x.ceil.int)

    xMin = xMin.clamp(0, a.width)
    xMax = xMax.clamp(0, a.width)

    if blendMode == bmIntersectMask:
      if xMin > 0:
        zeroMem(a.data[a.dataIndex(0, y)].addr, 4 * xMin)

    if smooth:
      for x in xMin ..< xMax:
        let
          srcPos = p + dx * x.float32 + dy * y.float32
          xFloat = srcPos.x - h
          yFloat = srcPos.y - h
        when type(a) is Image:
          let backdrop = a.getRgbaUnsafe(x, y)
          when type(b) is Image:
            let
              sample = b.getRgbaSmooth(xFloat, yFloat)
              blended = blender(backdrop, sample)
          else: # b is a Mask
            let
              sample = b.getValueSmooth(xFloat, yFloat)
              blended = blender(backdrop, rgba(0, 0, 0, sample))
          a.setRgbaUnsafe(x, y, blended)
        else: # a is a Mask
          let backdrop = a.getValueUnsafe(x, y)
          when type(b) is Image:
            let sample = b.getRgbaSmooth(xFloat, yFloat).a
          else: # b is a Mask
            let sample = b.getValueSmooth(xFloat, yFloat)
          a.setValueUnsafe(x, y, masker(backdrop, sample))
    else:
      var x = xMin
      when defined(amd64) and not defined(pixieNoSimd):
        if dx.x == 1 and dx.y == 0 and dy.x == 0 and dy.y == 1:
          # Check we are not rotated before using SIMD blends
          when type(a) is Image:
            if blendMode.hasSimdBlender():
              let blenderSimd = blendMode.blenderSimd()
              for _ in countup(x, xMax - 4, 4):
                let
                  srcPos = p + dx * x.float32 + dy * y.float32
                  sx = srcPos.x.int
                  sy = srcPos.y.int
                  backdrop = mm_loadu_si128(a.data[a.dataIndex(x, y)].addr)
                when type(b) is Image:
                  let source = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                else: # b is a Mask
                  # Need to move 4 mask values into the alpha slots
                  var source = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                  source = unpackAlphaValues(source)

                mm_storeu_si128(
                  a.data[a.dataIndex(x, y)].addr,
                  blenderSimd(backdrop, source)
                )
                x += 4

          else: # is a Mask
            if blendMode.hasSimdMasker():
              let maskerSimd = blendMode.maskerSimd()
              for _ in countup(x, xMax - 16, 16):
                let
                  srcPos = p + dx * x.float32 + dy * y.float32
                  sx = srcPos.x.int
                  sy = srcPos.y.int
                  backdrop = mm_loadu_si128(a.data[a.dataIndex(x, y)].addr)
                when type(b) is Image:
                  # Need to read 16 colors and pack their alpha values
                  var
                    i = mm_loadu_si128(b.data[b.dataIndex(sx + 0, sy)].addr)
                    j = mm_loadu_si128(b.data[b.dataIndex(sx + 4, sy)].addr)
                    k = mm_loadu_si128(b.data[b.dataIndex(sx + 8, sy)].addr)
                    l = mm_loadu_si128(b.data[b.dataIndex(sx + 12, sy)].addr)

                  i = packAlphaValues(i)
                  j = packAlphaValues(j)
                  k = packAlphaValues(k)
                  l = packAlphaValues(l)

                  j = mm_slli_si128(j, 4)
                  k = mm_slli_si128(k, 8)
                  l = mm_slli_si128(l, 12)

                  let source = mm_or_si128(mm_or_si128(i, j), mm_or_si128(k, l))
                else: # b is a Mask
                  let source = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)

                mm_storeu_si128(
                  a.data[a.dataIndex(x, y)].addr,
                  maskerSimd(backdrop, source)
                )
                x += 16

      for _ in x ..< xMax:
        let
          srcPos = p + dx * x.float32 + dy * y.float32
          xFloat = srcPos.x - h
          yFloat = srcPos.y - h

        when type(a) is Image:
          let backdrop = a.getRgbaUnsafe(x, y)
          when type(b) is Image:
            let
              sample = b.getRgbaUnsafe(xFloat.int, yFloat.int)
              blended = blender(backdrop, sample)
          else: # b is a Mask
            let
              sample = b.getValueUnsafe(xFloat.int, yFloat.int)
              blended = blender(backdrop, rgba(0, 0, 0, sample))
          a.setRgbaUnsafe(x, y, blended)
        else: # a is a Mask
          let backdrop = a.getValueUnsafe(x, y)
          when type(b) is Image:
            let sample = b.getRgbaUnsafe(xFloat.int, yFloat.int).a
          else: # b is a Mask
            let sample = b.getValueUnsafe(xFloat.int, yFloat.int)
          a.setValueUnsafe(x, y, masker(backdrop, sample))
        inc x

    if blendMode == bmIntersectMask:
      if a.width - xMax > 0:
        zeroMem(a.data[a.dataIndex(xMax, y)].addr, 4 * (a.width - xMax))

proc draw*(a, b: Image, mat: Mat3, blendMode = bmNormal) {.inline.} =
  ## Draws one image onto another using matrix with color blending.
  a.drawUber(b, mat, blendMode)

proc draw*(a, b: Image, pos = vec2(0, 0), blendMode = bmNormal) {.inline.} =
  a.draw(b, translate(pos), blendMode)

proc draw*(image: Image, mask: Mask, mat: Mat3, blendMode = bmMask) {.inline.} =
  image.drawUber(mask, mat, blendMode)

proc draw*(
  image: Image, mask: Mask, pos = vec2(0, 0), blendMode = bmMask
) {.inline.} =
  image.drawUber(mask, translate(pos), blendMode)

proc draw*(a, b: Mask, mat: Mat3, blendMode = bmMask) {.inline.} =
  a.drawUber(b, mat, blendMode)

proc draw*(a, b: Mask, pos = vec2(0, 0), blendMode = bmMask) {.inline.} =
  a.draw(b, translate(pos), blendMode)

proc draw*(mask: Mask, image: Image, mat: Mat3, blendMode = bmMask) {.inline.} =
  mask.drawUber(image, mat, blendMode)

proc draw*(
  mask: Mask, image: Image, pos = vec2(0, 0), blendMode = bmMask
) {.inline.} =
  mask.draw(image, translate(pos), blendMode)

proc resize*(srcImage: Image, width, height: int): Image =
  if width == srcImage.width and height == srcImage.height:
    result = srcImage.copy()
  else:
    result = newImage(width, height)
    result.draw(
      srcImage,
      scale(vec2(
        width.float32 / srcImage.width.float32,
        height.float32 / srcImage.height.float32
      )),
      bmOverwrite
    )

proc shift*(target: Image | Mask, offset: Vec2) =
  ## Shifts the target by offset.
  if offset != vec2(0, 0):
    let copy = target.copy() # Copy to read from

    # Reset target for being drawn to
    when type(target) is Image:
      target.fill(rgba(0, 0, 0, 0))
    else:
      target.fill(0)

    target.draw(copy, offset, bmOverwrite) # Draw copy at offset

proc shadow*(
  image: Image, offset: Vec2, spread, blur: float32, color: ColorRGBA
): Image =
  ## Create a shadow of the image with the offset, spread and blur.
  let mask = image.newMask()
  if offset != vec2(0, 0):
    mask.shift(offset)
  if spread > 0:
    mask.spread(spread)
  if blur > 0:
    mask.blur(blur)
  result = newImage(mask.width, mask.height)
  result.fill(color)
  result.draw(mask, blendMode = bmMask)

when defined(release):
  {.pop.}
