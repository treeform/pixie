import pixie/fontformats/opentype, pixie/paths, unicode, vmath

const AutoLineHeight* = -1.float32

type
  Font* = ref object
    opentype: OpenType
    glyphPaths: Table[Rune, Path]
    kerningPairs: Table[(Rune, Rune), float32]
    size*: float32 ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or AutoLineHeight for the font's default line height.

  HAlignMode* = enum
    haLeft
    haCenter
    haRight

  VAlignMode* = enum
    vaTop
    vaMiddle
    vaBottom

  TextCase* = enum
    tcNormal
    tcUpper
    tcLower
    tcTitle
    # tcSmallCaps
    # tcSmallCapsForced

proc ascent*(font: Font): float32 {.inline.} =
  ## The font ascender value in font units.
  font.opentype.hhea.ascender.float32

proc descent*(font: Font): float32 {.inline.} =
  ## The font descender value in font units.
  font.opentype.hhea.descender.float32

proc lineGap*(font: Font): float32 {.inline.} =
  ## The font line gap value in font units.
  font.opentype.hhea.lineGap.float32

proc scale*(font: Font): float32 =
  ## The scale factor to transform font units into pixels.
  font.size / font.opentype.head.unitsPerEm.float32

proc defaultLineHeight*(font: Font): float32 =
  ## The default line height in pixels for the current font size.
  round((font.ascent + abs(font.descent) + font.lineGap) * font.scale)

proc getGlyphPath*(font: Font, rune: Rune): Path =
  ## The glyph path for the parameter rune.
  if rune notin font.glyphPaths:
    font.glyphPaths[rune] = font.opentype.parseGlyph(rune)
    font.glyphPaths[rune].transform(scale(vec2(1, -1)))
  font.glyphPaths[rune]

proc getGlyphAdvance*(font: Font, rune: Rune): float32 =
  ## The advance for the parameter rune in pixels.
  let glyphId = font.opentype.getGlyphId(rune).int
  if glyphId < font.opentype.hmtx.hMetrics.len:
    result = font.opentype.hmtx.hMetrics[glyphId].advanceWidth.float32
  else:
    result = font.opentype.hmtx.hMetrics[^1].advanceWidth.float32
  result *= font.scale

proc getKerningAdjustment*(font: Font, left, right: Rune): float32 =
  ## The kerning adjustment for the parameter rune pair, in pixels.
  let pair = (left, right)
  if pair in font.kerningPairs:
    result = font.kerningPairs[pair]
  result *= font.scale

proc convertTextCase(runes: var seq[Rune], textCase: TextCase) =
  case textCase:
  of tcNormal:
    discard
  of tcUpper:
    for rune in runes.mitems:
      rune = rune.toUpper()
  of tcLower:
    for rune in runes.mitems:
      rune = rune.toLower()
  of tcTitle:
    for rune in runes.mitems:
      rune = rune.toTitle()

proc canWrap(rune: Rune): bool =
  rune == Rune(32) or rune.isWhiteSpace()

proc typeset*(
  font: Font,
  text: string,
  bounds = vec2(0, 0),
  hAlign = haLeft,
  vAlign = vaTop,
  textCase = tcNormal
): seq[Path] =
  var runes = toRunes(text)
  runes.convertTextCase(textCase)

  let lineHeight =
    if font.lineheight >= 0:
      font.lineheight
    else:
      font.defaultLineHeight

  var
    positions = newSeq[Vec2](runes.len)
    at: Vec2
    prevCanWrap: int
  at.y = round(font.ascent * font.scale)
  at.y += (lineheight - font.defaultLineHeight) / 2
  for i, rune in runes:
    if rune.canWrap():
      prevCanWrap = i

    if i > 0:
      at.x += font.getKerningAdjustment(runes[i - 1], rune)

    let advance = font.getGlyphAdvance(rune)
    if bounds.x > 0 and at.x + advance > bounds.x: # Wrap to new line
      at.x = 0
      at.y += lineHeight

      # Go back and wrap glyphs after the wrap index down to the next line
      if prevCanWrap > 0 and prevCanWrap != i:
        for j in prevCanWrap + 1 ..< i:
          if j > 0:
            at.x += font.getKerningAdjustment(runes[j - 1], runes[j])
          positions[j] = at
          at.x += font.getGlyphAdvance(runes[j])

    positions[i] = at
    at.x += advance

  for i, rune in runes:
    var path = font.getGlyphPath(rune)
    path.transform(translate(positions[i]) * scale(vec2(font.scale)))
    result.add(path)

proc parseOtf*(buf: string): Font =
  result = Font()
  result.opentype = parseOpenType(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight

  if result.opentype.kern != nil:
    for table in result.opentype.kern.subTables:
      if (table.coverage and 1) != 0: # Horizontal data
        for pair in table.kernPairs:
          if pair.value != 0 and
            pair.left in result.opentype.cmap.glyphIdToRune and
            pair.right in result.opentype.cmap.glyphIdToRune:
            let key = (
              result.opentype.cmap.glyphIdToRune[pair.left],
              result.opentype.cmap.glyphIdToRune[pair.right]
            )
            var value = pair.value.float32
            if key in result.kerningPairs:
              if (table.coverage and 0b1000) != 0: # Override
                discard
              else: # Accumulate
                value += result.kerningPairs[key]
            result.kerningPairs[key] = value

proc parseTtf*(buf: string): Font =
  parseOtf(buf)
