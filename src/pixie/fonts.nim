import pixie/fontformats/opentype, pixie/paths, unicode, vmath

const AutoLineHeight* = -1.float32

type
  Typeface* = ref object
    opentype: OpenType
    glyphPaths: Table[Rune, Path]
    kerningPairs: Table[(Rune, Rune), float32]

  Font* = ref object
    typeface*: Typeface
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

proc ascent(typeface: Typeface): float32 {.inline.} =
  ## The font ascender value in font units.
  typeface.opentype.hhea.ascender.float32

proc descent(typeface: Typeface): float32 {.inline.} =
  ## The font descender value in font units.
  typeface.opentype.hhea.descender.float32

proc lineGap(typeface: Typeface): float32 {.inline.} =
  ## The font line gap value in font units.
  typeface.opentype.hhea.lineGap.float32

proc getGlyphPath*(typeface: Typeface, rune: Rune): Path =
  ## The glyph path for the rune.
  if rune notin typeface.glyphPaths:
    typeface.glyphPaths[rune] = typeface.opentype.parseGlyph(rune)
    typeface.glyphPaths[rune].transform(scale(vec2(1, -1)))
  typeface.glyphPaths[rune]

proc getGlyphAdvance(typeface: Typeface, rune: Rune): float32 =
  ## The advance for the rune in pixels.
  let glyphId = typeface.opentype.getGlyphId(rune).int
  if glyphId < typeface.opentype.hmtx.hMetrics.len:
    result = typeface.opentype.hmtx.hMetrics[glyphId].advanceWidth.float32
  else:
    result = typeface.opentype.hmtx.hMetrics[^1].advanceWidth.float32

proc getKerningAdjustment(typeface: Typeface, left, right: Rune): float32 =
  ## The kerning adjustment for the rune pair, in pixels.
  let pair = (left, right)
  if pair in typeface.kerningPairs:
    result = typeface.kerningPairs[pair]

proc scale*(font: Font): float32 =
  ## The scale factor to transform font units into pixels.
  font.size / font.typeface.opentype.head.unitsPerEm.float32

proc defaultLineHeight*(font: Font): float32 =
  ## The default line height in pixels for the current font size.
  round((font.typeface.ascent + abs(font.typeface.descent) + font.typeface.lineGap) * font.scale)

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

  proc glyphAdvance(runes: seq[Rune], font: Font, i: int): float32 =
    if i + 1 < runes.len:
      result += font.typeface.getKerningAdjustment(runes[i], runes[i + 1])
    result += font.typeface.getGlyphAdvance(runes[i])
    result *= font.scale

  var
    positions = newSeq[Vec2](runes.len)
    at: Vec2
    prevCanWrap: int
  at.y = round(font.typeface.ascent * font.scale)
  at.y += (lineheight - font.defaultLineHeight) / 2
  for i, rune in runes:
    if rune.canWrap():
      prevCanWrap = i

    let advance = glyphAdvance(runes, font, i)
    if bounds.x > 0 and at.x + advance > bounds.x: # Wrap to new line
      at.x = 0
      at.y += lineHeight

      # Go back and wrap glyphs after the wrap index down to the next line
      if prevCanWrap > 0 and prevCanWrap != i:
        for j in prevCanWrap + 1 ..< i:
          positions[j] = at
          at.x += glyphAdvance(runes, font, j)

    positions[i] = at
    at.x += advance

  for i, rune in runes:
    var path = font.typeface.getGlyphPath(rune)
    path.transform(translate(positions[i]) * scale(vec2(font.scale)))
    result.add(path)

proc parseOtf*(buf: string): Font =
  result = Font()
  result.typeface = Typeface()
  result.typeface.opentype = parseOpenType(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight

  if result.typeface.opentype.kern != nil:
    for table in result.typeface.opentype.kern.subTables:
      if (table.coverage and 1) != 0: # Horizontal data
        for pair in table.kernPairs:
          if pair.value != 0 and
            pair.left in result.typeface.opentype.cmap.glyphIdToRune and
            pair.right in result.typeface.opentype.cmap.glyphIdToRune:
            let key = (
              result.typeface.opentype.cmap.glyphIdToRune[pair.left],
              result.typeface.opentype.cmap.glyphIdToRune[pair.right]
            )
            var value = pair.value.float32
            if key in result.typeface.kerningPairs:
              if (table.coverage and 0b1000) != 0: # Override
                discard
              else: # Accumulate
                value += result.typeface.kerningPairs[key]
            result.typeface.kerningPairs[key] = value

proc parseTtf*(buf: string): Font =
  parseOtf(buf)
