import chroma, vmath

type
  PixieError* = object of ValueError ## Raised if an operation fails.

proc fractional*(v: float32): float32 {.inline.} =
  ## Returns unsigned fraction part of the float.
  ## -13.7868723 -> 0.7868723
  result = abs(v)
  result = result - floor(result)

func lerp*(a, b: Color, v: float32): Color {.inline.} =
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
