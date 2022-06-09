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

proc mix*(a, b: uint8, t: float32): uint8 {.inline, raises: [].} =
  ## Linearly interpolate between a and b using t.
  let t = round(t * 255).uint32
  ((a * (255 - t) + b * t) div 255).uint8

proc mix*(a, b: ColorRGBX, t: float32): ColorRGBX {.inline, raises: [].} =
  ## Linearly interpolate between a and b using t.
  let x = round(t * 255).uint32
  result.r = ((a.r.uint32 * (255 - x) + b.r.uint32 * x) div 255).uint8
  result.g = ((a.g.uint32 * (255 - x) + b.g.uint32 * x) div 255).uint8
  result.b = ((a.b.uint32 * (255 - x) + b.b.uint32 * x) div 255).uint8
  result.a = ((a.a.uint32 * (255 - x) + b.a.uint32 * x) div 255).uint8

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
