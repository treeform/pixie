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
  x >= 0 and x < image.width and y >= 0 and y < image.height

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

func moduloMod(n, M: int): int {.inline.} =
  ## Computes "mathematical" modulo vs c modulo.
  ((n mod M) + M) mod M

func lerp(a, b: Color, v: float): Color {.inline.} =
  result.r = lerp(a.r, b.r, v)
  result.g = lerp(a.g, b.g, v)
  result.b = lerp(a.b, b.b, v)
  result.a = lerp(a.a, b.a, v)

proc getRgbaSmooth*(image: Image, x, y: float64): ColorRGBA
  {.inline, raises: [].} =
  ## Gets a pixel as (x, y) floats.
  let
    minX = floor(x).int
    difX = (x - minX.float32)

    minY = floor(y).int
    difY = (y - minY.float32)

    vX0Y0 = image.getRgbaUnsafe(
      moduloMod(minX, image.width),
      moduloMod(minY, image.height),
    ).color()

    vX1Y0 = image.getRgbaUnsafe(
      moduloMod(minX + 1, image.width),
      moduloMod(minY, image.height),
    ).color()

    vX0Y1 = image.getRgbaUnsafe(
      moduloMod(minX, image.width),
      moduloMod(minY + 1, image.height),
    ).color()

    vX1Y1 = image.getRgbaUnsafe(
      moduloMod(minX + 1, image.width),
      moduloMod(minY + 1, image.height),
    ).color()

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

proc draw*(destImage: Image, srcImage: Image, mat: Mat3, blendMode = Normal): Image =
  ## Draws one image onto another using matrix with color blending.

  # Todo: if matrix is simple integer translation -> fast pass
  # Todo: if matrix is a simple flip -> fast path
  # Todo: if blend mode is copy -> fast path

  result = newImage(destImage.width, destImage.height)
  for y in 0 ..< destImage.width:
    for x in 0 ..< destImage.height:
      let srcPos = mat * vec2(x.float32, y.float32)
      let destRgba = destImage.getRgbaUnsafe(x, y)
      var rgba = destRgba
      var srcRgba = rgba(0, 0, 0, 0)
      if srcImage.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        srcRgba = srcImage.getRgbaSmooth(srcPos.x - 0.5, srcPos.y - 0.5)
      if blendMode.hasEffect(srcRgba):
        rgba = blendMode.mix(destRgba, srcRgba)
      result.setRgbaUnsafe(x, y, rgba)

proc draw*(destImage: Image, srcImage: Image, pos = vec2(0, 0), blendMode = Normal): Image =
  destImage.draw(srcImage, translate(-pos), blendMode)
