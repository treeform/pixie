import vmath

type
  PixieError* = object of ValueError ## Raised if an operation fails.

proc fractional*(v: float32): float32 {.inline.} =
  ## Returns unsigned fraction part of the float.
  ## -13.7868723 -> 0.7868723
  result = abs(v)
  result = result - floor(result)
