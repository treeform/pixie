import bumpy, chroma, pixie/fontformats/opentype, pixie/fontformats/svgfont,
    pixie/images, pixie/masks, pixie/paints, pixie/paths, unicode, vmath

const
  AutoLineHeight* = -1.float32 ## Use default line height for the font size
  LF = Rune(10)
  SP = Rune(32)

type
  Typeface* = ref object
    opentype: OpenType
    svgFont: SvgFont
    filePath*: string

  Font* = object
    typeface*: Typeface
    size*: float32              ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or AutoLineHeight for the font's default line height.
    paint*: Paint
    textCase*: TextCase
    underline*: bool            ## Apply an underline.
    strikethrough*: bool        ## Apply a strikethrough.
    noKerningAdjustments*: bool ## Optionally disable kerning pair adjustments

  Span* = ref object
    text*: string
    font*: Font

  Arrangement* = ref object
    lines*: seq[(int, int)]    ## The (start, stop) of the lines of text.
    spans*: seq[(int, int)]    ## The (start, stop) of the spans in the text.
    fonts*: seq[Font]          ## The font for each span.
    runes*: seq[Rune]          ## The runes of the text.
    positions*: seq[Vec2]      ## The positions of the glyphs for each rune.
    selectionRects*: seq[Rect] ## The selection rects for each glyph.

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

proc lineHeight*(typeface: Typeface): float32 {.inline.} =
  ## The default line height in font units.
  typeface.ascent - typeface.descent + typeface.lineGap

proc underlinePosition(typeface: Typeface): float32 {.inline.} =
  if typeface.opentype != nil:
    result = typeface.opentype.post.underlinePosition.float32

proc underlineThickness(typeface: Typeface): float32 {.inline.} =
  if typeface.opentype != nil:
    result = typeface.opentype.post.underlineThickness.float32

proc strikeoutPosition(typeface: Typeface): float32 {.inline.} =
  if typeface.opentype != nil:
    result = typeface.opentype.os2.yStrikeoutPosition.float32

proc strikeoutThickness(typeface: Typeface): float32 {.inline.} =
  if typeface.opentype != nil:
    result = typeface.opentype.os2.yStrikeoutSize.float32

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

proc newSpan*(text: string, font: Font): Span =
  ## Creates a span, associating a font with the text.
  result = Span()
  result.text = text
  result.font = font

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

proc canWrap(rune: Rune): bool {.inline.} =
  rune == Rune(32) or rune.isWhiteSpace()

proc typeset*(
  spans: seq[Span],
  bounds = vec2(0, 0),
  hAlign = haLeft,
  vAlign = vaTop,
  wrap = true
): Arrangement =
  ## Lays out the character glyphs and returns the arrangement.
  ## Optional parameters:
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  ## wrap: enable/disable text wrapping

  result = Arrangement()

  block: # Walk and filter the spans
    var start: int
    for span in spans:
      var
        i = 0
        rune: Rune
        runes: seq[Rune]
      while i < span.text.len:
        fastRuneAt(span.text, i, rune, true)
        # Ignore control runes (0 - 31) except LF for now
        if rune.uint32 >= SP.uint32 or rune.uint32 == LF.uint32:
          runes.add(rune)

      if runes.len > 0:
        runes.convertTextCase(span.font.textCase)
        result.runes.add(runes)
        result.spans.add((start, start + runes.len - 1))
        result.fonts.add(span.font)
        start += runes.len

  if result.runes.len == 0:
    return

  result.positions.setLen(result.runes.len)
  result.selectionRects.setLen(result.runes.len)

  result.lines = @[(0, 0)] # (start, stop)

  block: # Arrange the glyphs horizontally first (handling line breaks)
    proc advance(font: Font, runes: seq[Rune], i: int): float32 {.inline.} =
      if not font.noKerningAdjustments and i + 1 < runes.len:
        result += font.typeface.getKerningAdjustment(runes[i], runes[i + 1])
      result += font.typeface.getAdvance(runes[i])
      result *= font.scale

    var
      at: Vec2
      prevCanWrap: int
    for spanIndex, (start, stop) in result.spans:
      let font = result.fonts[spanIndex]
      for runeIndex in start .. stop:
        let rune = result.runes[runeIndex]
        if rune == LF:
          let advance = font.typeface.getAdvance(SP) * font.scale
          result.positions[runeIndex] = at
          result.selectionRects[runeIndex] = rect(at.x, at.y, advance, 0)
          at.x = 0
          at.y += 1
          prevCanWrap = 0
          result.lines[^1][1] = runeIndex
          # Start a new line if we are not at the end
          if runeIndex + 1 < result.runes.len:
            result.lines.add((runeIndex + 1, 0))
        else:
          let advance = advance(font, result.runes, runeIndex)
          if wrap and rune != SP and bounds.x > 0 and at.x + advance > bounds.x:
            # Wrap to new line
            at.x = 0
            at.y += 1

            var lineStart = runeIndex

            # Go back and wrap glyphs after the wrap index down to the next line
            if prevCanWrap > 0 and prevCanWrap != runeIndex:
              for i in prevCanWrap + 1 ..< runeIndex:
                result.positions[i] = at
                result.selectionRects[i].xy = vec2(at.x, at.y)
                at.x += advance(font, result.runes, i)
                dec lineStart

            result.lines[^1][1] = lineStart - 1
            result.lines.add((lineStart, 0))

          if rune.canWrap():
            prevCanWrap = runeIndex

          result.positions[runeIndex] = at
          result.selectionRects[runeIndex] = rect(at.x, at.y, advance, 0)
          at.x += advance

    result.lines[^1][1] = result.runes.len - 1

    if hAlign != haLeft:
      # Since horizontal alignment adjustments are different for each line,
      # find the start and stop of each line of text.
      for (start, stop) in result.lines:
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

    block: # Nudge selection rects to pixel grid
      var at = result.selectionRects[0]
      at.x = round(at.x)
      for rect in result.selectionRects.mitems:
        if rect.y == at.y:
          rect.x = at.x
          rect.w = round(rect.w)
          at.x = rect.x + rect.w
        else:
          rect.w = round(rect.w)
          at.x = rect.w
          at.y = rect.y

  block: # Arrange the lines vertically
    let initialY = block:
      var maxInitialY: float32
      block outer:
        for spanIndex, (start, stop) in result.spans:
          let
            font = result.fonts[spanIndex]
            lineHeight =
              if font.lineheight >= 0:
                font.lineheight
              else:
                font.defaultLineHeight
          var fontUnitInitialY = font.typeface.ascent + font.typeface.lineGap / 2
          if lineHeight != font.defaultLineHeight:
            fontUnitInitialY += (
              (lineHeight / font.scale) - font.typeface.lineHeight
            ) / 2
          maxInitialY = max(maxInitialY, round(fontUnitInitialY * font.scale))
          for runeIndex in start .. stop:
            if runeIndex == result.lines[0][1]:
              break outer
      maxInitialY

    var lineHeights = newSeq[float32](result.lines.len)
    block: # Compute each line's line height
      var line: int
      for spanIndex, (start, stop) in result.spans:
        let
          font = result.fonts[spanIndex]
          fontLineHeight =
            if font.lineheight >= 0:
              font.lineheight
            else:
              font.defaultLineHeight
        lineHeights[line] = max(lineHeights[line], fontLineHeight)
        for runeIndex in start .. stop:
          if line + 1 < result.lines.len and
            runeIndex == result.lines[line + 1][0]:
            inc line
            lineHeights[line] = max(lineHeights[line], fontLineHeight)
        # Handle when span and line endings coincide
        if line + 1 < result.lines.len and stop == result.lines[line][1]:
          inc line

    block: # Vertically position the glyphs
      var
        line: int
        baseline = initialY
      for spanIndex, (start, stop) in result.spans:
        let
          font = result.fonts[spanIndex]
          lineHeight =
            if font.lineheight >= 0:
              font.lineheight
            else:
              font.defaultLineHeight
        for runeIndex in start .. stop:
          if line + 1 < result.lines.len and
            runeIndex == result.lines[line + 1][0]:
            inc line
            baseline += lineHeights[line]
          result.positions[runeIndex].y = baseline
          result.selectionRects[runeIndex].y =
            baseline - round(font.typeface.ascent * font.scale)
          result.selectionRects[runeIndex].h = lineHeight

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

proc typeset*(
  font: Font,
  text: string,
  bounds = vec2(0, 0),
  hAlign = haLeft,
  vAlign = vaTop,
  wrap = true
): Arrangement {.inline.} =
  ## Lays out the character glyphs and returns the arrangement.
  ## Optional parameters:
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  ## wrap: enable/disable text wrapping
  typeset(@[newSpan(text, font)], bounds, hAlign, vAlign, wrap)

proc computeBounds*(arrangement: Arrangement): Vec2 =
  ## Computes the width and height of the arrangement in pixels.
  if arrangement.runes.len > 0:
    for i in 0 ..< arrangement.runes.len:
      if arrangement.runes[i] != LF:
        let rect = arrangement.selectionRects[i]
        result.x = max(result.x, rect.x + rect.w)
    let finalRect = arrangement.selectionRects[^1]
    result.y = finalRect.y + finalRect.h

proc computeBounds*(font: Font, text: string): Vec2 {.inline.} =
  ## Computes the width and height of the text in pixels.
  font.typeset(text).computeBounds()

proc computeBounds*(spans: seq[Span]): Vec2 {.inline.} =
  ## Computes the width and height of the spans in pixels.
  typeset(spans).computeBounds()

proc parseOtf*(buf: string): Font =
  result.typeface = Typeface()
  result.typeface.opentype = parseOpenType(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight
  result.paint = rgbx(0, 0, 0, 255)

proc parseTtf*(buf: string): Font =
  parseOtf(buf)

proc parseSvgFont*(buf: string): Font =
  result.typeface = Typeface()
  result.typeface.svgFont = svgfont.parseSvgFont(buf)
  result.size = 12
  result.lineHeight = AutoLineHeight
  result.paint = Paint(kind: pkSolid, color: rgbx(0, 0, 0, 255))

proc textUber(
  target: Image | Mask,
  arrangement: Arrangement,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0,
  lineCap = lcButt,
  lineJoin = ljMiter,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[],
  stroke: static[bool] = false
) =
  var line: int
  for spanIndex, (start, stop) in arrangement.spans:
    let
      font = arrangement.fonts[spanIndex]
      underlineThickness = font.typeface.underlineThickness * font.scale
      underlinePosition = font.typeface.underlinePosition * font.scale
      strikeoutThickness = font.typeface.strikeoutThickness * font.scale
      strikeoutPosition = font.typeface.strikeoutPosition * font.scale
    for runeIndex in start .. stop:
      let position = arrangement.positions[runeIndex]

      var path = font.typeface.getGlyphPath(arrangement.runes[runeIndex])
      path.transform(
        translate(position) *
        scale(vec2(font.scale))
      )

      var applyDecoration = true
      if runeIndex == arrangement.lines[line][1]:
        inc line
        if arrangement.runes[runeIndex] == SP:
          # Do not apply decoration to the space at end of lines
          applyDecoration = false

      if applyDecoration:
        if font.underline:
          path.rect(
            arrangement.selectionRects[runeIndex].x,
            position.y - underlinePosition + underlineThickness / 2,
            arrangement.selectionRects[runeIndex].w,
            underlineThickness
          )
        if font.strikethrough:
          path.rect(
            arrangement.selectionRects[runeIndex].x,
            position.y - strikeoutPosition,
            arrangement.selectionRects[runeIndex].w,
            strikeoutThickness
          )

      when stroke:
        when type(target) is Image:
          target.strokePath(
            path,
            font.paint,
            transform,
            strokeWidth,
            lineCap,
            lineJoin,
            miterLimit,
            dashes
          )
        else: # target is Mask
          target.strokePath(
            path,
            transform,
            strokeWidth,
            lineCap,
            lineJoin,
            miterLimit,
            dashes
          )
      else:
        when type(target) is Image:
          target.fillPath(path, font.paint, transform)
        else: # target is Mask
          target.fillPath(path, transform)

proc fillText*(
  target: Image | Mask,
  arrangement: Arrangement,
  transform: Vec2 | Mat3 = vec2(0, 0)
) {.inline.} =
  ## Fills the text arrangement.
  textUber(
    target,
    arrangement,
    transform
  )

proc fillText*(
  target: Image | Mask,
  font: Font,
  text: string,
  transform: Vec2 | Mat3 = vec2(0, 0),
  bounds = vec2(0, 0),
  hAlign = haLeft,
  vAlign = vaTop
) {.inline.} =
  ## Typesets and fills the text. Optional parameters:
  ## transform: translation or matrix to apply
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  fillText(target, font.typeset(text, bounds, hAlign, vAlign), transform)

proc strokeText*(
  target: Image | Mask,
  arrangement: Arrangement,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0,
  lineCap = lcButt,
  lineJoin = ljMiter,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
) {.inline.} =
  ## Strokes the text arrangement.
  textUber(
    target,
    arrangement,
    transform,
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes,
    true
  )

proc strokeText*(
  target: Image | Mask,
  font: Font,
  text: string,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0,
  bounds = vec2(0, 0),
  hAlign = haLeft,
  vAlign = vaTop,
  lineCap = lcButt,
  lineJoin = ljMiter,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
) {.inline.} =
  ## Typesets and strokes the text. Optional parameters:
  ## transform: translation or matrix to apply
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  ## lineCap: stroke line cap shape
  ## lineJoin: stroke line join shape
  strokeText(
    target,
    font.typeset(text, bounds, hAlign, vAlign),
    transform,
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes
  )
