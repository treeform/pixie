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

proc copy*(image: Image): Image =
  ## Copies an image creating a new image.
  result = newImage(image.width, image.height)
  result.data = image.data

proc `$`*(image: Image): string =
  ## Display the image size and channels.
  "<Image " & $image.width & "x" & $image.height & ">"

proc fraction(v: float32): float32 =
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
  for i in 0 ..< image.data.len:
    image.data[i] = rgba

proc invert*(image: Image) =
  ## Inverts all of the colors and alpha.
  for rgba in image.data.mitems:
    rgba.r = 255 - rgba.r
    rgba.g = 255 - rgba.g
    rgba.b = 255 - rgba.b
    rgba.a = 255 - rgba.a

proc subImage*(image: Image, x, y, w, h: int): Image =
  ## Gets a sub image of the main image.
  doAssert x >= 0 and y >= 0
  doAssert x + w <= image.width and y + h <= image.height
  result = newImage(w, h)
  for y2 in 0 ..< h:
    for x2 in 0 ..< w:
      result.setRgbaUnsafe(x2, y2, image.getRgbaUnsafe(x2 + x, y2 + y))

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

func lerp(a, b: Color, v: float): Color {.inline.} =
  result.r = lerp(a.r, b.r, v)
  result.g = lerp(a.g, b.g, v)
  result.b = lerp(a.b, b.b, v)
  result.a = lerp(a.a, b.a, v)

proc getRgbaSmooth*(image: Image, x, y: float64): ColorRGBA {.inline.} =
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
  of bmCopy:
    true
  else:
    rgba.a > 0

proc drawFast1*(a: Image, b: Image, mat: Mat3): Image =
  ## Draws one image onto another using integer x,y offset with COPY.
  result = newImage(a.width, a.height)
  var matInv = mat.inverse()
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      let srcPos = matInv * vec2(x.float32, y.float32)
      if b.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        rgba = b.getRgbaUnsafe(srcPos.x.floor.int, srcPos.y.floor.int)
      result.setRgbaUnsafe(x, y, rgba)

proc drawFast2*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImage(a.width, a.height)
  var matInv = mat.inverse()
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      #echo x, ", ", y
      var rgba = a.getRgbaUnsafe(x, y)
      let srcPos = matInv * vec2(x.float32, y.float32)
      if b.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        let rgba2 = b.getRgbaUnsafe(srcPos.x.floor.int, srcPos.y.floor.int)
        if blendMode.hasEffect(rgba2):
          rgba = blendMode.mix(rgba, rgba2)
      result.setRgbaUnsafe(x, y, rgba)

proc drawFast3*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImage(a.width, a.height)
  var matInv = mat.inverse()
  for y in 0 ..< a.height:
    for x in 0 ..< a.width:
      var rgba = a.getRgbaUnsafe(x, y)
      let srcPos = matInv * vec2(x.float32, y.float32)
      if b.inside1px(srcPos.x, srcPos.y):
        let rgba2 = b.getRgbaSmooth(srcPos.x, srcPos.y)
        if blendMode.hasEffect(rgba2):
          rgba = blendMode.mix(rgba, rgba2)
      result.setRgbaUnsafe(x, y, rgba)

proc draw*(a: Image, b: Image, mat: Mat3, blendMode = bmNormal): Image =
  ## Draws one image onto another using matrix with color blending.
  let ns = [-1.float32, 0, 1]
  if mat[0, 0] in ns and mat[0, 1] in ns and
    mat[1, 0] in ns and mat[1, 1] in ns and
    mat[2, 0].fraction == 0.0 and mat[2, 1].fraction == 0.0:
      if blendMode == bmCopy:
        return drawFast1(
          a, b, mat
        )
      else:
        return drawFast2(
          a, b, mat, blendMode
        )
  return drawFast3(a, b, mat, blendMode)

proc draw*(a: Image, b: Image, pos = vec2(0, 0), blendMode = bmNormal): Image =
  a.draw(b, translate(pos), blendMode)


# TODO: Make methods bellow not be in place.

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
  result = newImage(mask.width, mask.height)
  result.fill(color.rgba)
  return result.draw(shadow, blendMode = bmMask)

proc invertColor*(image: Image) =
  ## Flips the image around the Y axis.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var rgba = image.getRgbaUnsafe(x, y)
      rgba.r = 255 - rgba.r
      rgba.g = 255 - rgba.g
      rgba.b = 255 - rgba.b
      rgba.a = 255 - rgba.a
      image.setRgbaUnsafe(x, y, rgba)

proc applyOpacity*(image: Image, opacity: float32) =
  ## Multiplies alpha of the image by opacity.
  let op = (255 * opacity).uint8
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var rgba = image.getRgbaUnsafe(x, y)
      rgba.a = ((rgba.a.uint32 * op.uint32) div 255).clamp(0, 255).uint8
      image.setRgbaUnsafe(x, y, rgba)

# TODO: Make this method use path's AA lines.
proc line*(image: Image, at, to: Vec2, rgba: ColorRGBA) =
  ## Draws a line from one at vec to to vec.
  let
    dx = to.x - at.x
    dy = to.y - at.y
  var x = at.x
  while true:
    if dx == 0:
      break
    let y = at.y + dy * (x - at.x) / dx
    image[int x, int y] =  rgba
    if at.x < to.x:
      x += 1
      if x > to.x:
        break
    else:
      x -= 1
      if x < to.x:
        break

  var y = at.y
  while true:
    if dy == 0:
      break
    let x = at.x + dx * (y - at.y) / dy
    image[int x, int y] = rgba
    if at.y < to.y:
      y += 1
      if y > to.y:
        break
    else:
      y -= 1
      if y < to.y:
        break
