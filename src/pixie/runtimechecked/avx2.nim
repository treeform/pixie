import chroma, nimsimd/avx2

when defined(gcc) or defined(clang):
  {.localPassc: "-mavx2".}

when defined(release):
  {.push checks: off.}

proc isOneColorAvx2*(data: var seq[ColorRGBX], start, len: int): bool =
  result = true

  let color = data[0]

  var
    i = start
    p = cast[uint](data[i].addr)
  # Align to 32 bytes
  while i < (start + len) and (p and 31) != 0:
    if data[i] != color:
      return false
    inc i
    p += 4

  let
    colorVec = mm256_set1_epi32(cast[int32](color))
    iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm256_load_si256(cast[pointer](p))
      values1 = mm256_load_si256(cast[pointer](p + 32))
      eq0 = mm256_cmpeq_epi8(values0, colorVec)
      eq1 = mm256_cmpeq_epi8(values1, colorVec)
      eq01 = mm256_and_si256(eq0, eq1)
    if mm256_movemask_epi8(eq01) != cast[int32](0xffffffff):
      return false
    p += 64
  i += 16 * iterations

  for i in i ..< start + len:
    if data[i] != color:
      return false

proc isTransparentAvx2*(data: var seq[ColorRGBX], start, len: int): bool =
  result = true

  var
    i = start
    p = cast[uint](data[i].addr)
  # Align to 32 bytes
  while i < (start + len) and (p and 31) != 0:
    if data[i].a != 0:
      return false
    inc i
    p += 4

  let
    vecZero = mm256_setzero_si256()
    iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm256_load_si256(cast[pointer](p))
      values1 = mm256_load_si256(cast[pointer](p + 32))
      values01 = mm256_or_si256(values0, values1)
      eq = mm256_cmpeq_epi8(values01, vecZero)
    if mm256_movemask_epi8(eq) != cast[int32](0xffffffff):
      return false
    p += 64
  i += 16 * iterations

  for i in i ..< start + len:
    if data[i].a != 0:
      return false

proc isOpaqueAvx2*(data: var seq[ColorRGBX], start, len: int): bool =
  result = true

  var
    i = start
    p = cast[uint](data[i].addr)
  # Align to 32 bytes
  while i < (start + len) and (p and 31) != 0:
    if data[i].a != 255:
      return false
    inc i
    p += 4

  let
    vec255 = mm256_set1_epi8(255)
    iterations = (start + len - i) div 16
  for _ in 0 ..< iterations:
    let
      values0 = mm256_load_si256(cast[pointer](p))
      values1 = mm256_load_si256(cast[pointer](p + 32))
      values01 = mm256_and_si256(values0, values1)
      eq = mm256_cmpeq_epi8(values01, vec255)
    if (mm256_movemask_epi8(eq) and 0x88888888) != 0x88888888:
      return false
    p += 64
  i += 16 * iterations

  for i in i ..< start + len:
    if data[i].a != 255:
      return false

when defined(release):
  {.pop.}
