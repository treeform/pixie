import bumpy, chroma, flatty/binny, os, pixie/blends, pixie/common,
    pixie/fileformats/bmp, pixie/fileformats/gif, pixie/fileformats/jpg,
    pixie/fileformats/png, pixie/fileformats/svg, pixie/fonts, pixie/images,
    pixie/masks, pixie/paints, pixie/paths, strutils, vmath

export blends, bumpy, chroma, common, fonts, images, masks, paints, paths, vmath

type
  FileFormat* = enum
    ffPng, ffBmp, ffJpg, ffGif

proc readFont*(filePath: string): Font =
  ## Loads a font from a file.
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
  result.typeface.filePath = filePath

converter autoStraightAlpha*(c: ColorRGBX): ColorRGBA {.inline.} =
  ## Convert a paremultiplied alpha RGBA to a straight alpha RGBA.
  c.rgba()

converter autoPremultipliedAlpha*(c: ColorRGBA): ColorRGBX {.inline.} =
  ## Convert a straight alpha RGBA to a premultiplied alpha RGBA.
  c.rgbx()

proc decodeImage*(data: string | seq[uint8]): Image =
  ## Loads an image from a memory.
  if data.len > 8 and data.readUint64(0) == cast[uint64](pngSignature):
    decodePng(data)
  elif data.len > 2 and data.readUint16(0) == cast[uint16](jpgStartOfImage):
    decodeJpg(data)
  elif data.len > 2 and data.readStr(0, 2) == bmpSignature:
    decodeBmp(data)
  elif data.len > 5 and
    (data.readStr(0, 5) == xmlSignature or data.readStr(0, 4) == svgSignature):
    decodeSvg(data)
  elif data.len > 6 and data.readStr(0, 6) in gifSignatures:
    decodeGif(data)
  else:
    raise newException(PixieError, "Unsupported image file format")

proc readImage*(filePath: string): Image =
  ## Loads an image from a file.
  decodeImage(readFile(filePath))

proc encodeImage*(image: Image, fileFormat: FileFormat): string =
  ## Encodes an image into memory.
  case fileFormat:
  of ffPng:
    image.encodePng()
  of ffJpg:
    image.encodeJpg()
  of ffBmp:
    image.encodeBmp()
  of ffGif:
    raise newException(PixieError, "Unsupported image format")

proc writeFile*(image: Image, filePath: string, fileFormat: FileFormat) =
  ## Writes an image to a file.
  writeFile(filePath, image.encodeImage(fileFormat))

proc writeFile*(image: Image, filePath: string) =
  ## Writes an image to a file.
  let fileFormat = case splitFile(filePath).ext.toLowerAscii():
    of ".png": ffPng
    of ".bmp": ffBmp
    of ".jpg", ".jpeg": ffJpg
    else:
      raise newException(PixieError, "Unsupported image file extension")
  image.writeFile(filePath, fileformat)

proc fillRect*(
  image: Image,
  rect: Rect,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a rectangle.
  var path: Path
  path.rect(rect)
  image.fillPath(path, color, transform)

proc fillRect*(
  mask: Mask,
  rect: Rect,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a rectangle.
  var path: Path
  path.rect(rect)
  mask.fillPath(path, transform)

proc strokeRect*(
  image: Image,
  rect: Rect,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a rectangle.
  var path: Path
  path.rect(rect)
  image.strokePath(path, color, transform, strokeWidth)

proc strokeRect*(
  mask: Mask,
  rect: Rect,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a rectangle.
  var path: Path
  path.rect(rect)
  mask.strokePath(path, transform, strokeWidth)

proc fillRoundedRect*(
  image: Image,
  rect: Rect,
  nw, ne, se, sw: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a rounded rectangle.
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  image.fillPath(path, color, transform)

proc fillRoundedRect*(
  image: Image,
  rect: Rect,
  radius: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a rounded rectangle.
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  image.fillPath(path, color, transform)

proc fillRoundedRect*(
  mask: Mask,
  rect: Rect,
  nw, ne, se, sw: float32,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a rounded rectangle.
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  mask.fillPath(path, transform)

proc fillRoundedRect*(
  mask: Mask,
  rect: Rect,
  radius: float32,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a rounded rectangle.
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  mask.fillPath(path, transform)

proc strokeRoundedRect*(
  image: Image,
  rect: Rect,
  nw, ne, se, sw: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a rounded rectangle.
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  image.strokePath(path, color, transform, strokeWidth)

proc strokeRoundedRect*(
  image: Image,
  rect: Rect,
  radius: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a rounded rectangle.
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  image.strokePath(path, color, transform, strokeWidth)

proc strokeRoundedRect*(
  mask: Mask,
  rect: Rect,
  nw, ne, se, sw: float32,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a rounded rectangle.
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  mask.strokePath(path, transform, strokeWidth)

proc strokeRoundedRect*(
  mask: Mask,
  rect: Rect,
  radius: float32,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a rounded rectangle.
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  mask.strokePath(path, transform, strokeWidth)

proc strokeSegment*(
  image: Image,
  segment: Segment,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a segment (draws a line from segment.at to segment.to).
  var path: Path
  path.moveTo(segment.at)
  path.lineTo(segment.to)
  image.strokePath(path, color, transform, strokeWidth)

proc strokeSegment*(
  mask: Mask,
  segment: Segment,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a segment (draws a line from segment.at to segment.to).
  var path: Path
  path.moveTo(segment.at)
  path.lineTo(segment.to)
  mask.strokePath(path, transform, strokeWidth)

proc fillEllipse*(
  image: Image,
  center: Vec2,
  rx, ry: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  blendMode = bmNormal
) =
  ## Fills an ellipse.
  var path: Path
  path.ellipse(center, rx, ry)
  image.fillPath(path, color, transform, wrNonZero, blendMode)

proc fillEllipse*(
  mask: Mask,
  center: Vec2,
  rx, ry: float32,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills an ellipse.
  var path: Path
  path.ellipse(center, rx, ry)
  mask.fillPath(path, transform)

proc strokeEllipse*(
  image: Image,
  center: Vec2,
  rx, ry: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes an ellipse.
  var path: Path
  path.ellipse(center, rx, ry)
  image.strokePath(path, color, transform, strokeWidth)

proc strokeEllipse*(
  mask: Mask,
  center: Vec2,
  rx, ry: float32,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes an ellipse.
  var path: Path
  path.ellipse(center, rx, ry)
  mask.strokePath(path, transform, strokeWidth)

proc fillCircle*(
  image: Image,
  center: Vec2,
  radius: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a circle.
  var path: Path
  path.ellipse(center, radius, radius)
  image.fillPath(path, color, transform)

proc fillCircle*(
  mask: Mask,
  center: Vec2,
  radius: float32,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a circle.
  var path: Path
  path.ellipse(center, radius, radius)
  mask.fillPath(path, transform)

proc strokeCircle*(
  image: Image,
  center: Vec2,
  radius: float32,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a circle.
  var path: Path
  path.ellipse(center, radius, radius)
  image.strokePath(path, color, transform, strokeWidth)

proc strokeCircle*(
  mask: Mask,
  center: Vec2,
  radius: float32,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a circle.
  var path: Path
  path.ellipse(center, radius, radius)
  mask.fillPath(path, transform, strokeWidth)

proc fillPolygon*(
  image: Image,
  pos: Vec2,
  size: float32,
  sides: int,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a polygon.
  var path: Path
  path.polygon(pos, size, sides)
  image.fillPath(path, color, transform)

proc fillPolygon*(
  mask: Mask,
  pos: Vec2,
  size: float32,
  sides: int,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills a polygon.
  var path: Path
  path.polygon(pos, size, sides)
  mask.fillPath(path, transform)

proc strokePolygon*(
  image: Image,
  pos: Vec2,
  size: float32,
  sides: int,
  color: SomeColor,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a polygon.
  var path: Path
  path.polygon(pos, size, sides)
  image.strokePath(path, color, transform, strokeWidth)

proc strokePolygon*(
  mask: Mask,
  pos: Vec2,
  size: float32,
  sides: int,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0
) =
  ## Strokes a polygon.
  var path: Path
  path.polygon(pos, size, sides)
  mask.strokePath(path, transform, strokeWidth)

proc fillText*(
  target: Image | Mask,
  arrangement: Arrangement,
  transform: Vec2 | Mat3 = vec2(0, 0)
) =
  ## Fills the text arrangement.
  for spanIndex, (start, stop) in arrangement.spans:
    let font = arrangement.fonts[spanIndex]
    for runeIndex in start .. stop:
      var path = font.typeface.getGlyphPath(arrangement.runes[runeIndex])
      path.transform(
        translate(arrangement.positions[runeIndex]) *
        scale(vec2(font.scale))
      )
      when type(target) is Image:
        target.fillPath(path, font.paint, transform)
      else: # target is Mask
        target.fillPath(path, transform)

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
  strokeWidth = 1.0
) =
  ## Strokes the text arrangement.
  for spanIndex, (start, stop) in arrangement.spans:
    let font = arrangement.fonts[spanIndex]
    for runeIndex in start .. stop:
      var path = font.typeface.getGlyphPath(arrangement.runes[runeIndex])
      path.transform(
        translate(arrangement.positions[runeIndex]) *
        scale(vec2(font.scale))
      )
      when type(target) is Image:
        target.strokePath(path, font.paint, transform, strokeWidth)
      else: # target is Mask
        target.strokePath(path, transform, strokeWidth)

proc strokeText*(
  target: Image | Mask,
  font: Font,
  text: string,
  transform: Vec2 | Mat3 = vec2(0, 0),
  strokeWidth = 1.0,
  bounds = vec2(0, 0),
  hAlign = haLeft,
  vAlign = vaTop
) {.inline.} =
  ## Typesets and strokes the text. Optional parameters:
  ## transform: translation or matrix to apply
  ## bounds: width determines wrapping and hAlign, height for vAlign
  ## hAlign: horizontal alignment of the text
  ## vAlign: vertical alignment of the text
  strokeText(
    target,
    font.typeset(text, bounds, hAlign, vAlign),
    transform,
    strokeWidth
  )
