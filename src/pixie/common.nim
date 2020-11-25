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

proc intersects*(a, b: Segment, at: var Vec2): bool =
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
