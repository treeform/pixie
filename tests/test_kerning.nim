import
  std/unicode,
  flatty/binny, pixie, pixie/fontformats/opentype

proc words(values: openArray[int]): string =
  ## Encodes big-endian words for small OpenType test tables.
  for value in values:
    result.add(char((value shr 8) and 255))
    result.add(char(value and 255))

proc writeOffset(data: var string, position, value: int) =
  ## Writes a big-endian 32-bit table offset.
  for i in 0 ..< 4:
    data[position + i] = char((value shr ((3 - i) * 8)) and 255)

proc positioning(pair: string, extensionOffset = 0): string =
  ## Wraps a pair table in a direct or extended GPOS lookup.
  let lookupType =
    if extensionOffset == 0:
      2
    else:
      9
  result = words([1, 0, 0, 0, 10, 1, 4, lookupType, 0, 1, 8])
  if extensionOffset > 0:
    result.add(words([1, 2, 0, 0]))
    result.writeOffset(26, extensionOffset)
    result.setLen(22 + extensionOffset)
  result.add(pair)

proc fontWithPositioning(positioning: string): OpenType =
  ## Substitutes a synthetic positioning table into an existing valid font.
  var data = readFile("tests/fonts/IBMPlexSans-Regular_2.ttf")
  let count = data.readUint16(4).swap().int
  for i in 0 ..< count:
    let record = 12 + i * 16
    if data[record ..< record + 4] == "GPOS":
      data.writeOffset(record + 8, data.len)
      data.writeOffset(record + 12, positioning.len)
      data.add(positioning)
      return parseOpenType(data)
  doAssert false, "The test font must contain a GPOS table"

proc expectMalformed(positioning: string) =
  ## Requires malformed extension data to raise the public Pixie error.
  var failed = false
  try:
    discard fontWithPositioning(positioning)
  except PixieError:
    failed = true
  doAssert failed

block:
  let
    original = parseOpenType(readFile("tests/fonts/IBMPlexSans-Regular_2.ttf"))
    left = original.cmap.runeToGlyphId[Rune('A')].int
    right = original.cmap.runeToGlyphId[Rune('V')].int
    pairs = [
      words([1, 12, 4, 0, 1, 18, 1, 1, left, 1, right, -49]),
      words([
        2, 24, 4, 0, 30, 38, 2, 2, 0, 0, 0, -49,
        1, 1, left, 1, left, 1, 1, 1, right, 1, 1
      ])
    ]
  echo "Testing direct and extended glyph and class kerning"
  for pair in pairs:
    for extensionOffset in [0, 8, 70_000]:
      let font = fontWithPositioning(positioning(pair, extensionOffset))
      doAssert font.getKerningAdjustment(Rune('A'), Rune('V')) == -49
      doAssert font.getKerningAdjustment(Rune('A'), Rune('A')) == 0
      doAssert font.getKerningAdjustment(Rune('V'), Rune('A')) == 0

  echo "Testing malformed positioning extensions"
  var invalid = positioning(pairs[0], 8)
  invalid[23] = char(2)
  expectMalformed(invalid)
  invalid = positioning(pairs[0], 8)
  invalid.writeOffset(26, 0)
  expectMalformed(invalid)
  invalid.writeOffset(26, int(uint32.high))
  expectMalformed(invalid)
  invalid = positioning(pairs[0], 8)
  invalid.setLen(29)
  expectMalformed(invalid)
