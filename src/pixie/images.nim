import chroma, chroma/blends, vmath

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

proc blitUnsafe*(destImage: Image, srcImage: Image, src, dest: Rect) =
  ## Blits rectangle from one image to the other image.
  ## * No bounds checking *
  ## Make sure that src and dest rect are in bounds.
  ## Make sure that channels for images are the same.
  ## Failure in the assumptions will case unsafe memory writes.
  ## Note: Does not do alpha or color mixing.
  for y in 0 ..< int(dest.h):
    let
      srcIdx = int(src.x) + (int(src.y) + y) * srcImage.width
      destIdx = int(dest.x) + (int(dest.y) + y) * destImage.width
    copyMem(
      destImage.data[destIdx].addr,
      srcImage.data[srcIdx].addr,
      int(dest.w) * 4
    )

proc blit*(destImage: Image, srcImage: Image, src, dest: Rect) =
  ## Blits rectangle from one image to the other image.
  ## Note: Does not do alpha or color mixing.
  doAssert src.w == dest.w and src.h == dest.h
  doAssert src.x >= 0 and src.x + src.w <= srcImage.width.float32
  doAssert src.y >= 0 and src.y + src.h <= srcImage.height.float32

  # See if the image hits the bounds and needs to be adjusted.
  var
    src = src
    dest = dest
  if dest.x < 0:
    dest.w += dest.x
    src.x -= dest.x
    src.w += dest.x
    dest.x = 0
  if dest.x + dest.w > destImage.width.float32:
    let diff = destImage.width.float32 - (dest.x + dest.w)
    dest.w += diff
    src.w += diff
  if dest.y < 0:
    dest.h += dest.y
    src.y -= dest.y
    src.h += dest.y
    dest.y = 0
  if dest.y + dest.h > destImage.height.float32:
    let diff = destImage.height.float32 - (dest.y + dest.h)
    dest.h += diff
    src.h += diff

  # See if image is entirely outside the bounds:
  if dest.x + dest.w < 0 or dest.x > destImage.width.float32:
    return
  if dest.y + dest.h < 0 or dest.y > destImage.height.float32:
    return

  blitUnsafe(destImage, srcImage, src, dest)

proc blit*(destImage: Image, srcImage: Image, pos: Vec2) =
  ## Blits rectangle from one image to the other image.
  ## Note: Does not do alpha or color mixing.
  destImage.blit(
    srcImage,
    rect(0.0, 0.0, srcImage.width.float32, srcImage.height.float32),
    rect(pos.x, pos.y, srcImage.width.float32, srcImage.height.float32)
  )

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

proc drawBlendIntegerPos*(
  destImage, srcImage: Image, pos = vec2(0, 0), blendMode = Normal,
) =
  ## Fast draw of dest + fill using offset with color blending.
  for y in 0 ..< srcImage.height:
    for x in 0 ..< srcImage.width:
      let
        srcRgba = srcImage.getRgbaUnsafe(x, y)
      if blendMode.hasEffect(srcRgba):
        let
          destRgba = destImage.getRgbaUnsafe(x + pos.x.int, y + pos.y.int)
          rgba = blendMode.mix(destRgba, srcRgba)
        # TODO: Make unsafe
        destImage[x + pos.x.int, y + pos.y.int] = rgba

proc draw*(destImage: Image, srcImage: Image, mat: Mat4, blendMode = Normal) =
  ## Draws one image onto another using matrix with color blending.
  var srcImage = srcImage
  let
    matInv = mat.inverse()
    bounds = [
      mat * vec3(-1, -1, 0),
      mat * vec3(-1, float32 srcImage.height + 1, 0),
      mat * vec3(float32 srcImage.width + 1, -1, 0),
      mat * vec3(float32 srcImage.width + 1, float32 srcImage.height + 1, 0)
    ]
  var
    boundsX: array[4, float32]
    boundsY: array[4, float32]
  for i, v in bounds:
    boundsX[i] = v.x
    boundsY[i] = v.y
  let
    xStart = max(int min(boundsX), 0)
    yStart = max(int min(boundsY), 0)
    xEnd = min(int max(boundsX), destImage.width)
    yEnd = min(int max(boundsY), destImage.height)

  var
    # compute movement vectors
    start = matInv * vec3(0.5, 0.5, 0)
    stepX = matInv * vec3(1.5, 0.5, 0) - start
    stepY = matInv * vec3(0.5, 1.5, 0) - start

    minFilterBy2 = max(stepX.length, stepY.length)

  while minFilterBy2 > 2.0:
    srcImage = srcImage.minifyBy2()
    start /= 2
    stepX /= 2
    stepY /= 2
    minFilterBy2 /= 2

  # fill the bounding rectangle
  for y in yStart ..< yEnd:
    for x in xStart ..< xEnd:
      let srcV = start + stepX * float32(x) + stepY * float32(y)
      if srcImage.inside(int srcV.x.floor, int srcV.y.floor):
        let
          srcRgba = srcImage.getRgbaSmooth(srcV.x - 0.5, srcV.y - 0.5)
        if blendMode.hasEffect(srcRgba):
          let
            destRgba = destImage.getRgbaUnsafe(x, y)
            color = blendMode.mix(destRgba, srcRgba)
          destImage.setRgbaUnsafe(x, y, color)

proc gpuDraw*(destImage: Image, srcImage: Image, mat: Mat3, blendMode = Normal): Image =
  ## Draws one image onto another using matrix with color blending.
  result = newImage(destImage.width, destImage.height)
  for y in 0 .. result.width:
    for x in 0 .. result.height:
      let srcPos = mat * vec2(x.float32, y.float32)
      var destRgba = destImage.getRgbaUnsafe(x, y)
      var srcRgba = rgba(0, 0, 0, 0)
      if srcImage.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        srcRgba = srcImage.getRgbaSmooth(srcPos.x - 0.5, srcPos.y - 0.5)
      if blendMode.hasEffect(srcRgba):
        destRgba = blendMode.mix(destRgba, srcRgba)
      result.setRgbaUnsafe(x, y, destRgba)

proc draw*(destImage: Image, srcImage: Image, pos = vec2(0, 0), blendMode = Normal) =
  destImage.draw(srcImage, translate(vec3(pos.x, pos.y, 0)), blendMode)

proc gpuDraw*(destImage: Image, srcImage: Image, pos = vec2(0, 0), blendMode = Normal): Image =
  destImage.gpuDraw(srcImage, translate(-pos), blendMode)

## Thoughts
## single draw function that takes a matrix
## if matrix is simple integer translation -> fast pass
## if matrix is a simple flip -> fast path
## if blend mode is copy -> fast path
##
## Helper function that takes x,y
## Helper function that takes x,y and rotation.
