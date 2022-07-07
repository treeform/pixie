import chroma, nimsimd/sse2

when defined(release):
  {.push checks: off.}

proc applyOpacity*(color: M128, opacity: float32): ColorRGBX {.inline.} =
  let opacityVec = mm_set1_ps(opacity)
  var finalColor = mm_cvtps_epi32(mm_mul_ps(color, opacityVec))
  finalColor = mm_packus_epi16(finalColor, mm_setzero_si128())
  finalColor = mm_packus_epi16(finalColor, mm_setzero_si128())
  cast[ColorRGBX](mm_cvtsi128_si32(finalColor))

proc packAlphaValues(v: M128i): M128i {.inline.} =
  ## Shuffle the alpha values for these 4 colors to the first 4 bytes.
  result = mm_srli_epi32(v, 24)
  result = mm_packus_epi16(result, mm_setzero_si128())
  result = mm_packus_epi16(result, mm_setzero_si128())

proc pack4xAlphaValues*(i, j, k, l: M128i): M128i {.inline.} =
  let
    i = packAlphaValues(i)
    j = mm_slli_si128(packAlphaValues(j), 4)
    k = mm_slli_si128(packAlphaValues(k), 8)
    l = mm_slli_si128(packAlphaValues(l), 12)
  mm_or_si128(mm_or_si128(i, j), mm_or_si128(k, l))

proc unpackAlphaValues*(v: M128i): M128i {.inline, raises: [].} =
  ## Unpack the first 32 bits into 4 rgba(0, 0, 0, value).
  result = mm_unpacklo_epi8(mm_setzero_si128(), v)
  result = mm_unpacklo_epi8(mm_setzero_si128(), result)

when defined(release):
  {.pop.}
