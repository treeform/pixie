import chroma, blends, bumpy, vmath, common, system/memory

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

proc fillUnsafe(data: var seq[ColorRGBA], rgba: ColorRGBA, start, len: int) =
  ## Fills the image data with a solid color starting at index start and
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
          cast[ptr uint64](image.data[j].addr)[] = u64
          i += 2
    # Fill whatever is left the slow way
    for j in i ..< start + len:
      data[j] = rgba

proc fill*(image: Image, rgba: ColorRgba) {.inline.} =
  ## Fills the image with a solid color.
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

proc minifyBy2*(image: Image): Image =
  ## Scales the image down by an integer scale.
  result = newImage(image.width div 2, image.height div 2)
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      var color =
        image.getRgbaUnsafe(x * 2 + 0, y * 2 + 0).color / 4.0 +
        image.getRgbaUnsafe(x * 2 + 1, y * 2 + 0).color / 4.0 +
        image.getRgbaUnsafe(x * 2 + 1, y * 2 + 1).color / 4.0 +
        image.getRgbaUnsafe(x * 2 + 0, y * 2 + 1).color / 4.0
      result.setRgbaUnsafe(x, y, color.rgba)

proc minifyBy2*(image: Image, scale2x: int): Image =
  ## Scales the image down by an integer scale.
  result = image
  for i in 1 ..< scale2x:
    result = result.minifyBy2()

proc magnifyBy2*(image: Image, scale2x: int): Image =
  ## Scales image image up by an integer scale.
  let scale = 2 ^ scale2x
  result = newImage(image.width * scale, image.height * scale)
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      var rgba = image.getRgbaUnsafe(x div scale, y div scale)
      result.setRgbaUnsafe(x, y, rgba)

proc magnifyBy2*(image: Image): Image =
  image.magnifyBy2(2)

proc toPremultipliedAlpha*(image: Image) =
  ## Converts an image to straight alpha from premultiplied alpha.
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

when defined(release):
  {.pop.}

proc draw*(a, b: Image, mat: Mat3, blendMode = bmNormal)
proc draw*(a, b: Image, pos = vec2(0, 0), blendMode = bmNormal) {.inline.}

proc invert*(image: Image) =
  ## Inverts all of the colors and alpha.
  var i: int
  when defined(amd64) and not defined(pixieNoSimd):
    let vec255 = mm_set1_epi8(255)
    while i < image.data.len - 4:
      var m = mm_loadu_si128(image.data[i].addr)
      m = mm_sub_epi8(vec255, m)
      mm_storeu_si128(image.data[i].addr, m)
      i += 4
  for j in i ..< image.data.len:
    var rgba = image.data[j]
    rgba.r = 255 - rgba.r
    rgba.g = 255 - rgba.g
    rgba.b = 255 - rgba.b
    rgba.a = 255 - rgba.a
    image.data[j] = rgba

proc getRgbaSmooth*(image: Image, x, y: float32): ColorRGBA {.inline.} =
  let
    minX = x.floor.int
    difX = x - x.floor
    minY = y.floor.int
    difY = y - y.floor

    vX0Y0 = image[minX, minY].toPremultipliedAlpha()
    vX1Y0 = image[minX + 1, minY].toPremultipliedAlpha()
    vX0Y1 = image[minX, minY + 1].toPremultipliedAlpha()
    vX1Y1 = image[minX + 1, minY + 1].toPremultipliedAlpha()

    bottomMix = lerp(vX0Y0, vX1Y0, difX)
    topMix = lerp(vX0Y1, vX1Y1, difX)
    finalMix = lerp(bottomMix, topMix, difY)

  finalMix.toStraightAlpha()

proc resize*(srcImage: Image, width, height: int): Image =
  result = newImage(width, height)
  result.draw(
    srcImage,
    scale(vec2(
      (width + 1).float / srcImage.width.float,
      (height + 1).float / srcImage.height.float
    ))
  )

proc blur*(image: Image, radius: float32) =
  ## Applies Gaussian blur to the image given a radius.
  let radius = round(radius).int
  if radius == 0:
    return

  # Compute lookup table for 1d Gaussian kernel.
  var
    lookup = newSeq[float](radius * 2 + 1)
    total = 0.0
  for xb in -radius .. radius:
    let s = radius.float32 / 2.2 # 2.2 matches Figma.
    let x = xb.float32
    let a = 1 / sqrt(2 * PI * s^2) * exp(-1 * x^2 / (2 * s^2))
    lookup[xb + radius] = a
    total += a
  for xb in -radius .. radius:
    lookup[xb + radius] /= total

  # Blur in the X direction.
  var blurX = newImage(image.width, image.height)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var c: Color
      var totalA = 0.0
      for xb in -radius .. radius:
        let c2 = image[x + xb, y].color
        let a = lookup[xb + radius]
        let aa = c2.a * a
        totalA += aa
        c.r += c2.r * aa
        c.g += c2.g * aa
        c.b += c2.b * aa
        c.a += c2.a * a
      c.r = c.r / totalA
      c.g = c.g / totalA
      c.b = c.b / totalA
      blurX.setRgbaUnsafe(x, y, c.rgba)

  # Blur in the Y direction.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var c: Color
      var totalA = 0.0
      for yb in -radius .. radius:
        let c2 = blurX[x, y + yb].color
        let a = lookup[yb + radius]
        let aa = c2.a * a
        totalA += aa
        c.r += c2.r * aa
        c.g += c2.g * aa
        c.b += c2.b * aa
        c.a += c2.a * a
      c.r = c.r / totalA
      c.g = c.g / totalA
      c.b = c.b / totalA
      image.setRgbaUnsafe(x, y, c.rgba)

proc blurAlpha*(image: Image, radius: float32) =
  ## Applies Gaussian blur to the image given a radius.
  let radius = round(radius).int
  if radius == 0:
    return

  # Compute lookup table for 1d Gaussian kernel.
  var
    lookup = newSeq[float](radius * 2 + 1)
    total = 0.0
  for xb in -radius .. radius:
    let s = radius.float32 / 2.2 # 2.2 matches Figma.
    let x = xb.float32
    let a = 1 / sqrt(2 * PI * s^2) * exp(-1 * x^2 / (2 * s^2))
    lookup[xb + radius] = a
    total += a
  for xb in -radius .. radius:
    lookup[xb + radius] /= total

  # Blur in the X direction.
  var blurX = newImage(image.width, image.height)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var alpha: float32
      for xb in -radius .. radius:
        let c2 = image[x + xb, y]
        let a = lookup[xb + radius]
        alpha += c2.a.float32 * a
      blurX.setRgbaUnsafe(x, y, rgba(0, 0, 0, alpha.uint8))

  # Blur in the Y direction and modify image.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var alpha: float32
      for yb in -radius .. radius:
        let c2 = blurX[x, y + yb]
        let a = lookup[yb + radius]
        alpha += c2.a.float32 * a
      image.setRgbaUnsafe(x, y, rgba(0, 0, 0, alpha.uint8))

proc shift*(image: Image, offset: Vec2) =
  ## Shifts the image by offset.
  let copy = image.copy() # Copy to read from.
  image.fill(rgba(0, 0, 0, 0)) # Reset this for being drawn to.
  image.draw(copy, offset) # Draw copy into image.

proc spread*(image: Image, spread: float32) =
  ## Grows the image as a mask by spread.
  let
    copy = image.copy()
    spread = round(spread).int
  assert spread > 0
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var maxAlpha = 0.uint8
      block blurBox:
        for bx in -spread .. spread:
          for by in -spread .. spread:
            let alpha = copy[x + bx, y + by].a
            if alpha > maxAlpha:
              maxAlpha = alpha
            if maxAlpha == 255:
              break blurBox
      image[x, y] = rgba(0, 0, 0, maxAlpha)

proc shadow*(
  mask: Image, offset: Vec2, spread, blur: float32, color: ColorRGBA
): Image =
  ## Create a shadow of the image with the offset, spread and blur.
  var shadow = mask
  if offset != vec2(0, 0):
    shadow.shift(offset)
  if spread > 0:
    shadow.spread(spread)
  if blur > 0:
    shadow.blurAlpha(blur)
  result = newImage(mask.width, mask.height)
  result.fill(color)
  result.draw(shadow, blendMode = bmMask)

proc applyOpacity*(image: Image, opacity: float32) =
  ## Multiplies alpha of the image by opacity.
  let op = (255 * opacity).uint32
  for i in 0 ..< image.data.len:
    var rgba = image.data[i]
    rgba.a = ((rgba.a.uint32 * op) div 255).clamp(0, 255).uint8
    image.data[i] = rgba

proc sharpOpacity*(image: Image) =
  ## Sharpens the opacity to extreme.
  ## A = 0 stays 0. Anything else turns into 255.
  for i in 0 ..< image.data.len:
    var rgba = image.data[i]
    if rgba.a == 0:
      image.data[i] = rgba(0, 0, 0, 0)
    else:
      image.data[i] = rgba(255, 255, 255, 255)

proc drawCorrect*(a, b: Image, mat: Mat3, blendMode: BlendMode) =
  ## Draws one image onto another using matrix with color blending.
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

  let mixer = blendMode.mixer()
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      let
        srcPos = matInv * vec2(x.float32 + h, y.float32 + h)
        xFloat = srcPos.x - h
        yFloat = srcPos.y - h
        rgba = a.getRgbaUnsafe(x, y)
        rgba2 = b.getRgbaSmooth(xFloat, yFloat)
      a.setRgbaUnsafe(x, y, mixer(rgba, rgba2))

proc drawUber(
  a, b: Image,
  p, dx, dy: Vec2,
  lines: array[0..3, Segment],
  blendMode: BlendMode,
  smooth: bool
) =
  let mixer = blendMode.mixer()
  for y in 0 ..< a.height:
    var
      xMin = a.width
      xMax = 0
    for yOffset in [0.float32, 1]:
      var scanLine = segment(
        vec2(-100000, y.float32 + yOffset),
        vec2(10000, y.float32 + yOffset)
      )
      for l in lines:
        var at: Vec2
        if intersects(l, scanLine, at) and l.to != at:
          xMin = min(xMin, at.x.floor.int)
          xMax = max(xMax, at.x.ceil.int)

    xMin = xMin.clamp(0, a.width)
    xMax = xMax.clamp(0, a.width)

    if blendMode == bmIntersectMask:
      if xMin > 0:
        zeroMem(a.data[a.dataIndex(0, y)].addr, 4 * xMin)

    for x in xMin ..< xMax:
      let
        srcPos = p + dx * float32(x) + dy * float32(y)
        xFloat = srcPos.x - h
        yFloat = srcPos.y - h
        rgba = a.getRgbaUnsafe(x, y)
        rgba2 =
          if smooth:
            b.getRgbaSmooth(xFloat, yFloat)
          else:
            b.getRgbaUnsafe(xFloat.int, yFloat.int)
      a.setRgbaUnsafe(x, y, mixer(rgba, rgba2))

    if blendMode == bmIntersectMask:
      if a.width - xMax > 0:
        zeroMem(a.data[a.dataIndex(xMax, y)].addr, 4 * (a.width - xMax))

proc draw*(a, b: Image, mat: Mat3, blendMode: BlendMode) =
  ## Draws one image onto another using matrix with color blending.

  let
    corners = [
      mat * vec2(0, 0),
      mat * vec2(b.width.float32, 0),
      mat * vec2(b.width.float32, b.height.float32),
      mat * vec2(0, b.height.float32)
    ]
    lines = [
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

  let smooth = not(dx.length == 1.0 and dy.length == 1.0 and
    mat[2, 0].fractional == 0.0 and mat[2, 1].fractional == 0.0)

  a.drawUber(b, p, dx, dy, lines, blendMode, smooth)

proc draw*(a, b: Image, pos = vec2(0, 0), blendMode = bmNormal) {.inline.} =
  a.draw(b, translate(pos), blendMode)
