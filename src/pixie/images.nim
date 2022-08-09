import blends, bumpy, chroma, common, internal, simd, vmath

export Image, copy, dataIndex, newImage

const h = 0.5.float32

type UnsafeImage = distinct Image

when defined(release):
  {.push checks: off.}

proc `$`*(image: Image): string {.raises: [].} =
  ## Prints the image size.
  "<Image " & $image.width & "x" & $image.height & ">"

proc inside*(image: Image, x, y: int): bool {.inline, raises: [].} =
  ## Returns true if (x, y) is inside the image.
  x >= 0 and x < image.width and y >= 0 and y < image.height

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

proc isOneColor*(image: Image): bool {.hasSimd, raises: [].} =
  ## Checks if the entire image is the same color.
  result = true
  let color = cast[uint32](image.data[0])
  for i in 0 ..< image.data.len:
    if cast[uint32](image.data[i]) != color:
      return false

proc isTransparent*(image: Image): bool {.hasSimd, raises: [].} =
  ## Checks if this image is fully transparent or not.
  result = true
  for i in 0 ..< image.data.len:
    if image.data[i].a != 0:
      return false

proc isOpaque*(image: Image): bool {.raises: [].} =
  ## Checks if the entire image is opaque (alpha values are all 255).
  isOpaque(image.data, 0, image.data.len)

proc flipHorizontal*(image: Image) {.raises: [].} =
  ## Flips the image around the Y axis.
  let halfWidth = image.width div 2
  for y in 0 ..< image.height:
    var
      left = image.dataIndex(0, y)
      right = left + image.width - 1
    for x in 0 ..< halfWidth:
      swap(image.data[left], image.data[right])
      inc left
      dec right

proc flipVertical*(image: Image) {.raises: [].} =
  ## Flips the image around the X axis.
  let halfHeight = image.height div 2
  for y in 0 ..< halfHeight:
    let
      topStart = image.dataIndex(0, y)
      bottomStart = image.dataIndex(0, image.height - y - 1)
    for x in 0 ..< image.width:
      swap(image.data[topStart + x], image.data[bottomStart + x])

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

proc subImage*(image: Image, rect: Rect): Image {.raises: [PixieError].} =
  ## Gets a sub image from this image via rectangle.
  ## Rectangle is snapped/expanded to whole pixels first.
  let r = rect.snapToPixels()
  image.subImage(r.x.int, r.y.int, r.w.int, r.h.int)

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

proc minifyBy2*(
  image: Image, power = 1
): Image {.hasSimd, raises: [PixieError].} =
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
      let
        topRowStart = src.dataIndex(0, y * 2)
        bottomRowStart = src.dataIndex(0, y * 2 + 1)
      for x in 0 ..< resultEvenWidth:
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

proc magnifyBy2*(
  image: Image, power = 1
): Image {.hasSimd, raises: [PixieError].} =
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
    for x in 0 ..< image.width:
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

proc applyOpacity*(image: Image, opacity: float32) {.hasSimd, raises: [].} =
  ## Multiplies alpha of the image by opacity.
  let opacity = round(255 * opacity).uint16
  if opacity == 255:
    return

  if opacity == 0:
    image.fill(rgbx(0, 0, 0, 0))
    return

  for i in 0 ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = ((rgbx.r * opacity) div 255).uint8
    rgbx.g = ((rgbx.g * opacity) div 255).uint8
    rgbx.b = ((rgbx.b * opacity) div 255).uint8
    rgbx.a = ((rgbx.a * opacity) div 255).uint8
    image.data[i] = rgbx

proc invert*(image: Image) {.hasSimd, raises: [].} =
  ## Inverts all of the colors and alpha.
  for i in 0 ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = 255 - rgbx.r
    rgbx.g = 255 - rgbx.g
    rgbx.b = 255 - rgbx.b
    rgbx.a = 255 - rgbx.a
    image.data[i] = rgbx

  # Inverting rgbx(50, 100, 150, 200) becomes rgbx(205, 155, 105, 55). This
  # is not a valid premultiplied alpha color.
  # We need to convert back to premultiplied alpha after inverting.
  image.data.toPremultipliedAlpha()

proc ceil*(image: Image) {.hasSimd, raises: [].} =
  ## A value of 0 stays 0. Anything else turns into 255.
  for i in 0 ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = if rgbx.r == 0: 0 else: 255
    rgbx.g = if rgbx.g == 0: 0 else: 255
    rgbx.b = if rgbx.b == 0: 0 else: 255
    rgbx.a = if rgbx.a == 0: 0 else: 255
    image.data[i] = rgbx

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
      var idx = image.dataIndex(0, y)
      for xx in max(x - radius, 0) .. min(x + radius, image.width - 1):
        values += image.data[idx + xx] * kernel[xx - x + radius]
      for xx in max(x - radius, image.width) .. x + radius:
        values += outOfBounds * kernel[xx - x + radius]
      blurX.unsafe[y, x] = rgbx(values)

  # Blur in the Y direction.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var values: array[4, uint32]
      for yy in y - radius ..< min(y + radius, 0):
        values += outOfBounds * kernel[yy - y + radius]
      var idx = blurX.dataIndex(0, x)
      for yy in max(y - radius, 0) .. min(y + radius, image.height - 1):
        values += blurX.data[idx + yy] * kernel[yy - y + radius]
      for yy in max(y - radius, image.height) .. y + radius:
        values += outOfBounds * kernel[yy - y + radius]
      image.unsafe[x, y] = rgbx(values)

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
  a, b: Image, transform = mat3(), blendMode: BlendMode, tiled: bool
) =
  ## Draws one image onto another using a matrix transform and color blending.
  ## This proc is not about performance, it should be as simple as possible.
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
    inverseTransform = scale(vec2(0.5, 0.5)) * inverseTransform

  while filterBy2 <= 0.5:
    b = b.magnifyBy2()
    p *= 2
    dx *= 2
    dy *= 2
    filterBy2 *= 2
    inverseTransform = scale(vec2(2, 2)) * inverseTransform

  let blender = blendMode.blender()
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      let
        samplePos = inverseTransform * vec2(x.float32 + h, y.float32 + h)
        xFloat = samplePos.x - h
        yFloat = samplePos.y - h
        backdrop = a.unsafe[x, y]
        sample = b.getRgbaSmooth(xFloat, yFloat, tiled)
        blended = blender(backdrop, sample)
      a.unsafe[x, y] = blended

proc blendLine(
  a, b: ptr UncheckedArray[ColorRGBX], len: int, blender: Blender
) {.inline.} =
  for i in 0 ..< len:
    a[i] = blender(a[i], b[i])

proc blendLineOverwrite(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.inline.} =
  copyMem(a[0].addr, b[0].addr, len * 4)

proc blendLineNormal(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.hasSimd.} =
  for i in 0 ..< len:
    a[i] = blendNormal(a[i], b[i])

proc blendLineMask(a, b: ptr UncheckedArray[ColorRGBX], len: int) {.hasSimd.} =
  for i in 0 ..< len:
    a[i] = blendMask(a[i], b[i])

proc blendRect(a, b: Image, pos: Ivec2, blendMode: BlendMode) =
  let
    px = pos.x.int
    py = pos.y.int

  if px >= a.width or px + b.width <= 0 or py >= a.height or py + b.height <= 0:
    if blendMode == MaskBlend:
      a.fill(rgbx(0, 0, 0, 0))
    return

  let
    xStart = max(-px, 0)
    yStart = max(-py, 0)
    xEnd = min(b.width, a.width - px)
    yEnd = min(b.height, a.height - py)

  case blendMode:
  of NormalBlend:
    for y in yStart ..< yEnd:
      blendLineNormal(
        a.getUncheckedArray(xStart + px, y + py),
        b.getUncheckedArray(xStart, y),
        xEnd - xStart
      )
  of OverwriteBlend:
    for y in yStart ..< yEnd:
      blendLineOverwrite(
        a.getUncheckedArray(xStart + px, y + py),
        b.getUncheckedArray(xStart, y),
        xEnd - xStart
      )
  of MaskBlend:
    {.linearScanEnd.}
    if yStart + py > 0:
      zeroMem(a.data[0].addr, (yStart + py) * a.width * 4)
    for y in yStart ..< yEnd:
      if xStart + px > 0:
        zeroMem(a.data[a.dataIndex(0, y + py)].addr, (xStart + px) * 4)
      blendLineMask(
        a.getUncheckedArray(xStart + px, y + py),
        b.getUncheckedArray(xStart, y),
        xEnd - xStart
      )
      if xEnd + px < a.width:
        zeroMem(
          a.data[a.dataIndex(xEnd + px, y + py)].addr,
          (a.width - (xEnd + px)) * 4
        )
    if yEnd + py < a.height:
      zeroMem(
        a.data[a.dataIndex(0, yEnd + py)].addr,
        (a.height - (yEnd + py)) * a.width * 4
      )
  else:
    let blender = blendMode.blender()
    for y in yStart ..< yEnd:
      blendLine(
        a.getUncheckedArray(xStart + px, y + py),
        b.getUncheckedArray(xStart, y),
        xEnd - xStart,
        blender
      )

proc drawSmooth(a, b: Image, transform: Mat3, blendMode: BlendMode) =
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
    inverseTransform = transform.inverse()
    # Compute movement vectors
    p = inverseTransform * vec2(0 + h, 0 + h)
    dx = inverseTransform * vec2(1 + h, 0 + h) - p
    dy = inverseTransform * vec2(0 + h, 1 + h) - p

  # Determine where we should start and stop drawing in the y dimension
  var
    yStart = a.height
    yEnd = 0
  for segment in perimeter:
    yStart = min(yStart, segment.at.y.floor.int)
    yEnd = max(yEnd, segment.at.y.ceil.int)
  yStart = yStart.clamp(0, a.height)
  yEnd = yEnd.clamp(0, a.height)

  if blendMode == MaskBlend and yStart > 0:
    zeroMem(a.data[0].addr, yStart * a.width * 4)

  var sampleLine = newSeq[ColorRGBX](a.width)
  for y in yStart ..< yEnd:
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

    let
      xStart = clamp(xMin.floor.int, 0, a.width)
      xEnd = clamp(xMax.ceil.int, 0, a.width)

    if xEnd - xStart == 0:
      continue

    var srcPos = p + dx * xStart.float32 + dy * y.float32
    srcPos = vec2(srcPos.x - h, srcPos.y - h)
    for x in xStart ..< xEnd:
      sampleLine[x] = b.getRgbaSmooth(srcPos.x, srcPos.y)
      srcPos += dx

    case blendMode:
    of NormalBlend:
      blendLineNormal(
        a.getUncheckedArray(xStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[xStart].addr),
        xEnd - xStart
      )

    of OverwriteBlend:
      blendLineOverwrite(
        a.getUncheckedArray(xStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[xStart].addr),
        xEnd - xStart
      )

    of MaskBlend:
      {.linearScanEnd.}
      if blendMode == MaskBlend and xStart > 0:
        zeroMem(a.data[a.dataIndex(0, y)].addr, xStart * 4)

      blendLineMask(
        a.getUncheckedArray(xStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[xStart].addr),
        xEnd - xStart
      )

      if blendMode == MaskBlend and a.width - xEnd > 0:
        zeroMem(a.data[a.dataIndex(xEnd, y)].addr, (a.width - xEnd) * 4)
    else:
      blendLine(
        a.getUncheckedArray(xStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[xStart].addr),
        xEnd - xStart,
        blendMode.blender()
      )

  if blendMode == MaskBlend and a.height - yEnd > 0:
    zeroMem(
      a.data[a.dataIndex(0, yEnd)].addr,
      a.width * (a.height - yEnd) * 4
    )

proc draw*(
  a, b: Image, transform = mat3(), blendMode = NormalBlend
) {.raises: [PixieError].} =
  ## Draws one image onto another using a matrix transform and color blending.
  var
    transform = transform
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
    transform = transform * scale(vec2(2, 2))

  while filterBy2 <= 0.5:
    b = b.magnifyBy2()
    p *= 2
    dx *= 2
    dy *= 2
    filterBy2 *= 2
    transform = transform * scale(vec2(1/2, 1/2))

  let
    hasRotationOrScaling = not(dx == vec2(1, 0) and dy == vec2(0, 1))
    smooth = not(
      dx.length == 1.0 and
      dy.length == 1.0 and
      transform[2, 0].fractional == 0.0 and
      transform[2, 1].fractional == 0.0
    )

  if hasRotationOrScaling or smooth:
    a.drawSmooth(b, transform, blendMode)
  else:
    a.blendRect(b, ivec2(transform[2, 0].int32, transform[2, 1].int32), blendMode)

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

proc spread(image: Image, spread: float32) {.raises: [PixieError].} =
  ## Grows the mask by spread.
  let spread = round(spread).int
  if spread == 0:
    return

  if spread > 0:
    # Spread in the X direction. Store with dimensions swapped for reading later.
    let spreadX = newImage(image.height, image.width)
    for y in 0 ..< image.height:
      for x in 0 ..< image.width:
        var maxValue: uint8
        for xx in max(x - spread, 0) .. min(x + spread, image.width - 1):
          let value = image.unsafe[xx, y].a
          if value > maxValue:
            maxValue = value
          if maxValue == 255:
            break
        spreadX.unsafe[y, x].a = maxValue

    # Spread in the Y direction and modify mask.
    for y in 0 ..< image.height:
      for x in 0 ..< image.width:
        var maxValue: uint8
        for yy in max(y - spread, 0) .. min(y + spread, image.height - 1):
          let value = spreadX.unsafe[yy, x].a
          if value > maxValue:
            maxValue = value
          if maxValue == 255:
            break
        image.unsafe[x, y] = rgbx(0, 0, 0, maxValue)

  elif spread < 0:
    let spread = -spread

    # Spread in the X direction. Store with dimensions swapped for reading later.
    let spreadX = newImage(image.height, image.width)
    for y in 0 ..< image.height:
      for x in 0 ..< image.width:
        var minValue: uint8 = 255
        for xx in max(x - spread, 0) .. min(x + spread, image.width - 1):
          let value = image.unsafe[xx, y].a
          if value < minValue:
            minValue = value
          if minValue == 0:
            break
        spreadX.unsafe[y, x] = rgbx(0, 0, 0, minValue)

    # Spread in the Y direction and modify mask.
    for y in 0 ..< image.height:
      for x in 0 ..< image.width:
        var minValue: uint8 = 255
        for yy in max(y - spread, 0) .. min(y + spread, image.height - 1):
          let value = spreadX.unsafe[yy, x].a
          if value < minValue:
            minValue = value
          if minValue == 0:
            break
        image.unsafe[x, y] = rgbx(0, 0, 0, minValue)

proc shadow*(
  image: Image, offset: Vec2, spread, blur: float32, color: SomeColor
): Image {.raises: [PixieError].} =
  ## Create a shadow of the image with the offset, spread and blur.
  var mask: Image
  if offset == vec2(0, 0):
    mask = image.copy()
  else:
    mask = newImage(image.width, image.height)
    mask.draw(image, translate(offset), OverwriteBlend)

  mask.spread(spread)
  mask.blur(blur)

  result = newImage(mask.width, mask.height)
  result.fill(color)
  result.draw(mask, blendMode = MaskBlend)

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

proc opaqueBounds*(image: Image): Rect =
  ## Returns the bounds of opaque pixels.
  ## Some images have transparency around them, use this to find just the
  ## visible part of the image and then use subImage to cut it out.
  ## Returns zero rect if whole image is transparent.
  ## Returns just the size of the image if no edge is transparent.
  var
    xMin = image.width
    xMax = 0
    yMin = image.height
    yMax = 0
  # Find the trim coordinates.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      if image.unsafe[x, y].a != 0:
        xMin = min(xMin, x)
        xMax = max(xMax, x + 1)
        yMin = min(yMin, y)
        yMax = max(yMax, y + 1)
  if xMax <= xMin or yMax <= yMin:
    return rect(0, 0, 0, 0)
  rect(
    xMin.float32,
    yMin.float32,
    (xMax - xMin).float32,
    (yMax - yMin).float32
  )

when defined(release):
  {.pop.}
