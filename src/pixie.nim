import bumpy, chroma, flatty/binny, os, pixie/blends, pixie/common,
    pixie/fileformats/bmp, pixie/fileformats/jpg, pixie/fileformats/png,
    pixie/fileformats/svg, pixie/gradients, pixie/images, pixie/masks,
    pixie/paths, vmath

export blends, bumpy, chroma, common, gradients, images, masks, paths, vmath

type
  FileFormat* = enum
    ffPng, ffBmp, ffJpg

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

proc writeFile*(image: Image, filePath: string, fileFormat: FileFormat) =
  ## Writes an image to a file.
  writeFile(filePath, image.encodeImage(fileFormat))

proc writeFile*(image: Image, filePath: string) =
  ## Writes an image to a file.
  let fileFormat = case splitFile(filePath).ext:
    of ".png": ffPng
    of ".bmp": ffBmp
    of ".jpg", ".jpeg": ffJpg
    else:
      raise newException(PixieError, "Unsupported image file extension")
  image.writeFile(filePath, fileformat)

proc fillRect*(image: Image, rect: Rect, color: ColorRGBA) =
  var path: Path
  path.rect(rect)
  image.fillPath(path, color)

proc fillRect*(mask: Mask, rect: Rect) =
  var path: Path
  path.rect(rect)
  mask.fillPath(path)

proc strokeRect*(
  image: Image, rect: Rect, color: ColorRGBA, strokeWidth = 1.0
) =
  var path: Path
  path.rect(rect)
  image.strokePath(path, color, strokeWidth)

proc strokeRect*(mask: Mask, rect: Rect, strokeWidth = 1.0) =
  var path: Path
  path.rect(rect)
  mask.strokePath(path, strokeWidth)

proc fillRoundedRect*(
  image: Image,
  rect: Rect,
  nw, ne, se, sw: float32,
  color: ColorRGBA
) =
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  image.fillPath(path, color)

proc fillRoundedRect*(
  image: Image,
  rect: Rect,
  radius: float32,
  color: ColorRGBA
) =
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  image.fillPath(path, color)

proc fillRoundedRect*(mask: Mask, rect: Rect, nw, ne, se, sw: float32) =
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  mask.fillPath(path)

proc fillRoundedRect*(mask: Mask, rect: Rect, radius: float32) =
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  mask.fillPath(path)

proc strokeRoundedRect*(
  image: Image,
  rect: Rect,
  nw, ne, se, sw: float32,
  color: ColorRGBA,
  strokeWidth = 1.0
) =
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  image.strokePath(path, color, strokeWidth)

proc strokeRoundedRect*(
  image: Image,
  rect: Rect,
  radius: float32,
  color: ColorRGBA,
  strokeWidth = 1.0
) =
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  image.strokePath(path, color, strokeWidth)

proc strokeRoundedRect*(
  mask: Mask, rect: Rect, nw, ne, se, sw: float32, strokeWidth = 1.0
) =
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  mask.strokePath(path, strokeWidth)

proc strokeRoundedRect*(
  mask: Mask, rect: Rect, radius: float32, strokeWidth = 1.0
) =
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  mask.strokePath(path, strokeWidth)

proc strokeSegment*(
  image: Image,
  segment: Segment,
  color: ColorRGBA,
  strokeWidth = 1.0
) =
  var path: Path
  path.moveTo(segment.at)
  path.lineTo(segment.to)
  image.strokePath(path, color, strokeWidth)

proc strokeSegment*(mask: Mask, segment: Segment, strokeWidth: float32) =
  var path: Path
  path.moveTo(segment.at)
  path.lineTo(segment.to)
  mask.strokePath(path, strokeWidth)

proc fillEllipse*(
  image: Image,
  center: Vec2,
  rx, ry: float32,
  color: ColorRGBA,
  blendMode = bmNormal
) =
  var path: Path
  path.ellipse(center, rx, ry)
  image.fillPath(path, color, wrNonZero, blendMode)

proc fillEllipse*(
  mask: Mask,
  center: Vec2,
  rx, ry: float32
) =
  var path: Path
  path.ellipse(center, rx, ry)
  mask.fillPath(path)

proc strokeEllipse*(
  image: Image,
  center: Vec2,
  rx, ry: float32,
  color: ColorRGBA,
  strokeWidth = 1.0
) =
  var path: Path
  path.ellipse(center, rx, ry)
  image.strokePath(path, color, strokeWidth)

proc strokeEllipse*(
  mask: Mask,
  center: Vec2,
  rx, ry: float32,
  strokeWidth = 1.0
) =
  var path: Path
  path.ellipse(center, rx, ry)
  mask.strokePath(path, strokeWidth)

proc fillCircle*(
  image: Image,
  center: Vec2,
  radius: float32,
  color: ColorRGBA
) =
  var path: Path
  path.ellipse(center, radius, radius)
  image.fillPath(path, color)

proc fillCircle*(
  mask: Mask,
  center: Vec2,
  radius: float32
) =
  var path: Path
  path.ellipse(center, radius, radius)
  mask.fillPath(path)

proc strokeCircle*(
  image: Image,
  center: Vec2,
  radius: float32,
  color: ColorRGBA,
  strokeWidth = 1.0
) =
  var path: Path
  path.ellipse(center, radius, radius)
  image.fillPath(path, color)

proc strokeCircle*(
  mask: Mask,
  center: Vec2,
  radius: float32,
  strokeWidth = 1.0
) =
  var path: Path
  path.ellipse(center, radius, radius)
  mask.fillPath(path)

proc fillPolygon*(
  image: Image,
  pos: Vec2,
  size: float32,
  sides: int,
  color: ColorRGBA
) =
  var path: Path
  path.polygon(pos, size, sides)
  image.fillPath(path, color)

proc fillPolygon*(mask: Mask, pos: Vec2, size: float32, sides: int) =
  var path: Path
  path.polygon(pos, size, sides)
  mask.fillPath(path)

proc strokePolygon*(
  image: Image,
  pos: Vec2,
  size: float32,
  sides: int,
  color: ColorRGBA,
  strokeWidth = 1.0
) =
  var path: Path
  path.polygon(pos, size, sides)
  image.strokePath(path, color, strokeWidth)

proc strokePolygon*(
  mask: Mask,
  pos: Vec2,
  size: float32,
  sides: int,
  strokeWidth = 1.0
) =
  var path: Path
  path.polygon(pos, size, sides)
  mask.strokePath(path, strokeWidth)
