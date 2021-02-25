when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

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
    let
      first32 = cast[M128i]([uint32.high, 0, 0, 0])                # First 32 bits
      alphaMask = mm_set1_epi32(cast[int32](0xff000000))           # Only `a`

    result = mm_shuffle_epi32(v, MM_SHUFFLE(0, 0, 0, 0))

    var
      i = mm_and_si128(result, first32)
      j = mm_and_si128(result, mm_slli_si128(first32, 4))
      k = mm_and_si128(result, mm_slli_si128(first32, 8))
      l = mm_and_si128(result, mm_slli_si128(first32, 12))

    # Shift the values to `a`
    i = mm_slli_si128(i, 3)
    j = mm_slli_si128(j, 2)
    k = mm_slli_si128(k, 1)
    # l = mm_slli_si128(l, 0)

    result = mm_and_si128(
      mm_or_si128(mm_or_si128(i, j), mm_or_si128(k, l)),
      alphaMask
    )
