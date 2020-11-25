import chroma, blends, vmath

type
  Image* = ref object
    ## Main image object that holds the bitmap data in RGBA format.
    width*, height*: int
    data*: seq[ColorRGBA]

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

proc copy*(image: Image): Image =
  ## Copies an image creating a new image.
  result = newImage(image.width, image.height)
  result.data = image.data

proc `$`*(image: Image): string =
  ## Display the image size and channels.
  "<Image " & $image.width & "x" & $image.height & ">"

proc fractional(v: float32): float32 =
  ## Returns unsigned fraction part of the float.
  ## -13.7868723 -> 0.7868723
  result = abs(v)
  result = result - floor(result)

proc inside*(image: Image, x, y: int): bool {.inline.} =
  ## Returns true if (x, y) is inside the image.
  x >= 0 and x < image.width and
  y >= 0 and y < image.height

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
  addr image.data[image.width * y + x]

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

proc newImageFill*(width, height: int, rgba: ColorRgba): Image =
  ## Fills the image with a solid color.
  result = newImageNoInit(width, height)
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      result.setRgbaUnsafe(x, y, rgba)

proc fill*(image: Image, rgba: ColorRgba): Image =
  ## Fills the image with a solid color.
  result = newImageNoInit(image.width, image.height)
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      result.setRgbaUnsafe(x, y, rgba)

proc invert*(image: Image): Image =
  ## Inverts all of the colors and alpha.
  result = newImageNoInit(image.width, image.height)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var rgba = image.getRgbaUnsafe(x, y)
      rgba.r = 255 - rgba.r
      rgba.g = 255 - rgba.g
      rgba.b = 255 - rgba.b
      rgba.a = 255 - rgba.a
      result.setRgbaUnsafe(x, y, rgba)

proc subImage*(image: Image, x, y, w, h: int): Image =
  ## Gets a sub image of the main image.
  ## TODO handle images out of bounds faster
  # doAssert x >= 0 and y >= 0
  # doAssert x + w <= image.width and y + h <= image.height
  result = newImage(w, h)
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

func lerp(a, b: Color, v: float32): Color {.inline.} =
  result.r = lerp(a.r, b.r, v)
  result.g = lerp(a.g, b.g, v)
  result.b = lerp(a.b, b.b, v)
  result.a = lerp(a.a, b.a, v)

proc getRgbaSmooth*(image: Image, x, y: float32): ColorRGBA {.inline.} =
  ## Gets a pixel as (x, y) floats.

  proc toAlphy(c: Color): Color =
    result.r = c.r * c.a
    result.g = c.g * c.a
    result.b = c.b * c.a
    result.a = c.a

  proc fromAlphy(c: Color): Color =
    if c.a == 0:
      return
    result.r = c.r / c.a
    result.g = c.g / c.a
    result.b = c.b / c.a
    result.a = c.a

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

proc hasEffect*(blendMode: BlendMode, rgba: ColorRGBA): bool =
  ## Returns true if applying rgba with current blend mode has effect.
  case blendMode
  of bmMask:
    rgba.a != 255
  of bmOverwrite:
    true
  of bmIntersectMask:
    true
  else:
    rgba.a > 0

proc allowCopy*(blendMode: BlendMode): bool =
  ## Returns true if applying rgba with current blend mode has effect.
  case blendMode
  of bmIntersectMask:
    false
  else:
    true

proc drawOverwrite*(a: Image, b: Image, mat: Mat3): Image =
  ## Draws one image onto another using integer x,y offset with COPY.
  result = newImageNoInit(a.width, a.height)
  var matInv = mat.inverse()
  # TODO: Alternative mem-copies from a and b as scan down.
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      let srcPos = matInv * vec2(x.float32, y.float32)
      if b.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        rgba = b.getRgbaUnsafe(srcPos.x.floor.int, srcPos.y.floor.int)
      result.setRgbaUnsafe(x, y, rgba)

proc drawBlend*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImageNoInit(a.width, a.height)
  var matInv = mat.inverse()
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:

      let srcPos = matInv * vec2(x.float32, y.float32)
      if b.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        var rgba = a.getRgbaUnsafe(x, y)
        let rgba2 = b.getRgbaUnsafe(srcPos.x.floor.int, srcPos.y.floor.int)
        if blendMode.hasEffect(rgba2):
          rgba = blendMode.mix2(rgba, rgba2)
        result.setRgbaUnsafe(x, y, rgba)

      else:
        if blendMode.allowCopy():
          var rgba = a.getRgbaUnsafe(x, y)
          result.setRgbaUnsafe(x, y, rgba)
        else:
          result.setRgbaUnsafe(x, y, rgba(0,0,0,0))

proc drawBlendSmooth*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImageNoInit(a.width, a.height)

  # TODO: Implement mip maps.

  var matInv = mat.inverse()
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      let srcPos = matInv * vec2(x.float32, y.float32)
      if b.inside1px(srcPos.x, srcPos.y):
        var rgba = a.getRgbaUnsafe(x, y)
        let rgba2 = b.getRgbaSmooth(srcPos.x, srcPos.y)
        if blendMode.hasEffect(rgba2):
          rgba = blendMode.mix(rgba, rgba2)
        result.setRgbaUnsafe(x, y, rgba)
      else:
        if blendMode.allowCopy():
          var rgba = a.getRgbaUnsafe(x, y)
          result.setRgbaUnsafe(x, y, rgba)
        else:
          result.setRgbaUnsafe(x, y, rgba(0,0,0,0))

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

  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      let srcPos = matInv * vec2(x.float32 + h, y.float32 + h)
      var rgba = a.getRgbaUnsafe(x, y)
      let rgba2 = b.getRgbaSmooth(srcPos.x - h, srcPos.y - h)
      rgba = blendMode.mix(rgba, rgba2)
      result.setRgbaUnsafe(x, y, rgba)

proc drawStepper*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImageNoInit(a.width, a.height)

  type Segment = object
    ## A math segment from point "at" to point "to"
    at*: Vec2
    to*: Vec2

  proc segment(at, to: Vec2): Segment =
    result.at = at
    result.to = to

  proc intersects(a, b: Segment, at: var Vec2): bool =
    ## Checks if the a segment intersects b segment.
    ## If it returns true, at will have point of intersection
    var s1x, s1y, s2x, s2y: float32
    s1x = a.to.x - a.at.x
    s1y = a.to.y - a.at.y
    s2x = b.to.x - b.at.x
    s2y = b.to.y - b.at.y

    var s, t: float32
    s = (-s1y * (a.at.x - b.at.x) + s1x * (a.at.y - b.at.y)) /
        (-s2x * s1y + s1x * s2y)
    t = (s2x * (a.at.y - b.at.y) - s2y * (a.at.x - b.at.x)) /
        (-s2x * s1y + s1x * s2y)

    if s >= 0 and s < 1 and t >= 0 and t < 1:
      at.x = a.at.x + (t * s1x)
      at.y = a.at.y + (t * s1y)
      return true
    return false

  var
    matInv = mat.inverse()
    # compute movement vectors
    h = 0.5.float32
    start = matInv * vec2(0 + h, 0 + h)
    stepX = matInv * vec2(1 + h, 0 + h) - start
    stepY = matInv * vec2(0 + h, 1 + h) - start
    minFilterBy2 = max(stepX.length, stepY.length)
    b = b

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

  template forBlend(
    mixer: proc(a, b: ColorRGBA): ColorRGBA,
    getRgba: proc(a: Image, x, y: float32): ColorRGBA {.inline.},
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

      # for x in 0 ..< xMin:
      #   result.setRgbaUnsafe(x, y, a.getRgbaUnsafe(x, y))
      if xMin > 0:
        copyMem(result.getAddr(0, y), a.getAddr(0, y), 4*xMin)

      for x in xMin ..< xMax:
        let srcV = start + stepX * float32(x) + stepY * float32(y)
        var rgba = a.getRgbaUnsafe(x, y)
        # TODO maybe remove inside check?
        if b.inside((srcV.x - h).int, (srcV.y - h).int):
          let rgba2 = b.getRgba(srcV.x - h, srcV.y - h)
          rgba = mixer(rgba, rgba2)
        result.setRgbaUnsafe(x, y, rgba)

      #for x in xMax ..< a.width:
      #  result.setRgbaUnsafe(x, y, a.getRgbaUnsafe(x, y))
      if a.width - xMax > 0:
        copyMem(result.getAddr(xMax, y), a.getAddr(xMax, y), 4*(a.width - xMax))

  proc getRgba(a: Image, x, y: float32): ColorRGBA {.inline.} =
    a.getRgbaUnsafe(x.int, y.int)

  # TODO check pos for fractional
  if stepX.length == 1.0 and stepY.length == 1.0:
    case blendMode
    of bmNormal: forBlend(blendNormal, getRgba)
    of bmDarken: forBlend(blendDarken, getRgba)
    of bmMultiply: forBlend(blendMultiply, getRgba)
    of bmLinearBurn: forBlend(blendLinearBurn, getRgba)
    of bmColorBurn: forBlend(blendColorBurn, getRgba)
    of bmLighten: forBlend(blendLighten, getRgba)
    of bmScreen: forBlend(blendScreen, getRgba)
    of bmLinearDodge: forBlend(blendLinearDodge, getRgba)
    of bmColorDodge: forBlend(blendColorDodge, getRgba)
    of bmOverlay: forBlend(blendOverlay, getRgba)
    of bmSoftLight: forBlend(blendSoftLight, getRgba)
    of bmHardLight: forBlend(blendHardLight, getRgba)
    of bmDifference: forBlend(blendDifference, getRgba)
    of bmExclusion: forBlend(blendExclusion, getRgba)
    of bmHue: forBlend(blendHue, getRgba)
    of bmSaturation: forBlend(blendSaturation, getRgba)
    of bmColor: forBlend(blendColor, getRgba)
    of bmLuminosity: forBlend(blendLuminosity, getRgba)
    of bmMask: forBlend(blendMask, getRgba)
    of bmOverwrite: forBlend(blendOverwrite, getRgba)
    of bmSubtractMask: forBlend(blendSubtractMask, getRgba)
    of bmIntersectMask: forBlend(blendIntersectMask, getRgba)
    of bmExcludeMask: forBlend(blendExcludeMask, getRgba)
  else:
    case blendMode
    of bmNormal: forBlend(blendNormal, getRgbaSmooth)
    of bmDarken: forBlend(blendDarken, getRgbaSmooth)
    of bmMultiply: forBlend(blendMultiply, getRgbaSmooth)
    of bmLinearBurn: forBlend(blendLinearBurn, getRgbaSmooth)
    of bmColorBurn: forBlend(blendColorBurn, getRgbaSmooth)
    of bmLighten: forBlend(blendLighten, getRgbaSmooth)
    of bmScreen: forBlend(blendScreen, getRgbaSmooth)
    of bmLinearDodge: forBlend(blendLinearDodge, getRgbaSmooth)
    of bmColorDodge: forBlend(blendColorDodge, getRgbaSmooth)
    of bmOverlay: forBlend(blendOverlay, getRgbaSmooth)
    of bmSoftLight: forBlend(blendSoftLight, getRgbaSmooth)
    of bmHardLight: forBlend(blendHardLight, getRgbaSmooth)
    of bmDifference: forBlend(blendDifference, getRgbaSmooth)
    of bmExclusion: forBlend(blendExclusion, getRgbaSmooth)
    of bmHue: forBlend(blendHue, getRgbaSmooth)
    of bmSaturation: forBlend(blendSaturation, getRgbaSmooth)
    of bmColor: forBlend(blendColor, getRgbaSmooth)
    of bmLuminosity: forBlend(blendLuminosity, getRgbaSmooth)
    of bmMask: forBlend(blendMask, getRgbaSmooth)
    of bmOverwrite: forBlend(blendOverwrite, getRgbaSmooth)
    of bmSubtractMask: forBlend(blendSubtractMask, getRgbaSmooth)
    of bmIntersectMask: forBlend(blendIntersectMask, getRgbaSmooth)
    of bmExcludeMask: forBlend(blendExcludeMask, getRgbaSmooth)

proc draw*(a: Image, b: Image, mat: Mat3, blendMode = bmNormal): Image =
  ## Draws one image onto another using matrix with color blending.

  # Decide which ones of the draws best fit current parameters.
  # let ns = [-1.float32, 0, 1]
  # if mat[0, 0] in ns and mat[0, 1] in ns and
  #   mat[1, 0] in ns and mat[1, 1] in ns and
  #   mat[2, 0].fractional == 0.0 and mat[2, 1].fractional == 0.0:
  #     if blendMode == bmOverwrite:
  #       return drawOverwrite(a, b, mat)
  #     else:
  #      return drawBlend(a, b, mat, blendMode)

  # return drawCorrect(a, b, mat, blendMode)

  return drawStepper(a, b, mat, blendMode)

proc draw*(a: Image, b: Image, pos = vec2(0, 0), blendMode = bmNormal): Image =
  a.draw(b, translate(pos), blendMode)

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
      blurX.setRgbaUnsafe(x, y, c.rgba )

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

proc resize*(srcImage: Image, width, height: int): Image =
  result = newImage(width, height)
  return result.draw(
    srcImage,
    scale(vec2(
      (width + 1).float / srcImage.width.float,
      (height + 1).float / srcImage.height.float
    ))
  )

proc shift(image: Image, offset: Vec2): Image =
  ## Shifts the image by offset.
  result = newImage(image.width, image.height)
  return result.draw(image, offset)

proc spread(image: Image, spread: float32): Image =
  ## Grows the image as a mask by spread.
  result = newImage(image.width, image.height)
  assert spread > 0
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      var maxAlpha = 0.uint8
      for bx in -spread.int .. spread.int:
        for by in -spread.int .. spread.int:
          #if vec2(bx.float32, by.float32).length < spread:
          let alpha = image[x + bx, y + by].a
          if alpha > maxAlpha:
            maxAlpha = alpha
          if maxAlpha == 255:
            break
        if maxAlpha == 255:
            break
      result[x, y] = rgba(0, 0, 0, maxAlpha)

proc shadow*(
  mask: Image,
  offset: Vec2,
  spread: float,
  blur: float32,
  color: Color
): Image =
  ## Create a shadow of the image with the offset, spread and blur.
  var shadow = mask
  if offset != vec2(0, 0):
    shadow = shadow.shift(offset)
  if spread > 0:
    shadow = shadow.spread(spread)
  if blur > 0:
    shadow = shadow.blur(blur)
  result = newImageFill(mask.width, mask.height, color.rgba)
  return result.draw(shadow, blendMode = bmMask)

proc applyOpacity*(image: Image, opacity: float32): Image =
  ## Multiplies alpha of the image by opacity.
  result = newImageNoInit(image.width, image.height)
  let op = (255 * opacity).uint8
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var rgba = image.getRgbaUnsafe(x, y)
      rgba.a = ((rgba.a.uint32 * op.uint32) div 255).clamp(0, 255).uint8
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
