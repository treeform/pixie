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
  elif data.len > 5 and data.readStr(0, 5) == svgSignature:
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

proc drawRect*(
  image: Image, rect: Rect, color: ColorRGBA, blendMode = bmNormal
) =
  var path: Path
  path.rect(rect)
  image.fillPath(path, color, wrNonZero, blendMode)

proc drawRect*(mask: Mask, rect: Rect) =
  var path: Path
  path.rect(rect)
  mask.fillPath(path)

proc drawRoundedRect*(
  image: Image,
  rect: Rect,
  nw, ne, se, sw: float32,
  color: ColorRGBA,
  blendMode = bmNormal
) =
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  image.fillPath(path, color, wrNonZero, blendMode)

proc drawRoundedRect*(
  image: Image,
  rect: Rect,
  radius: float32,
  color: ColorRGBA,
  blendMode = bmNormal
) =
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  image.fillPath(path, color, wrNonZero, blendMode)

proc drawRoundedRect*(mask: Mask, rect: Rect, nw, ne, se, sw: float32) =
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  mask.fillPath(path)

proc drawRoundedRect*(mask: Mask, rect: Rect, radius: float32) =
  var path: Path
  path.roundedRect(rect, radius, radius, radius, radius)
  mask.fillPath(path)

proc drawSegment*(
  image: Image,
  segment: Segment,
  color: ColorRGBA,
  strokeWidth = 1.0,
  blendMode = bmNormal
) =
  var path: Path
  path.moveTo(segment.at)
  path.lineTo(segment.to)
  image.strokePath(path, color, strokeWidth, wrNonZero, blendMode)

proc drawSegment*(mask: Mask, segment: Segment, strokeWidth: float32) =
  var path: Path
  path.moveTo(segment.at)
  path.lineTo(segment.to)
  mask.strokePath(path, strokeWidth)
