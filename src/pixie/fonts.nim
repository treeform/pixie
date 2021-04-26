import pixie/fontformats/opentype, pixie/paths, unicode, vmath

const AutoLineHeight* = -1.float32

type
  Font* = ref object
    opentype: OpenType
    glyphPaths: Table[Rune, Path]
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

proc getGlyphPath*(font: Font, rune: Rune): Path =
  if rune notin font.glyphPaths:
    font.glyphPaths[rune] = font.opentype.parseGlyph(rune)
    font.glyphPaths[rune].transform(scale(vec2(1, -1)))
  font.glyphPaths[rune]

proc getGlyphAdvance*(font: Font, rune: Rune): float32 =
  let glyphId = font.opentype.getGlyphId(rune)
  if glyphId < font.opentype.hmtx.hMetrics.len:
    font.opentype.hmtx.hMetrics[glyphId].advanceWidth.float32
  else:
    font.opentype.hmtx.hMetrics[^1].advanceWidth.float32

proc scale*(font: Font): float32 =
  ## The scale factor to transform font units into pixels.
  font.size / font.opentype.head.unitsPerEm.float32

proc defaultLineHeight*(font: Font): float32 =
  ## The default line height in pixels for the current font size.
  round((font.ascent + abs(font.descent) + font.lineGap) * font.scale)

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

    let advance = font.getGlyphAdvance(rune) * font.scale
    if bounds.x > 0 and at.x + advance > bounds.x: # Wrap to new line
      at.x = 0
      at.y += lineHeight

      # Go back and wrap glyphs after the wrap index down to the next line
      if prevCanWrap > 0 and prevCanWrap != i:
        for j in prevCanWrap + 1 ..< i:
          positions[j] = at
          at.x += font.getGlyphAdvance(runes[j]) * font.scale

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

proc parseTtf*(buf: string): Font =
  parseOtf(buf)
