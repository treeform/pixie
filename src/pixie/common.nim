import vmath

type
  PixieError* = object of ValueError ## Raised if an operation fails.

  Segment* = object
    ## A math segment from point "at" to point "to"
    at*: Vec2
    to*: Vec2

proc segment*(at, to: Vec2): Segment =
  result.at = at
  result.to = to

proc intersects*(a, b: Segment, at: var Vec2): bool {.inline.} =
  ## Checks if the a segment intersects b segment.
  ## If it returns true, at will have point of intersection
  let
    s1 = a.to - a.at
    s2 = b.to - b.at
    denominator = (-s2.x * s1.y + s1.x * s2.y)
    s = (-s1.y * (a.at.x - b.at.x) + s1.x * (a.at.y - b.at.y)) / denominator
    t = (s2.x * (a.at.y - b.at.y) - s2.y * (a.at.x - b.at.x)) / denominator

  if s >= 0 and s < 1 and t >= 0 and t < 1:
    at = a.at + (t * s1)
    return true
  return false

proc fractional*(v: float32): float32 =
  ## Returns unsigned fraction part of the float.
  ## -13.7868723 -> 0.7868723
  result = abs(v)
  result = result - floor(result)
