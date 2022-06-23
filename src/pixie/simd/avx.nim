import chroma, nimsimd/avx

when defined(gcc) or defined(clang):
  {.localPassc: "-mavx".}

when defined(release):
  {.push checks: off.}

proc fillUnsafeAvx*(
  data: var seq[ColorRGBX],
  rgbx: ColorRGBX,
  start, len: int
) =
  var
    i = start
    p = cast[uint](data[i].addr)
  # Align to 32 bytes
  while i < (start + len) and (p and 31) != 0:
    data[i] = rgbx
    inc i
    p += 4
  # When supported, SIMD fill until we run out of room
  let
    iterations = (start + len - i) div 8
    colorVec = mm256_set1_epi32(cast[int32](rgbx))
  for _ in 0 ..< iterations:
    mm256_store_si256(cast[pointer](p), colorVec)
    p += 32
  i += iterations * 8
  # Fill whatever is left the slow way
  for i in i ..< start + len:
    data[i] = rgbx

when defined(release):
  {.pop.}
