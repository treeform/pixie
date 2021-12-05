import pixie/common, pixie/internal, pixie/paths, strutils, tables, unicode,
    vmath, xmlparser, xmltree

type SvgFont* = ref object
  unitsPerEm*, ascent*, descent*: float32
  advances: Table[Rune, float32]
  glyphPaths: Table[Rune, Path]
  kerningPairs: Table[(Rune, Rune), float32]
  missingGlyphAdvance: float32
  missingGlyphPath: Path

proc getGlyphPath*(svgFont: SvgFont, rune: Rune): Path {.raises: [].} =
  svgFont.glyphPaths.getOrDefault(rune, svgFont.missingGlyphPath)

proc hasGlyph*(svgFont: SvgFont, rune: Rune): bool =
  rune in svgFont.glyphPaths

proc getAdvance*(svgFont: SvgFont, rune: Rune): float32 {.raises: [].} =
  svgFont.advances.getOrDefault(rune, svgFont.missingGlyphAdvance)

proc getKerningAdjustment*(
  svgFont: SvgFont, left, right: Rune
): float32 {.raises: [].} =
  let pair = (left, right)
  result = svgFont.kerningPairs.getOrDefault(pair, 0)

template failInvalid() =
  raise newException(PixieError, "Invalid SVG font data")

proc parseFloat(node: XmlNode, attr: string): float32 =
  let value = node.attr(attr)
  if value.len == 0:
    raise newException(PixieError, "SVG font missing attr " & attr)
  try:
    result = parseFloat(value)
  except:
    failInvalid()

proc parseSvgFont*(buf: string): SvgFont {.raises: [PixieError].} =
  result = SvgFont()

  let root =
    try:
      parseXml(buf)
    except:
      raise currentExceptionAsPixieError()

  let defs = root.child("defs")
  if defs == nil:
    failInvalid()

  let font = defs.child("font")
  if font == nil:
    failInvalid()

  let defaultAdvance = font.parseFloat("horiz-adv-x")

  for node in font.items:
    case node.tag:
      of "font-face":
        result.unitsPerEm = node.parseFloat("units-per-em")
        result.ascent = node.parseFloat("ascent")
        result.descent = node.parseFloat("descent")
      of "glyph":
        let
          name = node.attr("glyph-name")
          unicode = node.attr("unicode")
        if unicode.len > 0 or name == "space":
          var
            i: int
            rune: Rune
          if name == "space":
            rune = Rune(32)
          else:
            fastRuneAt(unicode, i, rune, true)
          if i == unicode.len:
            var advance = defaultAdvance
            if node.attr("horiz-adv-x").len > 0:
              advance = node.parseFloat("horiz-adv-x")
            result.advances[rune] = advance
            let path = parsePath(node.attr("d"))
            path.transform(scale(vec2(1, -1)))
            result.glyphPaths[rune] = path
          else:
            discard # Multi-rune unicode?
      of "hkern":
        # TODO "g" kerning
        let
          u1 = node.attr("u1")
          u2 = node.attr("u2")
        if u1.len > 0 and u2.len > 0:
          var
            i1, i2: int
            left, right: Rune
          fastRuneAt(u1, i1, left, true)
          fastRuneAt(u2, i2, right, true)
          if i1 == u1.len and i2 == u2.len:
            let adjustment = -node.parseFloat("k")
            result.kerningPairs[(left, right)] = adjustment
          else:
            discard # Multi-rune unicode?
      of "missing-glyph":
        var advance = defaultAdvance
        if node.attr("horiz-adv-x").len > 0:
          advance = node.parseFloat("horiz-adv-x")
        result.missingGlyphAdvance = advance
        result.missingGlyphPath = parsePath(node.attr("d"))
        result.missingGlyphPath.transform(scale(vec2(1, -1)))
      else:
        discard # Unrecognized font node child
