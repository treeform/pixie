import bumpy, pixie/fontformats/opentype, pixie/fontformats/svgfont,
    pixie/paths, unicode, vmath

const
  AutoLineHeight* = -1.float32 ## Use default line height for the font size
  LF = Rune(10)
  SP = Rune(32)

type
  Typeface* = ref object
    opentype: OpenType
    svgFont: SvgFont

  Font* = object
    typeface*: Typeface
    size*: float32 ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or AutoLineHeight for the font's default line height.

  Arrangement* = ref object
    font*: Font
    runes*: seq[Rune]
    positions*: seq[Vec2]
    selectionRects*: seq[Rect]

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
  if rune.uint32 > SP.uint32: # Empty paths for control runes (not tofu)
    if typeface.opentype != nil:
      result = typeface.opentype.getGlyphPath(rune)
    else:
      result = typeface.svgFont.getGlyphPath(rune)

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
    var prevRune = SP
    for rune in runes.mitems:
      if prevRune.isWhiteSpace:
        rune = rune.toUpper()
      prevRune = rune

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
): Arrangement =
  ## Lays out the character glyphs and returns the arrangement.
  ## Optional parameters:
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  ## textCase: text character case
  ## wrap: enable/disable text wrapping
  ## kerning: enable/disable kerning adjustments to letter spacing
  result = Arrangement()
  result.font = font

  block: # Walk and filter runes
    var
      i = 0
      rune: Rune
    while i < text.len:
      fastRuneAt(text, i, rune, true)
      # Ignore control runes (0 - 31) except LF for now
      if rune.uint32 >= SP.uint32 or rune.uint32 == LF.uint32:
        result.runes.add(rune)

  if result.runes.len == 0:
    # No runes to typeset, early return
    return

  result.runes.convertTextCase(textCase)
  result.positions.setLen(result.runes.len)
  result.selectionRects.setLen(result.runes.len)

  let lineHeight =
    if font.lineheight >= 0:
      font.lineheight
    else:
      font.defaultLineHeight

  proc advance(
    font: Font, runes: seq[Rune], i: int, kerning: bool
  ): float32 {.inline.} =
    if kerning and i + 1 < runes.len:
      result += font.typeface.getKerningAdjustment(runes[i], runes[i + 1])
    result += font.typeface.getAdvance(runes[i])
    result *= font.scale

  var fontUnitInitialY = font.typeface.ascent + font.typeface.lineGap / 2
  if lineHeight != font.defaultLineHeight:
    fontUnitInitialY += (
      (lineHeight / font.scale) -
      (font.typeface.ascent - font.typeface.descent + font.typeface.lineGap)
    ) / 2
  let initialY = round(fontUnitInitialY * font.scale)

  var
    at: Vec2
    prevCanWrap: int
  at.y = initialY
  for i, rune in result.runes:
    if rune == LF:
      let advance = font.typeface.getAdvance(SP) * font.scale
      result.positions[i] = at
      at.x = 0
      at.y += lineHeight
      result.selectionRects[i] = rect(at.x, at.y - initialY, advance, lineHeight)
      prevCanWrap = 0
    else:
      if rune.canWrap():
        prevCanWrap = i

      let advance = advance(font, result.runes, i, kerning)
      if wrap and rune != SP and bounds.x > 0 and at.x + advance > bounds.x:
        # Wrap to new line
        at.x = 0
        at.y += lineHeight

        # Go back and wrap glyphs after the wrap index down to the next line
        if prevCanWrap > 0 and prevCanWrap != i:
          for j in prevCanWrap + 1 ..< i:
            result.positions[j] = at
            at.x += advance(font, result.runes, j, kerning)

      result.positions[i] = at
      result.selectionRects[i] = rect(at.x, at.y - initialY, advance, lineHeight)
      at.x += advance

  if hAlign != haLeft:
    # Since horizontal alignment adjustments are different for each line,
    # find the start and stop of each line of text.
    var
      lines: seq[(uint32, uint32)] # (start, stop)
      start: uint32
      prevY = result.positions[0].y
    for i, pos in result.positions:
      if pos.y != prevY:
        lines.add((start, i.uint32 - 1))
        start = i.uint32
        prevY = pos.y
    lines.add((start, result.positions.len.uint32 - 1))

    for (start, stop) in lines:
      var furthestX: float32
      for i in countdown(stop, start):
        if result.runes[i] != SP and result.runes[i] != LF:
          furthestX = result.selectionRects[i].x + result.selectionRects[i].w
          break

      var xAdjustment: float32
      case hAlign:
        of haLeft:
          discard
        of haCenter:
          xAdjustment = (bounds.x - furthestX) / 2
        of haRight:
          xAdjustment = bounds.x - furthestX

      if xAdjustment != 0:
        for i in start .. stop:
          result.positions[i].x += xAdjustment
          result.selectionRects[i].x += xAdjustment

  if vAlign != vaTop:
    let
      finalSelectionRect = result.selectionRects[^1]
      furthestY = finalSelectionRect.y + finalSelectionRect.h

    var yAdjustment: float32
    case vAlign:
      of vaTop:
        discard
      of vaMiddle:
        yAdjustment = round((bounds.y - furthestY) / 2)
      of vaBottom:
        yAdjustment = bounds.y - furthestY

    if yAdjustment != 0:
      for i in 0 ..< result.positions.len:
        result.positions[i].y += yAdjustment
        result.selectionRects[i].y += yAdjustment

proc getPath*(arrangement: Arrangement, index: int): Path =
  ## Returns the path for index.
  result = arrangement.font.typeface.getGlyphPath(arrangement.runes[index])
  result.transform(
    translate(arrangement.positions[index]) *
    scale(vec2(arrangement.font.scale))
  )

proc computeBounds*(font: Font, text: string): Vec2 =
  let arrangement = font.typeset(text)
  if arrangement.runes.len > 0:
    for rect in arrangement.selectionRects:
      result.x = max(result.x, rect.x + rect.w)
    let finalRect = arrangement.selectionRects[^1]
    result.y = finalRect.y + finalRect.h

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
