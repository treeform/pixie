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

proc inside*(image: Image, x, y: int): bool {.inline.} =
  ## Returns true if (x, y) is inside the image.
  x >= 0 and x < image.width and
  y >= 0 and y < image.height

proc inside1px*(image: Image, x, y: float): bool {.inline.} =
  ## Returns true if (x, y) is inside the image.
  x >= -1 and x < (image.width.float32 + 1) and
  y >= -1 and y < (image.height.float32 + 1)

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
  let
    minX = floor(x).int
    difX = (x - minX.float32)
    minY = floor(y).int
    difY = (y - minY.float32)

    vX0Y0 = image[minX, minY].color()
    vX1Y0 = image[minX + 1, minY].color()
    vX0Y1 = image[minX, minY + 1].color()
    vX1Y1 = image[minX + 1, minY + 1].color()

    bottomMix = lerp(vX0Y0, vX1Y0, difX)
    topMix = lerp(vX0Y1, vX1Y1, difX)
    finalMix = lerp(bottomMix, topMix, difY)

  return finalMix.rgba()

proc hasEffect*(blendMode: BlendMode, rgba: ColorRGBA): bool =
  ## Returns true if applying rgba with current blend mode has effect.
  case blendMode
  of Mask:
    rgba.a != 255
  of COPY:
    true
  else:
    rgba.a > 0

func translate*(v: Vec2): Mat3 =
  result[0, 0] = 1
  result[1, 1] = 1
  result[2, 0] = v.x
  result[2, 1] = v.y
  result[2, 2] = 1

proc fraction(v: float32): float32 =
  result = abs(v)
  result = result - floor(result)

proc drawFast*(a: Image, b: Image, x, y: int): Image =
  ## Draws one image onto another using integer x,y offset with COPY.
  result = newImage(a.width, a.height)
  for yd in 0 ..< a.width:
    for xd in 0 ..< a.height:
      var rgba = a.getRgbaUnsafe(xd, yd)
      if b.inside(xd + x, yd + y):
        rgba = b.getRgbaUnsafe(xd + x, yd + y)
      result.setRgbaUnsafe(xd, yd, rgba)

proc drawFast*(a: Image, b: Image, x, y: int, blendMode: BlendMode): Image =
  ## Draws one image onto another using integer x,y offset with color blending.
  result = newImage(a.width, a.height)
  for yd in 0 ..< a.width:
    for xd in 0 ..< a.height:
      var rgba = a.getRgbaUnsafe(xd, yd)
      if b.inside(xd + x, yd + y):
        var rgba2 = b.getRgbaUnsafe(xd + x, yd + y)
        if blendMode.hasEffect(rgba2):
          rgba = blendMode.mix(rgba, rgba2)
      result.setRgbaUnsafe(xd, yd, rgba)

proc drawFast*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImage(a.width, a.height)
  for y in 0 ..< a.width:
    for x in 0 ..< a.height:
      var rgba = a.getRgbaUnsafe(x, y)
      let srcPos = mat * vec2(x.float32, y.float32)
      if b.inside1px(srcPos.x, srcPos.y):
        let rgba2 = b.getRgbaSmooth(srcPos.x, srcPos.y)
        if blendMode.hasEffect(rgba2):
          rgba = blendMode.mix(rgba, rgba2)
      result.setRgbaUnsafe(x, y, rgba)

proc draw*(a: Image, b: Image, mat: Mat3, blendMode = Normal): Image =
  ## Draws one image onto another using matrix with color blending.

  if mat[0, 0] == 1 and mat[0, 1] == 0 and
    mat[1, 0] == 0 and mat[1, 1] == 1 and
    mat[2, 0].fraction == 0.0 and mat[2, 1].fraction == 0.0:
    # Matrix is simple integer translation fast path:
    if blendMode == Copy:
      echo "use 1"
      return drawFast(
        a, b, mat[2, 0].int, mat[2, 1].int
      )
    else:
      echo "use 2"
      return drawFast(
        a, b, mat[2, 0].int, mat[2, 1].int, blendMode
      )

  # Todo: if matrix is a simple flip -> fast path
  echo "use 3"
  return drawFast(a, b, mat, blendMode)


proc draw*(a: Image, b: Image, pos = vec2(0, 0), blendMode = Normal): Image =
  a.draw(b, translate(-pos), blendMode)
