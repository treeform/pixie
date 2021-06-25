import chroma, vmath

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

proc gaussianKernel*(radius: int): seq[uint32] =
  ## Compute lookup table for 1d Gaussian kernel.
  ## Values are [0, 255] * 1024.
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
    result[i] = round(f * 255 * 1024).uint32

proc toStraightAlpha*(data: var seq[ColorRGBA | ColorRGBX]) =
  ## Converts an image from premultiplied alpha to straight alpha.
  ## This is expensive for large images.
  for c in data.mitems:
    if c.a == 0 or c.a == 255:
      continue
    let multiplier = ((255 / c.a.float32) * 255).uint32
    c.r = ((c.r.uint32 * multiplier) div 255).uint8
    c.g = ((c.g.uint32 * multiplier) div 255).uint8
    c.b = ((c.b.uint32 * multiplier) div 255).uint8

proc toPremultipliedAlpha*(data: var seq[ColorRGBA | ColorRGBX]) =
  ## Converts an image to premultiplied alpha from straight alpha.
  var i: int
  when defined(amd64) and not defined(pixieNoSimd):
    # When supported, SIMD convert as much as possible
    let
      alphaMask = mm_set1_epi32(cast[int32](0xff000000))
      notAlphaMask = mm_set1_epi32(0x00ffffff)
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))

    for j in countup(i, data.len - 4, 4):
      var
        color = mm_loadu_si128(data[j].addr)
        alpha = mm_and_si128(color, alphaMask)

      let eqOpaque = mm_cmpeq_epi16(alpha, alphaMask)
      if mm_movemask_epi8(eqOpaque) != 0xffff:
        # If not all of the alpha values are 255, premultiply
        var
          colorEven = mm_slli_epi16(color, 8)
          colorOdd = mm_and_si128(color, oddMask)

        alpha = mm_or_si128(alpha, mm_srli_epi32(alpha, 16))

        colorEven = mm_mulhi_epu16(colorEven, alpha)
        colorOdd = mm_mulhi_epu16(colorOdd, alpha)

        colorEven = mm_srli_epi16(mm_mulhi_epu16(colorEven, div255), 7)
        colorOdd = mm_srli_epi16(mm_mulhi_epu16(colorOdd, div255), 7)

        color = mm_or_si128(colorEven, mm_slli_epi16(colorOdd, 8))
        color = mm_or_si128(
          mm_and_si128(alpha, alphaMask), mm_and_si128(color, notAlphaMask)
        )

        mm_storeu_si128(data[j].addr, color)
      i += 4
  # Convert whatever is left
  for j in i ..< data.len:
    var c = data[j]
    if c.a != 255:
      c.r = ((c.r.uint32 * c.a.uint32) div 255).uint8
      c.g = ((c.g.uint32 * c.a.uint32) div 255).uint8
      c.b = ((c.b.uint32 * c.a.uint32) div 255).uint8
      data[j] = c

when defined(amd64) and not defined(pixieNoSimd):
  proc packAlphaValues*(v: M128i): M128i {.inline.} =
    ## Shuffle the alpha values for these 4 colors to the first 4 bytes
    result = mm_srli_epi32(v, 24)
    let
      i = mm_srli_si128(result, 3)
      j = mm_srli_si128(result, 6)
      k = mm_srli_si128(result, 9)
      first32 = cast[M128i]([uint32.high, 0, 0, 0])
    result = mm_or_si128(mm_or_si128(result, i), mm_or_si128(j, k))
    result = mm_and_si128(result, first32)

  proc unpackAlphaValues*(v: M128i): M128i {.inline.} =
    ## Unpack the first 32 bits into 4 rgba(0, 0, 0, value)
    let mask = cast[M128i]([uint8.high.uint64, 0])

    var
      i = mm_and_si128(v, mask)
      j = mm_and_si128(v, mm_slli_si128(mask, 1))
      k = mm_and_si128(v, mm_slli_si128(mask, 2))
      l = mm_and_si128(v, mm_slli_si128(mask, 3))

    # Shift the values to uint32 `a`
    i = mm_slli_si128(i, 3)
    j = mm_slli_si128(j, 6)
    k = mm_slli_si128(k, 9)
    l = mm_slli_si128(l, 12)

    result = mm_or_si128(mm_or_si128(i, j), mm_or_si128(k, l))
