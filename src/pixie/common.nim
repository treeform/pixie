import chroma, vmath

type
  PixieError* = object of ValueError ## Raised if an operation fails.

proc fractional*(v: float32): float32 {.inline.} =
  ## Returns unsigned fraction part of the float.
  ## -13.7868723 -> 0.7868723
  result = abs(v)
  result = result - floor(result)

proc lerp*(a, b: ColorRGBA, t: float32): ColorRGBA {.inline.} =
  let x = round(t * 255).uint32
  result.r = ((a.r.uint32 * (255 - x) + b.r.uint32 * x) div 255).uint8
  result.g = ((a.g.uint32 * (255 - x) + b.g.uint32 * x) div 255).uint8
  result.b = ((a.b.uint32 * (255 - x) + b.b.uint32 * x) div 255).uint8
  result.a = ((a.a.uint32 * (255 - x) + b.a.uint32 * x) div 255).uint8

proc toPremultipliedAlpha*(c: ColorRGBA): ColorRGBA {.inline.} =
  ## Converts a color to premultiplied alpha from straight alpha.
  result.r = ((c.r.uint16 * c.a.uint16) div 255).uint8
  result.g = ((c.g.uint16 * c.a.uint16) div 255).uint8
  result.b = ((c.b.uint16 * c.a.uint16) div 255).uint8
  result.a = c.a

proc toStraightAlpha*(c: ColorRGBA): ColorRGBA {.inline.} =
  ## Converts a color to from premultiplied alpha to straight alpha.
  result = c
  if result.a != 0 and result.a != 255:
    let multiplier = ((255 / c.a.float32) * 255).uint32
    result.r = ((result.r.uint32 * multiplier) div 255).uint8
    result.g = ((result.g.uint32 * multiplier) div 255).uint8
    result.b = ((result.b.uint32 * multiplier) div 255).uint8

func lerp*(a, b: Color, v: float32): Color {.inline.} =
  result.r = lerp(a.r, b.r, v)
  result.g = lerp(a.g, b.g, v)
  result.b = lerp(a.b, b.b, v)
  result.a = lerp(a.a, b.a, v)

proc toPremultipliedAlpha*(c: Color): Color {.inline.} =
  ## Converts a color to premultiplied alpha from straight.
  result.r = c.r * c.a
  result.g = c.g * c.a
  result.b = c.b * c.a
  result.a = c.a

proc toStraightAlpha*(c: Color): Color {.inline.} =
  ## Converts a color to from premultiplied alpha to straight.
  if c.a == 0:
    return
  result.r = c.r / c.a
  result.g = c.g / c.a
  result.b = c.b / c.a
  result.a = c.a
