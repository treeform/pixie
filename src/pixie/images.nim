import chroma, blends, vmath, common

type
  Image* = ref object
    ## Main image object that holds the bitmap data in RGBA format.
    width*, height*: int
    data*: seq[ColorRGBA]

proc draw*(a, b: Image, mat: Mat3, blendMode = bmNormal)
proc draw*(a, b: Image, pos = vec2(0, 0), blendMode = bmNormal) {.inline.}

proc newImage*(width, height: int): Image =
  ## Creates a new image with appropriate dimensions.
  result = Image()
  result.width = width
  result.height = height
  result.data = newSeq[ColorRGBA](width * height)

proc newSeqNoInit*[T](len: Natural): seq[T] =
  ## Creates a new sequence of type ``seq[T]`` with length ``len``.
  ## Skips initialization of memory to zero.
  result = newSeqOfCap[T](len)
  when defined(nimSeqsV2):
    cast[ptr int](addr result)[] = len
  else:
    cast[ref int](result) = len

proc newImageNoInit*(width, height: int): Image =
  ## Creates a new image with appropriate dimensions.
  result = Image()
  result.width = width
  result.height = height
  result.data = newSeq[ColorRGBA](width * height)

proc wh*(image: Image): Vec2 {.inline.} =
  ## Return with and height as a size vector.
  vec2(image.width.float32, image.height.float32)

proc copy*(image: Image): Image =
  ## Copies an image creating a new image.
  result = newImage(image.width, image.height)
  result.data = image.data

proc `$`*(image: Image): string =
  ## Display the image size and channels.
  "<Image " & $image.width & "x" & $image.height & ">"

proc inside*(image: Image, x, y: int): bool {.inline.} =
  ## Returns true if (x, y) is inside the image.
  x >= 0 and x < image.width and y >= 0 and y < image.height

proc inside1px*(image: Image, x, y: float): bool {.inline.} =
  ## Returns true if (x, y) is inside the image.
  const px = 1
  x >= -px and x < (image.width.float32 + px) and
  y >= -px and y < (image.height.float32 + px)

proc getRgbaUnsafe*(image: Image, x, y: int): ColorRGBA {.inline.} =
  ## Gets a color from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory reads.
  result = image.data[image.width * y + x]

proc getAddr*(image: Image, x, y: int): pointer {.inline.} =
  ## Gets a address of the color from (x, y) coordinates.
  ## Unsafe make sure x, y are in bounds.
  image.data[image.width * y + x].addr

proc `[]`*(image: Image, x, y: int): ColorRGBA {.inline.} =
  ## Gets a pixel at (x, y) or returns transparent black if outside of bounds.
  if image.inside(x, y):
    return image.getRgbaUnsafe(x, y)

proc setRgbaUnsafe*(image: Image, x, y: int, rgba: ColorRGBA) {.inline.} =
  ## Sets a color from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory writes.
  image.data[image.width * y + x] = rgba

proc `[]=`*(image: Image, x, y: int, rgba: ColorRGBA) {.inline.} =
  ## Sets a pixel at (x, y) or does nothing if outside of bounds.
  if image.inside(x, y):
    image.setRgbaUnsafe(x, y, rgba)

proc fill*(image: Image, rgba: ColorRgba) =
  ## Fills the image with a solid color.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      image.setRgbaUnsafe(x, y, rgba)

proc newImageFill*(width, height: int, rgba: ColorRgba): Image =
  ## Fills the image with a solid color.
  result = newImageNoInit(width, height)
  result.fill(rgba)

proc invert*(image: Image) =
  ## Inverts all of the colors and alpha.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var rgba = image.getRgbaUnsafe(x, y)
      rgba.r = 255 - rgba.r
      rgba.g = 255 - rgba.g
      rgba.b = 255 - rgba.b
      rgba.a = 255 - rgba.a
      image.setRgbaUnsafe(x, y, rgba)

proc subImage*(image: Image, x, y, w, h: int): Image =
  ## Gets a sub image of the main image.
  ## TODO handle images out of bounds faster
  # doAssert x >= 0 and y >= 0
  # doAssert x + w <= image.width and y + h <= image.height
  result = newImageNoInit(w, h)
  for y2 in 0 ..< h:
    for x2 in 0 ..< w:
      result.setRgbaUnsafe(x2, y2, image[x2 + x, y2 + y])

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

proc flipHorizontal*(image: Image) =
  ## Flips the image around the Y axis.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let rgba = image.getRgbaUnsafe(x, y)
      image.setRgbaUnsafe(image.width - x - 1, y, rgba)

proc flipVertical*(image: Image) =
  ## Flips the image around the X axis.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let rgba = image.getRgbaUnsafe(x, y)
      image.setRgbaUnsafe(x, image.height - y - 1, rgba)

func lerp(a, b: Color, v: float32): Color {.inline.} =
  result.r = lerp(a.r, b.r, v)
  result.g = lerp(a.g, b.g, v)
  result.b = lerp(a.b, b.b, v)
  result.a = lerp(a.a, b.a, v)

proc toAlphy*(c: Color): Color =
  ## Converts a color to premultiplied alpha from straight.
  result.r = c.r * c.a
  result.g = c.g * c.a
  result.b = c.b * c.a
  result.a = c.a

proc fromAlphy*(c: Color): Color =
  ## Converts a color to from premultiplied alpha to straight.
  if c.a == 0:
    return
  result.r = c.r / c.a
  result.g = c.g / c.a
  result.b = c.b / c.a
  result.a = c.a

proc toAlphy*(image: Image) =
  ## Converts an image to premultiplied alpha from straight.
  for c in image.data.mitems:
    c.g = ((c.r.uint32 * c.a.uint32) div 255).uint8
    c.r = ((c.r.uint32 * c.a.uint32) div 255).uint8
    c.b = ((c.r.uint32 * c.a.uint32) div 255).uint8

proc fromAlphy*(image: Image) =
  ## Converts an image to from premultiplied alpha to straight.
  for c in image.data.mitems:
    if c.a == 0:
      continue
    c.r = ((c.r.int32 * 255) div c.a.int32).uint8
    c.g = ((c.g.int32 * 255) div c.a.int32).uint8
    c.b = ((c.b.int32 * 255) div c.a.int32).uint8

proc getRgbaSmooth*(image: Image, x, y: float32): ColorRGBA {.inline.} =
  ## Gets a pixel as (x, y) floats.
  var
    x = x # TODO: look at maybe +0.5
    y = y # TODO: look at maybe +0.5
    minX = x.floor.int
    difX = x - x.floor
    minY = y.floor.int
    difY = y - y.floor

    vX0Y0 = image[minX, minY].color().toAlphy()
    vX1Y0 = image[minX + 1, minY].color().toAlphy()
    vX0Y1 = image[minX, minY + 1].color().toAlphy()
    vX1Y1 = image[minX + 1, minY + 1].color().toAlphy()

    bottomMix = lerp(vX0Y0, vX1Y0, difX)
    topMix = lerp(vX0Y1, vX1Y1, difX)
    finalMix = lerp(bottomMix, topMix, difY)

  return finalMix.fromAlphy().rgba()

# @andre: unused, delete?

# proc hasEffect*(blendMode: BlendMode, rgba: ColorRGBA): bool =
#   ## Returns true if applying rgba with current blend mode has effect.
#   case blendMode
#   of bmMask:
#     rgba.a != 255
#   of bmOverwrite:
#     true
#   of bmIntersectMask:
#     true
#   else:
#     rgba.a > 0

# proc allowCopy*(blendMode: BlendMode): bool =
#   ## Returns true if applying rgba with current blend mode has effect.
#   case blendMode
#   of bmIntersectMask:
#     false
#   else:
#     true

proc resize*(srcImage: Image, width, height: int): Image =
  result = newImage(width, height)
  result.draw(
    srcImage,
    scale(vec2(
      (width + 1).float / srcImage.width.float,
      (height + 1).float / srcImage.height.float
    ))
  )

proc blur*(image: Image, radius: float32): Image =
  ## Applies Gaussian blur to the image given a radius.
  let radius = (radius).int
  if radius == 0:
    return image.copy()

  # Compute lookup table for 1d Gaussian kernel.
  var lookup = newSeq[float](radius*2+1)
  var total = 0.0
  for xb in -radius .. radius:
    let s = radius.float32 / 2.2 # 2.2 matches Figma.
    let x = xb.float32
    let a = 1/sqrt(2*PI*s^2) * exp(-1*x^2/(2*s^2))
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
  var blurY = newImage(image.width, image.height)
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
      blurY.setRgbaUnsafe(x, y, c.rgba)

  return blurY

proc blurAlpha*(image: Image, radius: float32): Image =
  ## Applies Gaussian blur to the image given a radius.
  let radius = (radius).int
  if radius == 0:
    return image.copy()

  # Compute lookup table for 1d Gaussian kernel.
  var lookup = newSeq[float](radius*2+1)
  var total = 0.0
  for xb in -radius .. radius:
    let s = radius.float32 / 2.2 # 2.2 matches Figma.
    let x = xb.float32
    let a = 1/sqrt(2*PI*s^2) * exp(-1*x^2/(2*s^2))
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
      blurX.setRgbaUnsafe(x, y, rgba(0,0,0, (alpha).uint8))

  # Blur in the Y direction.
  var blurY = newImage(image.width, image.height)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var alpha: float32
      for yb in -radius .. radius:
        let c2 = blurX[x, y + yb]
        let a = lookup[yb + radius]
        alpha += c2.a.float32 * a
      blurY.setRgbaUnsafe(x, y, rgba(0,0,0, (alpha).uint8))

  return blurY

proc shift*(image: Image, offset: Vec2): Image =
  ## Shifts the image by offset.
  result = newImage(image.width, image.height)
  result.draw(image, offset)

proc spread*(image: Image, spread: float32): Image =
  ## Grows the image as a mask by spread.
  result = newImage(image.width, image.height)
  assert spread > 0
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      var maxAlpha = 0.uint8
      for bx in -spread.int .. spread.int:
        for by in -spread.int .. spread.int:
          # if vec2(bx.float32, by.float32).length < spread:
          let alpha = image[x + bx, y + by].a
          if alpha > maxAlpha:
            maxAlpha = alpha
          if maxAlpha == 255:
            break
      result[x, y] = rgba(0, 0, 0, maxAlpha)

proc shadow*(
  mask: Image,
  offset: Vec2,
  spread, blur: float32,
  color: ColorRGBA
): Image =
  ## Create a shadow of the image with the offset, spread and blur.
  var shadow = mask
  if offset != vec2(0, 0):
    shadow = shadow.shift(offset)
  if spread > 0:
    shadow = shadow.spread(spread)
  if blur > 0:
    shadow = shadow.blurAlpha(blur)
  result = newImageFill(mask.width, mask.height, color)
  result.draw(shadow, blendMode = bmMask)

proc applyOpacity*(image: Image, opacity: float32): Image =
  ## Multiplies alpha of the image by opacity.
  result = newImageNoInit(image.width, image.height)
  let op = (255 * opacity).uint32
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var rgba = image.getRgbaUnsafe(x, y)
      rgba.a = ((rgba.a.uint32 * op) div 255).clamp(0, 255).uint8
      result.setRgbaUnsafe(x, y, rgba)

proc sharpOpacity*(image: Image): Image =
  ## Sharpens the opacity to extreme.
  ## A = 0 stays 0. Anything else turns into 255.
  result = newImageNoInit(image.width, image.height)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var rgba = image.getRgbaUnsafe(x, y)
      if rgba.a == 0:
        result.setRgbaUnsafe(x, y, rgba(0, 0, 0, 0))
      else:
        result.setRgbaUnsafe(x, y, rgba(255, 255, 255, 255))

proc drawCorrect*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImageNoInit(a.width, a.height)

  var
    matInv = mat.inverse()
    # compute movement vectors
    h = 0.5.float32
    start = matInv * vec2(0 + h, 0 + h)
    stepX = matInv * vec2(1 + h, 0 + h) - start
    stepY = matInv * vec2(0 + h, 1 + h) - start
    minFilterBy2 = max(stepX.length, stepY.length)
    b = b

  while minFilterBy2 > 2.0:
    b = b.minifyBy2()
    start /= 2
    stepX /= 2
    stepY /= 2
    minFilterBy2 /= 2
    matInv = matInv * scale(vec2(0.5, 0.5))

  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      let srcPos = matInv * vec2(x.float32 + h, y.float32 + h)
      var rgba = a.getRgbaUnsafe(x, y)
      let rgba2 = b.getRgbaSmooth(srcPos.x - h, srcPos.y - h)
      rgba = blendMode.mix(rgba, rgba2)
      result.setRgbaUnsafe(x, y, rgba)

const h = 0.5.float32

proc drawUberStatic(
  a, b, c: Image,
  start, stepX, stepY: Vec2,
  lines: array[0..3, Segment],
  blendMode: static[BlendMode],
  inPlace: static[bool],
  smooth: static[bool],
) =
  for y in 0 ..< a.height:
    var
      xMin = 0
      xMax = 0
      hasIntersection = false
    for yOffset in [0.float32, 1]:
      var scanLine = segment(
        vec2(-100000, y.float32 + yOffset),
        vec2(10000, y.float32 + yOffset)
      )
      for l in lines:
        var at: Vec2
        if intersects(l, scanLine, at):
          if hasIntersection:
            xMin = min(xMin, at.x.floor.int)
            xMax = max(xMax, at.x.ceil.int)
          else:
            hasIntersection = true
            xMin = at.x.floor.int
            xMax = at.x.ceil.int

    xMin = xMin.clamp(0, a.width)
    xMax = xMax.clamp(0, a.width)

    when blendMode == bmIntersectMask:
      if xMin > 0:
        zeroMem(c.getAddr(0, y), 4*xMin)
    else:
      when not inPlace:
        # for x in 0 ..< xMin:
        #   result.setRgbaUnsafe(x, y, a.getRgbaUnsafe(x, y))
        if xMin > 0:
          copyMem(c.getAddr(0, y), a.getAddr(0, y), 4*xMin)

    for x in xMin ..< xMax:
      let srcPos = start + stepX * float32(x) + stepY * float32(y)
      let
        xFloat = srcPos.x - h
        yFloat = srcPos.y - h
      var rgba = a.getRgbaUnsafe(x, y)
      var rgba2 =
        when smooth:
          b.getRgbaSmooth(xFloat, yFloat)
        else:
          b.getRgbaUnsafe(xFloat.round.int, yFloat.round.int)
      rgba = blendMode.mixStatic(rgba, rgba2)
      c.setRgbaUnsafe(x, y, rgba)

    when blendMode == bmIntersectMask:
      if a.width - xMax > 0:
        zeroMem(c.getAddr(xMax, y), 4*(a.width - xMax))
    else:
      when not inPlace:
        # for x in xMax ..< a.width:
        #  result.setRgbaUnsafe(x, y, a.getRgbaUnsafe(x, y))
        if a.width - xMax > 0:
          copyMem(c.getAddr(xMax, y), a.getAddr(xMax, y), 4*(a.width - xMax))

proc draw*(a, b: Image, mat: Mat3, blendMode: BlendMode) =
  ## Draws one image onto another using matrix with color blending.

  var
    matInv = mat.inverse()
    # compute movement vectors
    start = matInv * vec2(0 + h, 0 + h)
    stepX = matInv * vec2(1 + h, 0 + h) - start
    stepY = matInv * vec2(0 + h, 1 + h) - start
    minFilterBy2 = max(stepX.length, stepY.length)
    b = b
    c = a

  let corners = [
    mat * vec2(0, 0),
    mat * vec2(b.width.float32, 0),
    mat * vec2(b.width.float32, b.height.float32),
    mat * vec2(0, b.height.float32)
  ]

  let lines = [
    segment(corners[0], corners[1]),
    segment(corners[1], corners[2]),
    segment(corners[2], corners[3]),
    segment(corners[3], corners[0])
  ]

  while minFilterBy2 > 2.0:
    b = b.minifyBy2()
    start /= 2
    stepX /= 2
    stepY /= 2
    minFilterBy2 /= 2
    matInv = matInv * scale(vec2(0.5, 0.5))

  var smooth = not(stepX.length == 1.0 and stepY.length == 1.0 and
    mat[2, 0].fractional == 0.0 and mat[2, 1].fractional == 0.0)

  if not smooth:
    case blendMode
    of bmNormal: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmNormal, true, false)
    of bmDarken: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmDarken, true, false)
    of bmMultiply: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmMultiply, true, false)
    of bmLinearBurn: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLinearBurn, true, false)
    of bmColorBurn: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmColorBurn, true, false)
    of bmLighten: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLighten, true, false)
    of bmScreen: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmScreen, true, false)
    of bmLinearDodge: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLinearDodge, true, false)
    of bmColorDodge: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmColorDodge, true, false)
    of bmOverlay: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmOverlay, true, false)
    of bmSoftLight: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmSoftLight, true, false)
    of bmHardLight: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmHardLight, true, false)
    of bmDifference: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmDifference, true, false)
    of bmExclusion: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmExclusion, true, false)
    of bmHue: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmHue, true, false)
    of bmSaturation: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmSaturation, true, false)
    of bmColor: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmColor, true, false)
    of bmLuminosity: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLuminosity, true, false)
    of bmMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmMask, true, false)
    of bmOverwrite: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmOverwrite, true, false)
    of bmSubtractMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmSubtractMask, true, false)
    of bmIntersectMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmIntersectMask, true, false)
    of bmExcludeMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmExcludeMask, true, false)
  else:
    case blendMode
    of bmNormal: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmNormal, true, true)
    of bmDarken: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmDarken, true, true)
    of bmMultiply: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmMultiply, true, true)
    of bmLinearBurn: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLinearBurn, true, true)
    of bmColorBurn: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmColorBurn, true, true)
    of bmLighten: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLighten, true, true)
    of bmScreen: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmScreen, true, true)
    of bmLinearDodge: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLinearDodge, true, true)
    of bmColorDodge: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmColorDodge, true, true)
    of bmOverlay: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmOverlay, true, true)
    of bmSoftLight: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmSoftLight, true, true)
    of bmHardLight: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmHardLight, true, true)
    of bmDifference: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmDifference, true, true)
    of bmExclusion: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmExclusion, true, true)
    of bmHue: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmHue, true, true)
    of bmSaturation: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmSaturation, true, true)
    of bmColor: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmColor, true, true)
    of bmLuminosity: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmLuminosity, true, true)
    of bmMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmMask, true, true)
    of bmOverwrite: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmOverwrite, true, true)
    of bmSubtractMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmSubtractMask, true, true)
    of bmIntersectMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmIntersectMask, true, true)
    of bmExcludeMask: drawUberStatic(a, b, c, start, stepX, stepY, lines, bmExcludeMask, true, true)

proc draw*(
  a, b: Image, pos = vec2(0, 0), blendMode = bmNormal
) {.inline.} =
  a.draw(b, translate(pos), blendMode)
