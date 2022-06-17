import blends, bumpy, chroma, common, masks, pixie/internal, vmath

when defined(amd64) and allowSimd:
  import nimsimd/sse2

const h = 0.5.float32

type
  Image* = ref object
    ## Image object that holds bitmap data in RGBA format.
    width*, height*: int
    data*: seq[ColorRGBX]

  UnsafeImage = distinct Image

when defined(release):
  {.push checks: off.}

proc newImage*(width, height: int): Image {.raises: [PixieError].} =
  ## Creates a new image with the parameter dimensions.
  if width <= 0 or height <= 0:
    raise newException(PixieError, "Image width and height must be > 0")

  result = Image()
  result.width = width
  result.height = height
  result.data = newSeq[ColorRGBX](width * height)

proc newImage*(mask: Mask): Image {.raises: [PixieError].} =
  result = newImage(mask.width, mask.height)
  var i: int
  when defined(amd64) and allowSimd:
    for _ in 0 ..< mask.data.len div 16:
      var alphas = mm_loadu_si128(mask.data[i].addr)
      for j in 0 ..< 4:
        var unpacked = unpackAlphaValues(alphas)
        unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 8))
        unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 16))
        mm_storeu_si128(result.data[i + j * 4].addr, unpacked)
        alphas = mm_srli_si128(alphas, 4)
      i += 16

  for j in i ..< mask.data.len:
    let v = mask.data[j]
    result.data[j] = rgbx(v, v, v, v)

proc copy*(image: Image): Image {.raises: [PixieError].} =
  ## Copies the image data into a new image.
  result = newImage(image.width, image.height)
  result.data = image.data

proc `$`*(image: Image): string {.raises: [].} =
  ## Prints the image size.
  "<Image " & $image.width & "x" & $image.height & ">"

proc inside*(image: Image, x, y: int): bool {.inline, raises: [].} =
  ## Returns true if (x, y) is inside the image.
  x >= 0 and x < image.width and y >= 0 and y < image.height

proc dataIndex*(image: Image, x, y: int): int {.inline, raises: [].} =
  image.width * y + x

template unsafe*(src: Image): UnsafeImage =
  cast[UnsafeImage](src)

template `[]`*(view: UnsafeImage, x, y: int): var ColorRGBX =
  ## Gets a color from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will cause unsafe memory reads.
  cast[Image](view).data[cast[Image](view).dataIndex(x, y)]

template `[]=`*(view: UnsafeImage, x, y: int, color: ColorRGBX) =
  ## Sets a color from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will cause unsafe memory writes.
  cast[Image](view).data[cast[Image](view).dataIndex(x, y)] = color

proc `[]`*(image: Image, x, y: int): ColorRGBX {.inline, raises: [].} =
  ## Gets a pixel at (x, y) or returns transparent black if outside of bounds.
  if image.inside(x, y):
    return image.unsafe[x, y]

proc `[]=`*(image: Image, x, y: int, color: SomeColor) {.inline, raises: [].} =
  ## Sets a pixel at (x, y) or does nothing if outside of bounds.
  if image.inside(x, y):
    image.unsafe[x, y] = color.asRgbx()

proc getColor*(image: Image, x, y: int): Color {.inline, raises: [].} =
  ## Gets a color at (x, y) or returns transparent black if outside of bounds.
  image[x, y].color()

proc setColor*(image: Image, x, y: int, color: Color) {.inline, raises: [].} =
  ## Sets a color at (x, y) or does nothing if outside of bounds.
  image[x, y] = color.rgbx()

proc fill*(image: Image, color: SomeColor) {.inline, raises: [].} =
  ## Fills the image with the color.
  fillUnsafe(image.data, color, 0, image.data.len)

proc isOneColor*(image: Image): bool {.raises: [].} =
  ## Checks if the entire image is the same color.
  result = true

  let color = image.data[0]

  var i: int
  when defined(amd64) and allowSimd:
    let colorVec = mm_set1_epi32(cast[int32](color))
    for _ in 0 ..< image.data.len div 8:
      let
        values0 = mm_loadu_si128(image.data[i + 0].addr)
        values1 = mm_loadu_si128(image.data[i + 4].addr)
        mask0 = mm_movemask_epi8(mm_cmpeq_epi8(values0, colorVec))
        mask1 = mm_movemask_epi8(mm_cmpeq_epi8(values1, colorVec))
      if mask0 != 0xffff or mask1 != 0xffff:
        return false
      i += 8

  for j in i ..< image.data.len:
    if image.data[j] != color:
      return false

proc isTransparent*(image: Image): bool {.raises: [].} =
  ## Checks if this image is fully transparent or not.
  result = true

  var i: int
  when defined(amd64) and allowSimd:
    let vecZero = mm_setzero_si128()
    for _ in 0 ..< image.data.len div 16:
      let
        values0 = mm_loadu_si128(image.data[i + 0].addr)
        values1 = mm_loadu_si128(image.data[i + 4].addr)
        values2 = mm_loadu_si128(image.data[i + 8].addr)
        values3 = mm_loadu_si128(image.data[i + 12].addr)
        values01 = mm_or_si128(values0, values1)
        values23 = mm_or_si128(values2, values3)
        values = mm_or_si128(values01, values23)
      if mm_movemask_epi8(mm_cmpeq_epi8(values, vecZero)) != 0xffff:
        return false
      i += 16

  for j in i ..< image.data.len:
    if image.data[j].a != 0:
      return false

proc isOpaque*(image: Image): bool {.raises: [].} =
  ## Checks if the entire image is opaque (alpha values are all 255).
  isOpaque(image.data, 0, image.data.len)

proc flipHorizontal*(image: Image) {.raises: [].} =
  ## Flips the image around the Y axis.
  let w = image.width div 2
  for y in 0 ..< image.height:
    for x in 0 ..< w:
      swap(
        image.data[image.dataIndex(x, y)],
        image.data[image.dataIndex(image.width - x - 1, y)]
      )

proc flipVertical*(image: Image) {.raises: [].} =
  ## Flips the image around the X axis.
  let h = image.height div 2
  for y in 0 ..< h:
    for x in 0 ..< image.width:
      swap(
        image.data[image.dataIndex(x, y)],
        image.data[image.dataIndex(x, image.height - y - 1)]
      )

proc rotate90*(image: Image) {.raises: [PixieError].} =
  ## Rotates the image 90 degrees clockwise.
  let rotated = newImage(image.height, image.width)
  for y in 0 ..< rotated.height:
    for x in 0 ..< rotated.width:
      rotated.data[rotated.dataIndex(x, y)] =
        image.data[image.dataIndex(y, image.height - x - 1)]
  image.width = rotated.width
  image.height = rotated.height
  image.data = move rotated.data

proc subImage*(image: Image, x, y, w, h: int): Image {.raises: [PixieError].} =
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

proc diff*(master, image: Image): (float32, Image) {.raises: [PixieError].} =
  ## Compares the parameters and returns a score and image of the difference.
  let
    w = max(master.width, image.width)
    h = max(master.height, image.height)
    diffImage = newImage(w, h)

  var
    diffScore = 0
    diffTotal = 0
  for x in 0 ..< w:
    for y in 0 ..< h:
      let
        m = master[x, y]
        u = image[x, y]
        diff = (m.r.int - u.r.int) + (m.g.int - u.g.int) + (m.b.int - u.b.int)
      var c: ColorRGBX
      c.r = abs(m.a.int - u.a.int).clamp(0, 255).uint8
      c.g = diff.clamp(0, 255).uint8
      c.b = (-diff).clamp(0, 255).uint8
      c.a = 255
      diffImage.unsafe[x, y] = c
      diffScore += abs(m.r.int - u.r.int) +
        abs(m.g.int - u.g.int) +
        abs(m.b.int - u.b.int) +
        abs(m.a.int - u.a.int)
      diffTotal += 255 * 4

  (100 * diffScore.float32 / diffTotal.float32, diffImage)

proc minifyBy2*(image: Image, power = 1): Image {.raises: [PixieError].} =
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
    for y in 0 ..< resultEvenHeight:
      var x: int
      when defined(amd64) and allowSimd:
        let
          oddMask = mm_set1_epi16(cast[int16](0xff00))
          first32 = cast[M128i]([uint32.high, 0, 0, 0])
        for _ in countup(0, resultEvenWidth - 4, 2):
          let
            top = mm_loadu_si128(src.data[src.dataIndex(x * 2, y * 2 + 0)].addr)
            btm = mm_loadu_si128(src.data[src.dataIndex(x * 2, y * 2 + 1)].addr)
            topShifted = mm_srli_si128(top, 4)
            btmShifted = mm_srli_si128(btm, 4)

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

            # merged [0, 1, 2, 3] has the correct values for the next two pixels
            # at index 0 and 2 so shift those into position and store

            zero = mm_and_si128(merged, first32)
            two = mm_and_si128(mm_srli_si128(merged, 8), first32)
            zeroTwo = mm_or_si128(zero, mm_slli_si128(two, 4))

          mm_storeu_si128(result.data[result.dataIndex(x, y)].addr, zeroTwo)
          x += 2

      for x in x ..< resultEvenWidth:
        let
          a = src.unsafe[x * 2 + 0, y * 2 + 0]
          b = src.unsafe[x * 2 + 1, y * 2 + 0]
          c = src.unsafe[x * 2 + 1, y * 2 + 1]
          d = src.unsafe[x * 2 + 0, y * 2 + 1]
          mixed = rgbx(
            ((a.r.uint32 + b.r + c.r + d.r) div 4).uint8,
            ((a.g.uint32 + b.g + c.g + d.g) div 4).uint8,
            ((a.b.uint32 + b.b + c.b + d.b) div 4).uint8,
            ((a.a.uint32 + b.a + c.a + d.a) div 4).uint8
          )
        result.unsafe[x, y] = mixed

      if srcWidthIsOdd:
        let rgbx = mix(
          src.unsafe[src.width - 1, y * 2 + 0],
          src.unsafe[src.width - 1, y * 2 + 1],
          0.5
        ) * 0.5
        result.unsafe[result.width - 1, y] = rgbx

    if srcHeightIsOdd:
      for x in 0 ..< resultEvenWidth:
        let rgbx = mix(
          src.unsafe[x * 2 + 0, src.height - 1],
          src.unsafe[x * 2 + 1, src.height - 1],
          0.5
        ) * 0.5
        result.unsafe[x, result.height - 1] = rgbx

      if srcWidthIsOdd:
        result.unsafe[result.width - 1, result.height - 1] =
          src.unsafe[src.width - 1, src.height - 1] * 0.25

    # Set src as this result for if we do another power
    src = result

proc magnifyBy2*(image: Image, power = 1): Image {.raises: [PixieError].} =
  ## Scales image up by 2 ^ power.
  if power < 0:
    raise newException(PixieError, "Cannot magnifyBy2 with negative power")

  let scale = 2 ^ power
  result = newImage(image.width * scale, image.height * scale)

  for y in 0 ..< image.height:
    # Write one row of pixels duplicated by scale
    var x: int
    when defined(amd64) and allowSimd:
      if scale == 2:
        while x <= image.width - 4:
          let
            values = mm_loadu_si128(image.data[image.dataIndex(x, y)].addr)
            lo = mm_unpacklo_epi32(values, mm_setzero_si128())
            hi = mm_unpackhi_epi32(values, mm_setzero_si128())
          mm_storeu_si128(
            result.data[result.dataIndex(x * scale + 0, y * scale)].addr,
            mm_or_si128(lo, mm_slli_si128(lo, 4))
          )
          mm_storeu_si128(
            result.data[result.dataIndex(x * scale + 4, y * scale)].addr,
            mm_or_si128(hi, mm_slli_si128(hi, 4))
          )
          x += 4
    for x in x ..< image.width:
      let
        rgbx = image.unsafe[x, y]
        resultIdx = result.dataIndex(x * scale, y * scale)
      for i in 0 ..< scale:
        result.data[resultIdx + i] = rgbx
    # Copy that row of pixels into (scale - 1) more rows
    let rowStart = result.dataIndex(0, y * scale)
    for i in 1 ..< scale:
      copyMem(
        result.data[rowStart + result.width * i].addr,
        result.data[rowStart].addr,
        result.width * 4
      )

proc applyOpacity*(target: Image | Mask, opacity: float32) {.raises: [].} =
  ## Multiplies alpha of the image by opacity.
  let opacity = round(255 * opacity).uint16
  if opacity == 255:
    return

  if opacity == 0:
    when type(target) is Image:
      target.fill(rgbx(0, 0, 0, 0))
    else:
      target.fill(0)
    return

  var i: int
  when defined(amd64) and allowSimd:
    when type(target) is Image:
      let byteLen = target.data.len * 4
    else:
      let byteLen = target.data.len

    let
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))
      zeroVec = mm_setzero_si128()
      opacityVec = mm_slli_epi16(mm_set1_epi16(cast[int16](opacity)), 8)
    for _ in 0 ..< byteLen div 16:
      when type(target) is Image:
        let index = i div 4
      else:
        let index = i

      let values = mm_loadu_si128(target.data[index].addr)

      if mm_movemask_epi8(mm_cmpeq_epi16(values, zeroVec)) != 0xffff:
        var
          valuesEven = mm_slli_epi16(mm_andnot_si128(oddMask, values), 8)
          valuesOdd = mm_and_si128(values, oddMask)

        # values * opacity
        valuesEven = mm_mulhi_epu16(valuesEven, opacityVec)
        valuesOdd = mm_mulhi_epu16(valuesOdd, opacityVec)

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
      var rgbx = target.data[j]
      rgbx.r = ((rgbx.r * opacity) div 255).uint8
      rgbx.g = ((rgbx.g * opacity) div 255).uint8
      rgbx.b = ((rgbx.b * opacity) div 255).uint8
      rgbx.a = ((rgbx.a * opacity) div 255).uint8
      target.data[j] = rgbx
  else:
    for j in i ..< target.data.len:
      target.data[j] = ((target.data[j] * opacity) div 255).uint8

proc invert*(target: Image) {.raises: [].} =
  ## Inverts all of the colors and alpha.
  var i: int
  when defined(amd64) and allowSimd:
    let vec255 = mm_set1_epi8(cast[int8](255))
    let byteLen = target.data.len * 4
    for _ in 0 ..< byteLen div 16:
      let index = i div 4
      var values = mm_loadu_si128(target.data[index].addr)
      values = mm_sub_epi8(vec255, values)
      mm_storeu_si128(target.data[index].addr, values)
      i += 16

  for j in i div 4 ..< target.data.len:
    var rgba = target.data[j]
    rgba.r = 255 - rgba.r
    rgba.g = 255 - rgba.g
    rgba.b = 255 - rgba.b
    rgba.a = 255 - rgba.a
    target.data[j] = rgba

  # Inverting rgbx(50, 100, 150, 200) becomes rgbx(205, 155, 105, 55). This
  # is not a valid premultiplied alpha color.
  # We need to convert back to premultiplied alpha after inverting.
  target.data.toPremultipliedAlpha()

proc blur*(
  image: Image, radius: float32, outOfBounds: SomeColor = color(0, 0, 0, 0)
) {.raises: [PixieError].} =
  ## Applies Gaussian blur to the image given a radius.
  let radius = round(radius).int
  if radius == 0:
    return
  if radius < 0:
    raise newException(PixieError, "Cannot apply negative blur")

  let
    kernel = gaussianKernel(radius)
    outOfBounds = outOfBounds.asRgbx()

  proc `*`(sample: ColorRGBX, a: uint32): array[4, uint32] {.inline.} =
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

  template rgbx(values: array[4, uint32]): ColorRGBX =
    rgbx(
      (values[0] div 256 div 255).uint8,
      (values[1] div 256 div 255).uint8,
      (values[2] div 256 div 255).uint8,
      (values[3] div 256 div 255).uint8
    )

  # Blur in the X direction. Store with dimensions swapped for reading later.
  let blurX = newImage(image.height, image.width)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var values: array[4, uint32]
      for xx in x - radius ..< min(x + radius, 0):
        values += outOfBounds * kernel[xx - x + radius]
      for xx in max(x - radius, 0) .. min(x + radius, image.width - 1):
        values += image.unsafe[xx, y] * kernel[xx - x + radius]
      for xx in max(x - radius, image.width) .. x + radius:
        values += outOfBounds * kernel[xx - x + radius]
      blurX.unsafe[y, x] = rgbx(values)

  # Blur in the Y direction.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var values: array[4, uint32]
      for yy in y - radius ..< min(y + radius, 0):
        values += outOfBounds * kernel[yy - y + radius]
      for yy in max(y - radius, 0) .. min(y + radius, image.height - 1):
        values += blurX.unsafe[yy, x] * kernel[yy - y + radius]
      for yy in max(y - radius, image.height) .. y + radius:
        values += outOfBounds * kernel[yy - y + radius]
      image.unsafe[x, y] = rgbx(values)

proc newMask*(image: Image): Mask {.raises: [PixieError].} =
  ## Returns a new mask using the alpha values of the image.
  result = newMask(image.width, image.height)

  var i: int
  when defined(amd64) and allowSimd:
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

  for j in i ..< image.data.len:
    result.data[j] = image.data[j].a

proc getRgbaSmooth*(
  image: Image, x, y: float32, wrapped = false
): ColorRGBX {.raises: [].} =
  ## Gets a interpolated color with float point coordinates.
  ## Pixels outside the image are transparent.
  let
    x0 = x.floor.int
    y0 = y.floor.int
    x1 = x0 + 1
    y1 = y0 + 1
    xFractional = x - x.floor
    yFractional = y - y.floor

  var x0y0, x1y0, x0y1, x1y1: ColorRGBX
  if wrapped:
    x0y0 = image.unsafe[x0 mod image.width, y0 mod image.height]
    x1y0 = image.unsafe[x1 mod image.width, y0 mod image.height]
    x0y1 = image.unsafe[x0 mod image.width, y1 mod image.height]
    x1y1 = image.unsafe[x1 mod image.width, y1 mod image.height]
  else:
    x0y0 = image[x0, y0]
    x1y0 = image[x1, y0]
    x0y1 = image[x0, y1]
    x1y1 = image[x1, y1]

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

proc drawCorrect(
  a, b: Image | Mask, transform = mat3(), blendMode = NormalBlend, tiled = false
) {.raises: [PixieError].} =
  ## Draws one image onto another using matrix with color blending.

  when type(a) is Image:
    let blender = blendMode.blender()
  else: # a is a Mask
    let masker = blendMode.masker()

  var
    inverseTransform = transform.inverse()
    # Compute movement vectors
    p = inverseTransform * vec2(0 + h, 0 + h)
    dx = inverseTransform * vec2(1 + h, 0 + h) - p
    dy = inverseTransform * vec2(0 + h, 1 + h) - p
    filterBy2 = max(dx.length, dy.length)
    b = b

  while filterBy2 >= 2.0:
    b = b.minifyBy2()
    p /= 2
    dx /= 2
    dy /= 2
    filterBy2 /= 2
    inverseTransform = scale(vec2(1/2, 1/2)) * inverseTransform

  while filterBy2 <= 0.5:
    b = b.magnifyBy2()
    p *= 2
    dx *= 2
    dy *= 2
    filterBy2 *= 2
    inverseTransform = scale(vec2(2, 2)) * inverseTransform

  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      let
        samplePos = inverseTransform * vec2(x.float32 + h, y.float32 + h)
        xFloat = samplePos.x - h
        yFloat = samplePos.y - h

      when type(a) is Image:
        let backdrop = a.unsafe[x, y]
        when type(b) is Image:
          let
            sample = b.getRgbaSmooth(xFloat, yFloat, tiled)
            blended = blender(backdrop, sample)
        else: # b is a Mask
          let
            sample = b.getValueSmooth(xFloat, yFloat)
            blended = blender(backdrop, rgbx(0, 0, 0, sample))
        a.unsafe[x, y] = blended
      else: # a is a Mask
        let backdrop = a.unsafe[x, y]
        when type(b) is Image:
          let sample = b.getRgbaSmooth(xFloat, yFloat, tiled).a
        else: # b is a Mask
          let sample = b.getValueSmooth(xFloat, yFloat)
        a.setValueUnsafe(x, y, masker(backdrop, sample))

proc drawUber(
  a, b: Image | Mask, transform = mat3(), blendMode: BlendMode
) {.raises: [PixieError].} =
  let
    corners = [
      transform * vec2(0, 0),
      transform * vec2(b.width.float32, 0),
      transform * vec2(b.width.float32, b.height.float32),
      transform * vec2(0, b.height.float32)
    ]
    perimeter = [
      segment(corners[0], corners[1]),
      segment(corners[1], corners[2]),
      segment(corners[2], corners[3]),
      segment(corners[3], corners[0])
    ]

  var
    inverseTransform = transform.inverse()
    # Compute movement vectors
    p = inverseTransform * vec2(0 + h, 0 + h)
    dx = inverseTransform * vec2(1 + h, 0 + h) - p
    dy = inverseTransform * vec2(0 + h, 1 + h) - p
    filterBy2 = max(dx.length, dy.length)
    b = b

  while filterBy2 >= 2.0:
    b = b.minifyBy2()
    p /= 2
    dx /= 2
    dy /= 2
    filterBy2 /= 2

  while filterBy2 <= 0.5:
    b = b.magnifyBy2()
    p *= 2
    dx *= 2
    dy *= 2
    filterBy2 *= 2

  let
    hasRotationOrScaling = not(dx == vec2(1, 0) and dy == vec2(0, 1))
    smooth = not(
      dx.length == 1.0 and
      dy.length == 1.0 and
      transform[2, 0].fractional == 0.0 and
      transform[2, 1].fractional == 0.0
    )

  # Determine where we should start and stop drawing in the y dimension
  var
    yMin = a.height
    yMax = 0
  for segment in perimeter:
    yMin = min(yMin, segment.at.y.floor.int)
    yMax = max(yMax, segment.at.y.ceil.int)
  yMin = yMin.clamp(0, a.height)
  yMax = yMax.clamp(0, a.height)

  when type(a) is Image:
    let blender = blendMode.blender()
  else: # a is a Mask
    let masker = blendMode.masker()

  if blendMode == MaskBlend:
    if yMin > 0:
      zeroMem(a.data[0].addr, 4 * yMin * a.width)

  for y in yMin ..< yMax:
    # Determine where we should start and stop drawing in the x dimension
    var
      xMin = a.width.float32
      xMax = 0.float32
    for yOffset in [0.float32, 1]:
      let scanLine = Line(
        a: vec2(-1000, y.float32 + yOffset),
        b: vec2(1000, y.float32 + yOffset)
      )
      for segment in perimeter:
        var at: Vec2
        if scanline.intersects(segment, at) and segment.to != at:
          xMin = min(xMin, at.x)
          xMax = max(xMax, at.x)

    var xStart, xStop: int
    if hasRotationOrScaling or smooth:
      xStart = xMin.floor.int
      xStop = xMax.ceil.int
    else:
      # Rotation of 360 degrees can cause knife-edge issues with floor and ceil
      xStart = xMin.round().int
      xStop = xMax.round().int
    xStart = xStart.clamp(0, a.width)
    xStop = xStop.clamp(0, a.width)

    # Skip this row if there is nothing in-bounds to draw
    if xStart == a.width or xStop == 0:
      continue

    if blendMode == MaskBlend:
      if xStart > 0:
        zeroMem(a.data[a.dataIndex(0, y)].addr, 4 * xStart)

    if smooth:
      var srcPos = p + dx * xStart.float32 + dy * y.float32
      srcPos = vec2(srcPos.x - h, srcPos.y - h)

      for x in xStart ..< xStop:
        when type(a) is Image:
          let backdrop = a.unsafe[x, y]
          when type(b) is Image:
            let
              sample = b.getRgbaSmooth(srcPos.x, srcPos.y)
              blended = blender(backdrop, sample)
          else: # b is a Mask
            let
              sample = b.getValueSmooth(srcPos.x, srcPos.y)
              blended = blender(backdrop, rgbx(0, 0, 0, sample))
          a.unsafe[x, y] = blended
        else: # a is a Mask
          let backdrop = a.unsafe[x, y]
          when type(b) is Image:
            let sample = b.getRgbaSmooth(srcPos.x, srcPos.y).a
          else: # b is a Mask
            let sample = b.getValueSmooth(srcPos.x, srcPos.y)
          a.unsafe[x, y] = masker(backdrop, sample)

        srcPos += dx

    else:
      var x = xStart
      if not hasRotationOrScaling:
        let
          srcPos = p + dx * x.float32 + dy * y.float32
          sy = srcPos.y.int
        var sx = srcPos.x.int

        when type(a) is Image and type(b) is Image:
          if blendMode in {NormalBlend, OverwriteBlend} and
            isOpaque(b.data, b.dataIndex(sx, sy), xStop - xStart):
            copyMem(
              a.data[a.dataIndex(x, y)].addr,
              b.data[b.dataIndex(sx, sy)].addr,
              (xStop - xStart) * 4
            )
            continue

        when defined(amd64) and allowSimd:
          case blendMode:
          of OverwriteBlend:
            for _ in 0 ..< (xStop - xStart) div 16:
              when type(a) is Image:
                when type(b) is Image:
                  for q in [0, 4, 8, 12]:
                    let sourceVec = mm_loadu_si128(b.data[b.dataIndex(sx + q, sy)].addr)
                    mm_storeu_si128(a.data[a.dataIndex(x + q, y)].addr, sourceVec)
                else: # b is a Mask
                  var values = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                  for q in [0, 4, 8, 12]:
                    let sourceVec = unpackAlphaValues(values)
                    mm_storeu_si128(a.data[a.dataIndex(x + q, y)].addr, sourceVec)
                    # Shuffle 32 bits off for the next iteration
                    values = mm_srli_si128(values, 4)
              else: # a is a Mask
                when type(b) is Image:
                  var
                    i = mm_loadu_si128(b.data[b.dataIndex(sx + 0, sy)].addr)
                    j = mm_loadu_si128(b.data[b.dataIndex(sx + 4, sy)].addr)
                    k = mm_loadu_si128(b.data[b.dataIndex(sx + 8, sy)].addr)
                    l = mm_loadu_si128(b.data[b.dataIndex(sx + 12, sy)].addr)
                  let sourceVec = pack4xAlphaValues(i, j, k, l)
                else: # b is a Mask
                  let sourceVec = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                mm_storeu_si128(a.data[a.dataIndex(x, y)].addr, sourceVec)
              x += 16
              sx += 16
          of NormalBlend:
            let vec255 = mm_set1_epi32(cast[int32](uint32.high))
            for _ in 0 ..< (xStop - xStart) div 16:
              when type(a) is Image:
                when type(b) is Image:
                  for q in [0, 4, 8, 12]:
                    let
                      sourceVec = mm_loadu_si128(b.data[b.dataIndex(sx + q, sy)].addr)
                      eqZer0 = mm_cmpeq_epi8(sourceVec, mm_setzero_si128())
                    if mm_movemask_epi8(eqZer0) != 0xffff:
                      let eq255 = mm_cmpeq_epi8(sourceVec, vec255)
                      if (mm_movemask_epi8(eq255) and 0x8888) == 0x8888:
                        mm_storeu_si128(a.data[a.dataIndex(x + q, y)].addr, sourceVec)
                      else:
                        let
                          backdropIdx = a.dataIndex(x + q, y)
                          backdropVec = mm_loadu_si128(a.data[backdropIdx].addr)
                        mm_storeu_si128(
                          a.data[backdropIdx].addr,
                          blendNormalSimd(backdropVec, sourceVec)
                        )
                else: # b is a Mask
                  var values = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                  for q in [0, 4, 8, 12]:
                    let
                      sourceVec = unpackAlphaValues(values)
                      eqZer0 = mm_cmpeq_epi8(sourceVec, mm_setzero_si128())
                    if mm_movemask_epi8(eqZer0) != 0xffff:
                      let eq255 = mm_cmpeq_epi8(sourceVec, vec255)
                      if (mm_movemask_epi8(eq255) and 0x8888) == 0x8888:
                        discard
                      else:
                        let
                          backdropIdx = a.dataIndex(x + q, y)
                          backdropVec = mm_loadu_si128(a.data[backdropIdx].addr)
                        mm_storeu_si128(
                          a.data[backdropIdx].addr,
                          blendNormalSimd(backdropVec, sourceVec)
                        )
                    # Shuffle 32 bits off for the next iteration
                    values = mm_srli_si128(values, 4)
              else: # a is a Mask
                let backdropVec = mm_loadu_si128(a.data[a.dataIndex(x, y)].addr)
                when type(b) is Image:
                  var
                    i = mm_loadu_si128(b.data[b.dataIndex(sx + 0, sy)].addr)
                    j = mm_loadu_si128(b.data[b.dataIndex(sx + 4, sy)].addr)
                    k = mm_loadu_si128(b.data[b.dataIndex(sx + 8, sy)].addr)
                    l = mm_loadu_si128(b.data[b.dataIndex(sx + 12, sy)].addr)
                  let sourceVec = pack4xAlphaValues(i, j, k, l)
                else: # b is a Mask
                  let sourceVec = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                mm_storeu_si128(
                  a.data[a.dataIndex(x, y)].addr,
                  maskBlendNormalSimd(backdropVec, sourceVec)
                )
              x += 16
              sx += 16
          of MaskBlend:
            let vec255 = mm_set1_epi32(cast[int32](uint32.high))
            for _ in 0 ..< (xStop - xStart) div 16:
              when type(a) is Image:
                when type(b) is Image:
                  for q in [0, 4, 8, 12]:
                    let
                      sourceVec = mm_loadu_si128(b.data[b.dataIndex(sx + q, sy)].addr)
                      eqZer0 = mm_cmpeq_epi8(sourceVec, mm_setzero_si128())
                    if mm_movemask_epi8(eqZer0) == 0xffff:
                      mm_storeu_si128(
                        a.data[a.dataIndex(x + q, y)].addr,
                        mm_setzero_si128()
                      )
                    elif mm_movemask_epi8(mm_cmpeq_epi8(sourceVec, vec255)) != 0xffff:
                      let backdropVec = mm_loadu_si128(a.data[a.dataIndex(x + q, y)].addr)
                      mm_storeu_si128(
                        a.data[a.dataIndex(x + q, y)].addr,
                        blendMaskSimd(backdropVec, sourceVec)
                      )
                else: # b is a Mask
                  var values = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                  for q in [0, 4, 8, 12]:
                    let
                      sourceVec = unpackAlphaValues(values)
                      eqZer0 = mm_cmpeq_epi8(sourceVec, mm_setzero_si128())
                      eq255 = mm_cmpeq_epi8(sourceVec, vec255)
                    if mm_movemask_epi8(eqZer0) == 0xffff:
                      mm_storeu_si128(
                        a.data[a.dataIndex(x + q, y)].addr,
                        mm_setzero_si128()
                      )
                    elif (mm_movemask_epi8(eq255) and 0x8888) != 0x8888:
                      let backdropVec = mm_loadu_si128(a.data[a.dataIndex(x + q, y)].addr)
                      mm_storeu_si128(
                        a.data[a.dataIndex(x + q, y)].addr,
                        blendMaskSimd(backdropVec, sourceVec)
                      )
                    # Shuffle 32 bits off for the next iteration
                    values = mm_srli_si128(values, 4)
              else: # a is a Mask
                let backdropVec = mm_loadu_si128(a.data[a.dataIndex(x, y)].addr)
                when type(b) is Image:
                  var
                    i = mm_loadu_si128(b.data[b.dataIndex(sx + 0, sy)].addr)
                    j = mm_loadu_si128(b.data[b.dataIndex(sx + 4, sy)].addr)
                    k = mm_loadu_si128(b.data[b.dataIndex(sx + 8, sy)].addr)
                    l = mm_loadu_si128(b.data[b.dataIndex(sx + 12, sy)].addr)
                  let sourceVec = pack4xAlphaValues(i, j, k, l)
                else: # b is a Mask
                  let sourceVec = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                mm_storeu_si128(
                  a.data[a.dataIndex(x, y)].addr,
                  maskBlendMaskSimd(backdropVec, sourceVec)
                )
              x += 16
              sx += 16
          else:
            when type(a) is Image:
              if blendMode.hasSimdBlender():
                let blenderSimd = blendMode.blenderSimd()
                for _ in 0 ..< (xStop - xStart) div 16:
                  when type(b) is Image:
                    for q in [0, 4, 8, 12]:
                      let
                        backdrop = mm_loadu_si128(a.data[a.dataIndex(x + q, y)].addr)
                        source = mm_loadu_si128(b.data[b.dataIndex(sx + q, sy)].addr)
                      mm_storeu_si128(
                        a.data[a.dataIndex(x + q, y)].addr,
                        blenderSimd(backdrop, source)
                      )
                  else: # b is a Mask
                    var values = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)
                    for q in [0, 4, 8, 12]:
                      let
                        backdrop = mm_loadu_si128(a.data[a.dataIndex(x + q, y)].addr)
                        source = unpackAlphaValues(values)
                      mm_storeu_si128(
                        a.data[a.dataIndex(x + q, y)].addr,
                        blenderSimd(backdrop, source)
                      )
                      # Shuffle 32 bits off for the next iteration
                      values = mm_srli_si128(values, 4)
                  x += 16
                  sx += 16
            else: # is a Mask
              if blendMode.hasSimdMasker():
                let maskerSimd = blendMode.maskerSimd()
                for _ in 0 ..< (xStop - xStart) div 16:
                  let backdrop = mm_loadu_si128(a.data[a.dataIndex(x, y)].addr)
                  when type(b) is Image:
                    # Need to read 16 colors and pack their alpha values
                    let
                      i = mm_loadu_si128(b.data[b.dataIndex(sx + 0, sy)].addr)
                      j = mm_loadu_si128(b.data[b.dataIndex(sx + 4, sy)].addr)
                      k = mm_loadu_si128(b.data[b.dataIndex(sx + 8, sy)].addr)
                      l = mm_loadu_si128(b.data[b.dataIndex(sx + 12, sy)].addr)
                      source = pack4xAlphaValues(i, j, k, l)
                  else: # b is a Mask
                    let source = mm_loadu_si128(b.data[b.dataIndex(sx, sy)].addr)

                  mm_storeu_si128(
                    a.data[a.dataIndex(x, y)].addr,
                    maskerSimd(backdrop, source)
                  )
                  x += 16
                  sx += 16

      var srcPos = p + dx * x.float32 + dy * y.float32
      srcPos = vec2(
        clamp(srcPos.x, 0, b.width.float32),
        clamp(srcPos.y, 0, b.height.float32)
      )

      case blendMode:
      of OverwriteBlend:
        for x in x ..< xStop:
          let samplePos = ivec2((srcPos.x - h).int32, (srcPos.y - h).int32)
          when type(a) is Image:
            when type(b) is Image:
              let source = b.unsafe[samplePos.x, samplePos.y]
            else: # b is a Mask
              let source = rgbx(0, 0, 0, b.unsafe[samplePos.x, samplePos.y])
            if source.a > 0:
              a.unsafe[x, y] = source
          else: # a is a Mask
            when type(b) is Image:
              let source = b.unsafe[samplePos.x, samplePos.y].a
            else: # b is a Mask
              let source = b.unsafe[samplePos.x, samplePos.y]
            if source > 0:
              a.unsafe[x, y] = source
          srcPos += dx
      of NormalBlend:
        for x in x ..< xStop:
          let samplePos = ivec2((srcPos.x - h).int32, (srcPos.y - h).int32)
          when type(a) is Image:
            when type(b) is Image:
              let source = b.unsafe[samplePos.x, samplePos.y]
            else: # b is a Mask
              let source = rgbx(0, 0, 0, b.unsafe[samplePos.x, samplePos.y])
            if source.a > 0:
              if source.a == 255:
                a.unsafe[x, y] = source
              else:
                let backdrop = a.unsafe[x, y]
                a.unsafe[x, y] = blendNormal(backdrop, source)
          else: # a is a Mask
            when type(b) is Image:
              let source = b.unsafe[samplePos.x, samplePos.y].a
            else: # b is a Mask
              let source = b.unsafe[samplePos.x, samplePos.y]
            if source > 0:
              if source == 255:
                a.unsafe[x, y] = source
              else:
                let backdrop = a.unsafe[x, y]
                a.unsafe[x, y] = blendAlpha(backdrop, source)
          srcPos += dx
      of MaskBlend:
        for x in x ..< xStop:
          let samplePos = ivec2((srcPos.x - h).int32, (srcPos.y - h).int32)
          when type(a) is Image:
            when type(b) is Image:
              let source = b.unsafe[samplePos.x, samplePos.y]
            else: # b is a Mask
              let source = rgbx(0, 0, 0, b.unsafe[samplePos.x, samplePos.y])
            if source.a == 0:
              a.unsafe[x, y] = rgbx(0, 0, 0, 0)
            elif source.a != 255:
              let backdrop = a.unsafe[x, y]
              a.unsafe[x, y] = blendMask(backdrop, source)
          else: # a is a Mask
            when type(b) is Image:
              let source = b.unsafe[samplePos.x, samplePos.y].a
            else: # b is a Mask
              let source = b.unsafe[samplePos.x, samplePos.y]
            if source == 0:
              a.unsafe[x, y] = 0
            elif source != 255:
              let backdrop = a.unsafe[x, y]
              a.unsafe[x, y] = maskBlendMask(backdrop, source)
          srcPos += dx
      else:
        for x in x ..< xStop:
          let samplePos = ivec2((srcPos.x - h).int32, (srcPos.y - h).int32)
          when type(a) is Image:
            let backdrop = a.unsafe[x, y]
            when type(b) is Image:
              let
                sample = b.unsafe[samplePos.x, samplePos.y]
                blended = blender(backdrop, sample)
            else: # b is a Mask
              let
                sample = b.unsafe[samplePos.x, samplePos.y]
                blended = blender(backdrop, rgbx(0, 0, 0, sample))
            a.unsafe[x, y] = blended
          else: # a is a Mask
            let backdrop = a.unsafe[x, y]
            when type(b) is Image:
              let sample = b.unsafe[samplePos.x, samplePos.y].a
            else: # b is a Mask
              let sample = b.unsafe[samplePos.x, samplePos.y]
            a.unsafe[x, y] = masker(backdrop, sample)
          srcPos += dx

    if blendMode == MaskBlend:
      if a.width - xStop > 0:
        zeroMem(a.data[a.dataIndex(xStop, y)].addr, 4 * (a.width - xStop))

  if blendMode == MaskBlend:
    if a.height - yMax > 0:
      zeroMem(a.data[a.dataIndex(0, yMax)].addr, 4 * a.width * (a.height - yMax))

proc draw*(
  a, b: Image, transform = mat3(), blendMode = NormalBlend
) {.inline, raises: [PixieError].} =
  ## Draws one image onto another using matrix with color blending.
  when type(transform) is Vec2:
    a.drawUber(b, translate(transform), blendMode)
  else:
    a.drawUber(b, transform, blendMode)

proc draw*(
  a, b: Mask, transform = mat3(), blendMode = MaskBlend
) {.inline, raises: [PixieError].} =
  ## Draws a mask onto a mask using a matrix with color blending.
  when type(transform) is Vec2:
    a.drawUber(b, translate(transform), blendMode)
  else:
    a.drawUber(b, transform, blendMode)

proc draw*(
  image: Image, mask: Mask, transform = mat3(), blendMode = MaskBlend
) {.inline, raises: [PixieError].} =
  ## Draws a mask onto an image using a matrix with color blending.
  when type(transform) is Vec2:
    image.drawUber(mask, translate(transform), blendMode)
  else:
    image.drawUber(mask, transform, blendMode)

proc draw*(
  mask: Mask, image: Image, transform = mat3(), blendMode = MaskBlend
) {.inline, raises: [PixieError].} =
  ## Draws a image onto a mask using a matrix with color blending.
  when type(transform) is Vec2:
    mask.drawUber(image, translate(transform), blendMode)
  else:
    mask.drawUber(image, transform, blendMode)

proc drawTiled*(
  dst, src: Image, mat: Mat3, blendMode = NormalBlend
) {.raises: [PixieError].} =
  dst.drawCorrect(src, mat, blendMode, true)

proc resize*(srcImage: Image, width, height: int): Image {.raises: [PixieError].} =
  ## Resize an image to a given height and width.
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
      OverwriteBlend
    )

proc resize*(srcMask: Mask, width, height: int): Mask {.raises: [PixieError].} =
  ## Resize a mask to a given height and width.
  if width == srcMask.width and height == srcMask.height:
    result = srcMask.copy()
  else:
    result = newMask(width, height)
    result.draw(
      srcMask,
      scale(vec2(
        width.float32 / srcMask.width.float32,
        height.float32 / srcMask.height.float32
      )),
      OverwriteBlend
    )

proc shadow*(
  image: Image, offset: Vec2, spread, blur: float32, color: SomeColor
): Image {.raises: [PixieError].} =
  ## Create a shadow of the image with the offset, spread and blur.
  let mask = image.newMask()

  var shifted: Mask
  if offset == vec2(0, 0):
    shifted = mask
  else:
    shifted = newMask(mask.width, mask.height)
    shifted.draw(mask, translate(offset), OverwriteBlend)

  shifted.spread(spread)
  shifted.blur(blur)

  result = newImage(shifted.width, shifted.height)
  result.fill(color)
  result.draw(shifted)

proc superImage*(image: Image, x, y, w, h: int): Image {.raises: [PixieError].} =
  ## Either cuts a sub image or returns a super image with padded transparency.
  if x >= 0 and x + w <= image.width and y >= 0 and y + h <= image.height:
    result = image.subImage(x, y, w, h)
  elif abs(x) >= image.width or abs(y) >= image.height:
    # Nothing to copy, just an empty new image
    result = newImage(w, h)
  else:
    result = newImage(w, h)
    result.draw(image, translate(vec2(-x.float32, -y.float32)), OverwriteBlend)

when defined(release):
  {.pop.}
