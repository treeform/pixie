import bumpy, chroma, common, simd, system/memory, vmath

template currentExceptionAsPixieError*(): untyped =
  ## Gets the current exception and returns it as a PixieError with stack trace.
  let e = getCurrentException()
  newException(PixieError, e.getStackTrace & e.msg, e)

template failUnsupportedBlendMode*(blendMode: BlendMode) =
  raise newException(
    PixieError,
    "Blend mode " & $blendMode & " not supported here"
  )

when defined(release):
  {.push checks: off.}

proc gaussianKernel*(radius: int): seq[uint16] {.raises: [].} =
  ## Compute lookup table for 1d Gaussian kernel.
  ## Values are [0, 255] * 256.
  result.setLen(radius * 2 + 1)

  var
    floats = newSeq[float32](result.len)
    total = 0.0
  for step in -radius .. radius:
    let
      s = radius.float32 / 2.2 # 2.2 matches Figma.
      a = 1 / sqrt(2 * PI * s^2) * exp(-1 * step.float32^2 / (2 * s^2))
    floats[step + radius] = a
    total += a
  for step in -radius .. radius:
    floats[step + radius] = floats[step + radius] / total
  for i, f in floats:
    result[i] = round(f * 255 * 256).uint16

proc intersectsInside*(a, b: Segment, at: var Vec2): bool {.inline.} =
  ## Checks if the a segment intersects b segment (excluding endpoints).
  ## If it returns true, at will have point of intersection
  let
    s1 = a.to - a.at
    s2 = b.to - b.at
    denominator = (-s2.x * s1.y + s1.x * s2.y)
    s = (-s1.y * (a.at.x - b.at.x) + s1.x * (a.at.y - b.at.y)) / denominator
    t = (s2.x * (a.at.y - b.at.y) - s2.y * (a.at.x - b.at.x)) / denominator

  if s > 0 and s < 1 and t > 0 and t < 1:
    at = a.at + (t * s1)
    return true

template getUncheckedArray*(
  image: Image, x, y: int
): ptr UncheckedArray[ColorRGBX] =
  cast[ptr UncheckedArray[ColorRGBX]](image.data[image.dataIndex(x, y)].addr)

proc fillUnsafe*(
  data: var seq[ColorRGBX], color: SomeColor, start, len: int
) {.hasSimd, raises: [].} =
  ## Fills the image data with the color starting at index start and
  ## continuing for len indices.
  let rgbx = color.asRgbx()
  # Use memset when every byte has the same value
  if rgbx.r == rgbx.g and rgbx.r == rgbx.b and rgbx.r == rgbx.a:
    nimSetMem(data[start].addr, rgbx.r.cint, len * 4)
  else:
    for i in start ..< start + len:
      data[i] = rgbx

const straightAlphaTable = block:
  var table: array[256, array[256, uint8]]
  for a in 0 ..< 256:
    let multiplier = if a > 0: (255 / a.float32) else: 0
    for c in 0 ..< 256:
      table[a][c] = min(round((c.float32 * multiplier)), 255).uint8
  table

proc toStraightAlpha*(data: var seq[ColorRGBA | ColorRGBX]) {.raises: [].} =
  ## Converts an image from premultiplied alpha to straight alpha.
  ## This is expensive for large images.
  for i in 0 ..< data.len:
    var c = data[i]
    c.r = straightAlphaTable[c.a][c.r]
    c.g = straightAlphaTable[c.a][c.g]
    c.b = straightAlphaTable[c.a][c.b]
    data[i] = c

proc toPremultipliedAlpha*(
  data: var seq[ColorRGBA | ColorRGBX]
) {.hasSimd, raises: [].} =
  ## Converts an image to premultiplied alpha from straight alpha.
  for i in 0 ..< data.len:
    var c = data[i]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a + 127) div 255).uint8
      c.g = ((c.g.uint32 * c.a + 127) div 255).uint8
      c.b = ((c.b.uint32 * c.a + 127) div 255).uint8
      data[i] = c

proc isOpaque*(data: var seq[ColorRGBX], start, len: int): bool {.hasSimd.} =
  result = true
  for i in start ..< start + len:
    if data[i].a != 255:
      return false

when defined(release):
  {.pop.}
