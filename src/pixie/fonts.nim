import bumpy, chroma, common, os, pixie/fontformats/opentype,
    pixie/fontformats/svgfont, pixie/images, pixie/paints, pixie/paths,
    strutils, unicode, vmath

const
  autoLineHeight*: float32 = -1 ## Use default line height for the font size
  LF = Rune(10)
  SP = Rune(32)

type
  Typeface* = ref object
    opentype: OpenType
    svgFont: SvgFont
    filePath*: string
    fallbacks*: seq[Typeface]

  Font* = ref object
    typeface*: Typeface
    size*: float32              ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or autoLineHeight for the font's default line height.
    paints*: seq[Paint]
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

  HorizontalAlignment* = enum
    LeftAlign
    CenterAlign
    RightAlign

  VerticalAlignment* = enum
    TopAlign
    MiddleAlign
    BottomAlign

  TextCase* = enum
    NormalCase
    UpperCase
    LowerCase
    TitleCase
    # tcSmallCaps
    # tcSmallCapsForced

proc scale*(typeface: Typeface): float32 {.inline, raises: [].} =
  ## The scale factor to transform font units into pixels.
  if typeface.opentype != nil:
    typeface.opentype.head.unitsPerEm.float32
  else:
    typeface.svgFont.unitsPerEm

proc ascent*(typeface: Typeface): float32 {.raises: [].} =
  ## The font ascender value in font units.
  if typeface.opentype != nil:
    typeface.opentype.hhea.ascender.float32
  else:
    typeface.svgFont.ascent

proc descent*(typeface: Typeface): float32 {.raises: [].} =
  ## The font descender value in font units.
  if typeface.opentype != nil:
    typeface.opentype.hhea.descender.float32
  else:
    typeface.svgFont.descent

proc lineGap*(typeface: Typeface): float32 {.raises: [].} =
  ## The font line gap value in font units.
  if typeface.opentype != nil:
    result = typeface.opentype.hhea.lineGap.float32

proc lineHeight*(typeface: Typeface): float32 {.inline, raises: [].} =
  ## The default line height in font units.
  # The descent is negative number, so this is really ascent + descent + lineGap.
  typeface.ascent - typeface.descent + typeface.lineGap

proc underlinePosition(typeface: Typeface): float32 =
  if typeface.opentype != nil:
    result = typeface.opentype.post.underlinePosition.float32

proc underlineThickness(typeface: Typeface): float32 =
  if typeface.opentype != nil:
    result = typeface.opentype.post.underlineThickness.float32

proc strikeoutPosition(typeface: Typeface): float32 =
  if typeface.opentype != nil:
    result = typeface.opentype.os2.yStrikeoutPosition.float32

proc strikeoutThickness(typeface: Typeface): float32 =
  if typeface.opentype != nil:
    result = typeface.opentype.os2.yStrikeoutSize.float32

proc isCCW(typeface: Typeface): bool {.inline.} =
  ## Returns the expected winding order of a font.
  if typeface.opentype != nil:
    return typeface.opentype.isCCW()

proc hasGlyph*(typeface: Typeface, rune: Rune): bool {.inline.} =
  ## Returns if there is a glyph for this rune.
  if typeface.opentype != nil:
    typeface.opentype.hasGlyph(rune)
  else:
    typeface.svgFont.hasGlyph(rune)

proc fallbackTypeface*(typeface: Typeface, rune: Rune): Typeface =
  ## Looks through fallback typefaces to find one that has the glyph.
  if typeface.hasGlyph(rune):
    return typeface
  for fallback in typeface.fallbacks:
    let typeface = fallback.fallbackTypeface(rune)
    if typeface != nil:
      return typeface

proc getGlyphPath*(
  typeface: Typeface, rune: Rune
): Path {.inline, raises: [PixieError].} =
  ## The glyph path for the rune.
  result = newPath()

  let typeface2 = typeface.fallbackTypeface(rune)
  if typeface2 == nil:
    return

  if typeface2.opentype != nil:
    result.addPath(typeface2.opentype.getGlyphPath(rune))
  else:
    result.addPath(typeface2.svgFont.getGlyphPath(rune))

  # Apply typeface ratio.
  let ratio = typeface.scale / typeface2.scale
  if ratio != 1.0:
    result.transform(scale(vec2(ratio, ratio)))

proc getAdvance*(typeface: Typeface, rune: Rune): float32 {.inline, raises: [].} =
  ## The advance for the rune in pixels.
  var typeface2 = typeface.fallbackTypeface(rune)
  if typeface2 == nil:
    # Get tofu advance, see tofu_advance test.
    typeface2 = typeface

  if typeface2.opentype != nil:
    result = typeface2.opentype.getAdvance(rune)
  else:
    result = typeface2.svgFont.getAdvance(rune)

  # Apply typeface ratio.
  result *= typeface.scale / typeface2.scale

proc getKerningAdjustment*(
  typeface: Typeface, left, right: Rune
): float32 {.inline, raises: [].} =
  ## The kerning adjustment for the rune pair, in pixels.
  let
    typefaceRight = typeface.fallbackTypeface(right)
    typefaceLeft = typeface.fallbackTypeface(left)
  # Is there a type face that matches?
  if typefaceRight == nil or typefaceLeft == nil:
    return
  # Only do kerning if both typefaces are the same.
  if typefaceRight == typefaceLeft:
    if typefaceRight.opentype != nil:
      result = typefaceRight.opentype.getKerningAdjustment(left, right)
    else:
      result = typefaceRight.svgfont.getKerningAdjustment(left, right)

    # Apply typeface ratio.
    result *= typeface.scale / typefaceRight.scale

proc scale*(font: Font): float32 {.inline, raises: [].} =
  ## The scale factor to transform font units into pixels.
  font.size / font.typeface.scale

proc defaultLineHeight*(font: Font): float32 {.inline, raises: [].} =
  ## The default line height in pixels for the current font size.
  let fontUnits =
    font.typeface.ascent - font.typeface.descent + font.typeface.lineGap
  round(fontUnits * font.scale)

proc lineGap(font: Font): float32 =
  ## The line gap in font units for the current font size and line-height.
  let lineHeight =
    if font.lineHeight >= 0:
      font.lineHeight
    else:
      font.defaultLineHeight
  if lineHeight == font.defaultLineHeight:
    font.typeface.lineGap
  else:
    (lineHeight / font.scale) - font.typeface.ascent + font.typeface.descent

proc paint*(font: Font): Paint {.inline, raises: [].} =
  font.paints[0]

proc `paint=`*(font: Font, paint: Paint) {.inline, raises: [].} =
  font.paints = @[paint]

proc newFont*(typeface: Typeface): Font {.raises: [].} =
  result = Font()
  result.typeface = typeface
  result.size = 12
  result.lineHeight = autoLineHeight
  result.paint = newPaint(SolidPaint)
  result.paint.color = color(0, 0, 0, 1)

proc copy*(font: Font): Font {.raises: [].} =
  result = Font()
  result.typeface = font.typeface
  result.size = font.size
  result.lineHeight = font.lineHeight
  result.paints = font.paints
  result.textCase = font.textCase
  result.underline = font.underline
  result.strikethrough = font.strikethrough
  result.noKerningAdjustments = font.noKerningAdjustments

proc newSpan*(text: string, font: Font): Span {.raises: [].} =
  ## Creates a span, associating a font with the text.
  result = Span()
  result.text = text
  result.font = font

proc convertTextCase(runes: var seq[Rune], textCase: TextCase) =
  case textCase:
  of NormalCase:
    discard
  of UpperCase:
    for rune in runes.mitems:
      rune = rune.toUpper()
  of LowerCase:
    for rune in runes.mitems:
      rune = rune.toLower()
  of TitleCase:
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
  hAlign = LeftAlign,
  vAlign = TopAlign,
  wrap = true
): Arrangement {.raises: [].} =
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
              prevCanWrap = 0

            result.lines[^1][1] = lineStart - 1
            result.lines.add((lineStart, 0))

          if rune.canWrap():
            prevCanWrap = runeIndex

          result.positions[runeIndex] = at
          result.selectionRects[runeIndex] = rect(at.x, at.y, advance, 0)
          at.x += advance

    result.lines[^1][1] = result.runes.len - 1

    if hAlign != LeftAlign:
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
          of LeftAlign:
            discard
          of CenterAlign:
            xAdjustment = (bounds.x - furthestX) / 2
          of RightAlign:
            xAdjustment = bounds.x - furthestX

        if xAdjustment != 0:
          for i in start .. stop:
            result.positions[i].x += xAdjustment
            result.selectionRects[i].x += xAdjustment

  block: # Arrange the lines vertically
    let initialY = block:
      var maxInitialY: float32
      block outer:
        for spanIndex, (start, stop) in result.spans:
          let
            font = result.fonts[spanIndex]
            fontUnitInitialY = font.typeface.ascent + font.lineGap / 2
          maxInitialY = max(maxInitialY, round(fontUnitInitialY * font.scale))
          if stop >= result.lines[0][1]:
            break outer
      maxInitialY

    var lineHeights = newSeq[float32](result.lines.len)
    block: # Compute each line's line height
      var line: int
      for spanIndex, (start, stop) in result.spans:
        let
          font = result.fonts[spanIndex]
          fontLineHeight =
            if font.lineHeight >= 0:
              font.lineHeight
            else:
              font.defaultLineHeight
        lineHeights[line] = max(lineHeights[line], fontLineHeight)
        for runeIndex in start .. stop:
          # This span could be many lines. This check can be made faster by
          # hopping based on line endings instead of checking each index.
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
            if font.lineHeight >= 0:
              font.lineHeight
            else:
              font.defaultLineHeight
        for runeIndex in start .. stop:
          if line + 1 < result.lines.len and
            runeIndex == result.lines[line + 1][0]:
            inc line
            baseline += lineHeights[line]
          result.positions[runeIndex].y = baseline
          result.selectionRects[runeIndex].y = baseline -
            round((font.typeface.ascent + font.lineGap / 2) * font.scale)
          result.selectionRects[runeIndex].h = lineHeight

    if vAlign != TopAlign:
      let
        finalSelectionRect = result.selectionRects[^1]
        furthestY = finalSelectionRect.y + finalSelectionRect.h

      var yAdjustment: float32
      case vAlign:
        of TopAlign:
          discard
        of MiddleAlign:
          yAdjustment = round((bounds.y - furthestY) / 2)
        of BottomAlign:
          yAdjustment = bounds.y - furthestY

      if yAdjustment != 0:
        for i in 0 ..< result.positions.len:
          result.positions[i].y += yAdjustment
          result.selectionRects[i].y += yAdjustment

  block: # Nudge selection rects to pixel grid
    for rect in result.selectionRects.mitems:
      let
        minX = round(rect.x)
        maxX = round(rect.x + rect.w)
        minY = round(rect.y)
        maxY = round(rect.y + rect.h)
      rect.x = minX
      rect.w = maxX - minX
      rect.y = minY
      rect.h = maxY - minY

proc typeset*(
  font: Font,
  text: string,
  bounds = vec2(0, 0),
  hAlign = LeftAlign,
  vAlign = TopAlign,
  wrap = true
): Arrangement {.inline, raises: [].} =
  ## Lays out the character glyphs and returns the arrangement.
  ## Optional parameters:
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  ## wrap: enable/disable text wrapping
  typeset(@[newSpan(text, font)], bounds, hAlign, vAlign, wrap)

proc layoutBounds*(arrangement: Arrangement): Vec2 {.raises: [].} =
  ## Computes the width and height of the arrangement in pixels.
  if arrangement.runes.len > 0:
    for i in 0 ..< arrangement.runes.len:
      if arrangement.runes[i] != LF:
        # Don't add width of a new line rune.
        let rect = arrangement.selectionRects[i]
        result.x = max(result.x, rect.x + rect.w)
    let finalRect = arrangement.selectionRects[^1]
    result.y = finalRect.y + finalRect.h
    if arrangement.runes[^1] == LF:
      # If the text ends with a new line, we need add another line height.
      result.y += finalRect.h

proc layoutBounds*(font: Font, text: string): Vec2 {.inline, raises: [].} =
  ## Computes the width and height of the text in pixels.
  font.typeset(text).layoutBounds()

proc layoutBounds*(spans: seq[Span]): Vec2 {.inline, raises: [].} =
  ## Computes the width and height of the spans in pixels.
  typeset(spans).layoutBounds()

proc parseOtf*(buf: string): Typeface {.raises: [PixieError].} =
  result = Typeface()
  result.opentype = parseOpenType(buf)

proc parseTtf*(buf: string): Typeface {.raises: [PixieError].} =
  parseOtf(buf)

proc parseSvgFont*(buf: string): Typeface {.raises: [PixieError].} =
  result = Typeface()
  result.svgFont = svgfont.parseSvgFont(buf)

proc computePaths(arrangement: Arrangement): seq[Path] =
  ## Takes an Arrangement and computes Paths for drawing.
  ## Returns a seq of paths that match the seq of Spans in the arrangement.
  ## If you only have one Span you will only get one Path.
  var line: int
  for spanIndex, (start, stop) in arrangement.spans:
    let
      spanPath = newPath()
      font = arrangement.fonts[spanIndex]
      underlineThickness = font.typeface.underlineThickness * font.scale
      underlinePosition = font.typeface.underlinePosition * font.scale
      strikeoutThickness = font.typeface.strikeoutThickness * font.scale
      strikeoutPosition = font.typeface.strikeoutPosition * font.scale
    for runeIndex in start .. stop:
      let
        position = arrangement.positions[runeIndex]
        path = font.typeface.getGlyphPath(arrangement.runes[runeIndex])
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
            underlineThickness,
            font.typeface.isCCW()
          )
        if font.strikethrough:
          path.rect(
            arrangement.selectionRects[runeIndex].x,
            position.y - strikeoutPosition,
            arrangement.selectionRects[runeIndex].w,
            strikeoutThickness,
            font.typeface.isCCW()
          )

      spanPath.addPath(path)
    result.add(spanPath)

proc textUber(
  target: Image,
  arrangement: Arrangement,
  transform = mat3(),
  strokeWidth: float32 = 1.0,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[],
  stroke: static[bool] = false
) =
  let spanPaths = arrangement.computePaths()
  for spanIndex in 0 ..< arrangement.spans.len:
    let path = spanPaths[spanIndex]
    when stroke:
      let font = arrangement.fonts[spanIndex]
      for paint in font.paints:
        target.strokePath(
          path,
          paint,
          transform,
          strokeWidth,
          lineCap,
          lineJoin,
          miterLimit,
          dashes
        )
    else:
      let font = arrangement.fonts[spanIndex]
      for paint in font.paints:
        target.fillPath(path, paint, transform)

proc computeBounds*(
  arrangement: Arrangement,
  transform = mat3()
): Rect {.raises: [PixieError].} =
  let fullPath = newPath()
  for path in arrangement.computePaths():
    fullPath.addPath(path)
  fullPath.transform(transform)
  fullPath.computeBounds()

proc fillText*(
  target: Image,
  arrangement: Arrangement,
  transform = mat3()
) {.inline, raises: [PixieError].} =
  ## Fills the text arrangement.
  textUber(
    target,
    arrangement,
    transform
  )

proc fillText*(
  target: Image,
  font: Font,
  text: string,
  transform = mat3(),
  bounds = vec2(0, 0),
  hAlign = LeftAlign,
  vAlign = TopAlign
) {.inline, raises: [PixieError].} =
  ## Typesets and fills the text. Optional parameters:
  ## transform: translation or matrix to apply
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  fillText(target, font.typeset(text, bounds, hAlign, vAlign), transform)

proc strokeText*(
  target: Image,
  arrangement: Arrangement,
  transform = mat3(),
  strokeWidth: float32 = 1.0,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
) {.inline, raises: [PixieError].} =
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
  target: Image,
  font: Font,
  text: string,
  transform = mat3(),
  strokeWidth: float32 = 1.0,
  bounds = vec2(0, 0),
  hAlign = LeftAlign,
  vAlign = TopAlign,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
) {.inline, raises: [PixieError].} =
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

proc readTypeface*(filePath: string): Typeface {.raises: [PixieError].} =
  ## Loads a typeface from a file.
  try:
    result =
      case splitFile(filePath).ext.toLowerAscii():
        of ".ttf":
          parseTtf(readFile(filePath))
        of ".otf":
          parseOtf(readFile(filePath))
        of ".svg":
          parseSvgFont(readFile(filePath))
        else:
          raise newException(PixieError, "Unsupported font format")
  except IOError as e:
    raise newException(PixieError, e.msg, e)

  result.filePath = filePath

proc readTypefaces*(filePath: string): seq[Typeface] {.raises: [PixieError].} =
  ## Loads a OpenType Collection (.ttc).
  try:
    for opentype in parseOpenTypeCollection(readFile(filePath)):
      let typeface = Typeface()
      typeface.opentype = opentype
      result.add(typeface)
  except IOError as e:
    raise newException(PixieError, e.msg, e)

proc name*(typeface: Typeface): string =
  ## Returns the name of the font.
  if typeface.opentype != nil:
    return typeface.opentype.fullName

proc readFont*(filePath: string): Font {.raises: [PixieError].} =
  ## Loads a font from a file.
  newFont(readTypeface(filePath))
