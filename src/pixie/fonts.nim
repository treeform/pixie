import pixie/fontformats/opentype, pixie/fontformats/svgfont, pixie/paths,
    unicode, vmath

const AutoLineHeight* = -1.float32 ## Use default line height for the font size

type
  Typeface = ref object
    opentype: OpenType
    svgFont: SvgFont

  Font* = object
    typeface*: Typeface
    size*: float32 ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or AutoLineHeight for the font's default line height.

  Typesetting* = ref object
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

proc ascent*(typeface: Typeface): float32 {.inline.} =
  ## The font ascender value in font units.
  if typeface.opentype != nil:
    typeface.opentype.hhea.ascender.float32
  else:
    typeface.svgFont.ascent

proc descent*(typeface: Typeface): float32 {.inline.} =
  ## The font descender value in font units.
  if typeface.opentype != nil:
    typeface.opentype.hhea.descender.float32
  else:
    typeface.svgFont.descent

proc lineGap*(typeface: Typeface): float32 {.inline.} =
  ## The font line gap value in font units.
  if typeface.opentype != nil:
    result = typeface.opentype.hhea.lineGap.float32

proc getGlyphPath*(typeface: Typeface, rune: Rune): Path {.inline.} =
  ## The glyph path for the rune.
  if typeface.opentype != nil:
    typeface.opentype.getGlyphPath(rune)
  else:
    typeface.svgFont.getGlyphPath(rune)

proc getAdvance*(typeface: Typeface, rune: Rune): float32 {.inline.} =
  ## The advance for the rune in pixels.
  if typeface.opentype != nil:
    typeface.opentype.getAdvance(rune)
  else:
    typeface.svgFont.getAdvance(rune)

proc getKerningAdjustment*(
  typeface: Typeface, left, right: Rune
): float32 {.inline.} =
  ## The kerning adjustment for the rune pair, in pixels.
  if typeface.opentype != nil:
    typeface.opentype.getKerningAdjustment(left, right)
  else:
    typeface.svgfont.getKerningAdjustment(left, right)

proc scale*(font: Font): float32 {.inline.} =
  ## The scale factor to transform font units into pixels.
  if font.typeface.opentype != nil:
    font.size / font.typeface.opentype.head.unitsPerEm.float32
  else:
    font.size / font.typeface.svgFont.unitsPerEm

proc defaultLineHeight*(font: Font): float32 {.inline.} =
  ## The default line height in pixels for the current font size.
  let fontUnits =
    font.typeface.ascent - font.typeface.descent + font.typeface.lineGap
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
  textCase = tcNormal,
  wrap = true,
  kerning = true
): Typesetting =
  result = Typesetting()
  result.runes = toRunes(text)
  result.runes.convertTextCase(textCase)
  result.positions.setLen(result.runes.len)

  let lineHeight =
    if font.lineheight >= 0:
      font.lineheight
    else:
      font.defaultLineHeight

  proc glyphAdvance(
    font: Font, runes: seq[Rune], i: int, kerning: bool
  ): float32 {.inline.} =
    if kerning and i + 1 < runes.len:
      result += font.typeface.getKerningAdjustment(runes[i], runes[i + 1])
    result += font.typeface.getAdvance(runes[i])
    result *= font.scale

  var
    at: Vec2
    prevCanWrap: int
  at.y = round((font.typeface.ascent + font.typeface.lineGap / 2) * font.scale)
  at.y += (lineheight - font.defaultLineHeight) / 2
  for i, rune in result.runes:
    if rune.canWrap():
      prevCanWrap = i

    let advance = glyphAdvance(font, result.runes, i, kerning)
    if rune != Rune(32) and bounds.x > 0 and at.x + advance > bounds.x:
      # Wrap to new line
      at.x = 0
      at.y += lineHeight

      # Go back and wrap glyphs after the wrap index down to the next line
      if prevCanWrap > 0 and prevCanWrap != i:
        for j in prevCanWrap + 1 ..< i:
          result.positions[j] = at
          at.x += glyphAdvance(font, result.runes, j, kerning)

    result.positions[i] = at
    at.x += advance

iterator typesetPaths*(
  font: Font,
  text: string,
  bounds = vec2(0, 0),
  hAlign = haLeft,
  vAlign = vaTop,
  textCase = tcNormal,
  wrap = true,
  kerning = true
): Path =
  let typesetText = font.typeset(
    text,
    bounds,
    hAlign,
    vAlign,
    textCase,
    wrap,
    kerning
  )
  for i in 0 ..< typesetText.runes.len:
    var path = font.typeface.getGlyphPath(typesetText.runes[i])
    path.transform(
      translate(typesetText.positions[i]) * scale(vec2(font.scale))
    )
    yield path

proc parseOtf*(buf: string): Font =
  result.typeface = Typeface()
  result.typeface.opentype = parseOpenType(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight

proc parseTtf*(buf: string): Font =
  parseOtf(buf)

proc parseSvgFont*(buf: string): Font =
  result.typeface = Typeface()
  result.typeface.svgFont = svgfont.parseSvgFont(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight
