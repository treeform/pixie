import pixie/fontformats/opentype, pixie/fontformats/svgfont, pixie/paths,
    unicode, vmath

const AutoLineHeight* = -1.float32

type
  Font* = ref object
    opentype: OpenType
    svgFont: SvgFont
    size*: float32 ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or AutoLineHeight for the font's default line height.

  TypesetText* = ref object
    runes*: seq[Rune]
    positions*: seq[Vec2]

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

proc ascent(font: Font): float32 {.inline.} =
  ## The font ascender value in font units.
  if font.opentype != nil:
    font.opentype.hhea.ascender.float32
  else:
    font.svgFont.ascent

proc descent(font: Font): float32 {.inline.} =
  ## The font descender value in font units.
  if font.opentype != nil:
    font.opentype.hhea.descender.float32
  else:
    font.svgFont.descent

proc lineGap(font: Font): float32 {.inline.} =
  ## The font line gap value in font units.
  if font.opentype != nil:
    result = font.opentype.hhea.lineGap.float32

proc getGlyphPath*(font: Font, rune: Rune): Path =
  ## The glyph path for the rune.
  if font.opentype != nil:
    font.opentype.getGlyphPath(rune)
  else:
    font.svgFont.getGlyphPath(rune)

proc getGlyphAdvance(font: Font, rune: Rune): float32 =
  ## The advance for the rune in pixels.
  if font.opentype != nil:
    font.opentype.getGlyphAdvance(rune)
  else:
    font.svgFont.getGlyphAdvance(rune)

proc getKerningAdjustment(font: Font, left, right: Rune): float32 =
  ## The kerning adjustment for the rune pair, in pixels.
  if font.opentype != nil:
    font.opentype.getKerningAdjustment(left, right)
  else:
    font.svgfont.getKerningAdjustment(left, right)

proc scale*(font: Font): float32 =
  ## The scale factor to transform font units into pixels.
  if font.opentype != nil:
    font.size / font.opentype.head.unitsPerEm.float32
  else:
    font.size / font.svgFont.unitsPerEm

proc defaultLineHeight*(font: Font): float32 =
  ## The default line height in pixels for the current font size.
  let fontUnits = (font.ascent + abs(font.descent) + font.lineGap)
  round(fontUnits * font.scale)

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
): TypesetText =
  result = TypesetText()
  result.runes = toRunes(text)
  result.runes.convertTextCase(textCase)

  result.positions.setLen(result.runes.len)

  let lineHeight =
    if font.lineheight >= 0:
      font.lineheight
    else:
      font.defaultLineHeight

  proc glyphAdvance(runes: seq[Rune], font: Font, i: int): float32 {.inline.} =
    if i + 1 < runes.len:
      result += font.getKerningAdjustment(runes[i], runes[i + 1])
    result += font.getGlyphAdvance(runes[i])
    result *= font.scale

  var
    at: Vec2
    prevCanWrap: int
  at.y = round(font.ascent * font.scale)
  at.y += (lineheight - font.defaultLineHeight) / 2
  for i, rune in result.runes:
    if rune.canWrap():
      prevCanWrap = i

    let advance = glyphAdvance(result.runes, font, i)
    if bounds.x > 0 and at.x + advance > bounds.x: # Wrap to new line
      at.x = 0
      at.y += lineHeight

      # Go back and wrap glyphs after the wrap index down to the next line
      if prevCanWrap > 0 and prevCanWrap != i:
        for j in prevCanWrap + 1 ..< i:
          result.positions[j] = at
          at.x += glyphAdvance(result.runes, font, j)

    result.positions[i] = at
    at.x += advance

proc parseOtf*(buf: string): Font =
  result = Font()
  result.opentype = parseOpenType(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight

proc parseTtf*(buf: string): Font =
  parseOtf(buf)

proc parseSvgFont*(buf: string): Font =
  result = Font()
  result.svgFont = svgfont.parseSvgFont(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight
