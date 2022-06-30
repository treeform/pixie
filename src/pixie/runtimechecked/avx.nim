import chroma, nimsimd/avx

when defined(gcc) or defined(clang):
  {.localPassc: "-mavx".}

when defined(release):
  {.push checks: off.}

proc fillUnsafeAvx*(
  data: ptr UncheckedArray[ColorRGBX],
  len: int,
  color: SomeColor
) =
  let rgbx = color.asRgbx()

  var i: int
  while i < len and (cast[uint](data[i].addr) and 31) != 0: # Align to 32 bytes
    data[i] = rgbx
    inc i

  let
    iterations = (len - i) div 8
    colorVec = mm256_set1_epi32(cast[int32](rgbx))
  for _ in 0 ..< iterations:
    mm256_store_si256(data[i].addr, colorVec)
    i += 8
  # Fill whatever is left the slow way
  for i in i ..< len:
    data[i] = rgbx

when defined(release):
  {.pop.}
