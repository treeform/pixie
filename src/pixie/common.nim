import bumpy, chroma, vmath

type
  PixieError* = object of ValueError ## Raised if an operation fails.

  BlendMode* = enum
    NormalBlend
    DarkenBlend
    MultiplyBlend
    # BlendLinearBurn
    ColorBurnBlend
    LightenBlend
    ScreenBlend
    # BlendLinearDodge
    ColorDodgeBlend
    OverlayBlend
    SoftLightBlend
    HardLightBlend
    DifferenceBlend
    ExclusionBlend
    HueBlend
    SaturationBlend
    ColorBlend
    LuminosityBlend

    MaskBlend         ## Special blend mode that is used for masking
    OverwriteBlend    ## Special blend mode that just copies pixels
    SubtractMaskBlend ## Inverse mask
    ExcludeMaskBlend

  ImageDimensions* = object
    width*, height*: int

  Image* = ref object
    ## Image object that holds bitmap data in premultiplied alpha RGBA format.
    width*, height*: int
    data*: seq[ColorRGBX]

proc newImage*(width, height: int): Image {.raises: [PixieError].} =
  ## Creates a new image with the parameter dimensions.
  if width <= 0 or height <= 0:
    raise newException(PixieError, "Image width and height must be > 0")

  result = Image()
  result.width = width
  result.height = height
  result.data = newSeq[ColorRGBX](width * height)

proc copy*(image: Image): Image {.raises: [].} =
  ## Copies the image data into a new image.
  result = Image()
  result.width = image.width
  result.height = image.height
  result.data = image.data

template dataIndex*(image: Image, x, y: int): int =
  image.width * y + x

proc mix*(a, b: ColorRGBX, t: float32): ColorRGBX {.inline, raises: [].} =
  ## Linearly interpolate between a and b using t.
  let x = round(t * 255).uint32
  result.r = ((a.r.uint32 * (255 - x) + b.r.uint32 * x + 127) div 255).uint8
  result.g = ((a.g.uint32 * (255 - x) + b.g.uint32 * x + 127) div 255).uint8
  result.b = ((a.b.uint32 * (255 - x) + b.b.uint32 * x + 127) div 255).uint8
  result.a = ((a.a.uint32 * (255 - x) + b.a.uint32 * x + 127) div 255).uint8

proc `*`*(color: ColorRGBX, opacity: float32): ColorRGBX {.raises: [].} =
  if opacity == 0:
    rgbx(0, 0, 0, 0)
  else:
    let
      x = round(opacity * 255).uint32
      r = ((color.r * x + 127) div 255).uint8
      g = ((color.g * x + 127) div 255).uint8
      b = ((color.b * x + 127) div 255).uint8
      a = ((color.a * x + 127) div 255).uint8
    rgbx(r, g, b, a)

proc `*`*(rgbx: ColorRGBX, opacity: uint8): ColorRGBX {.inline.} =
  if opacity == 0:
    discard
  elif opacity == 255:
    result = rgbx
  else:
    result = rgbx(
      ((rgbx.r.uint32 * opacity + 127) div 255).uint8,
      ((rgbx.g.uint32 * opacity + 127) div 255).uint8,
      ((rgbx.b.uint32 * opacity + 127) div 255).uint8,
      ((rgbx.a.uint32 * opacity + 127) div 255).uint8
    )

proc snapToPixels*(rect: Rect): Rect {.raises: [].} =
  let
    xMin = rect.x
    xMax = rect.x + rect.w
    yMin = rect.y
    yMax = rect.y + rect.h
  result.x = floor(xMin)
  result.w = ceil(xMax) - result.x
  result.y = floor(yMin)
  result.h = ceil(yMax) - result.y
