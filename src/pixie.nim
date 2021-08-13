import bumpy, chroma, flatty/binny, os, pixie/blends, pixie/common,
    pixie/contexts, pixie/fileformats/bmp, pixie/fileformats/gif,
    pixie/fileformats/jpg, pixie/fileformats/png, pixie/fileformats/svg,
    pixie/fonts, pixie/images, pixie/masks, pixie/paints, pixie/paths, strutils, vmath

export blends, bumpy, chroma, common, contexts, fonts, images, masks, paints,
    paths, vmath

type
  FileFormat* = enum
    ffPng, ffBmp, ffJpg, ffGif

converter autoStraightAlpha*(c: ColorRGBX): ColorRGBA {.inline.} =
  ## Convert a paremultiplied alpha RGBA to a straight alpha RGBA.
  c.rgba()

converter autoPremultipliedAlpha*(c: ColorRGBA): ColorRGBX {.inline.} =
  ## Convert a straight alpha RGBA to a premultiplied alpha RGBA.
  c.rgbx()

proc decodeImage*(data: string | seq[uint8]): Image =
  ## Loads an image from memory.
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

proc decodeMask*(data: string | seq[uint8]): Mask =
  ## Loads a mask from memory.
  if data.len > 8 and data.readUint64(0) == cast[uint64](pngSignature):
    newMask(decodePng(data))
  else:
    raise newException(PixieError, "Unsupported mask file format")

proc readImage*(filePath: string): Image =
  ## Loads an image from a file.
  decodeImage(readFile(filePath))

proc readMask*(filePath: string): Mask =
  ## Loads a mask from a file.
  decodeMask(readFile(filePath))

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
    raise newException(PixieError, "Unsupported file format")

proc encodeMask*(mask: Mask, fileFormat: FileFormat): string =
  ## Encodes a mask into memory.
  case fileFormat:
  of ffPng:
    mask.encodePng()
  else:
    raise newException(PixieError, "Unsupported file format")

proc writeFile*(image: Image, filePath: string) =
  ## Writes an image to a file.
  let fileFormat = case splitFile(filePath).ext.toLowerAscii():
    of ".png": ffPng
    of ".bmp": ffBmp
    of ".jpg", ".jpeg": ffJpg
    else:
      raise newException(PixieError, "Unsupported file extension")
  writeFile(filePath, image.encodeImage(fileFormat))

proc writeFile*(mask: Mask, filePath: string) =
  ## Writes a mask to a file.
  let fileFormat = case splitFile(filePath).ext.toLowerAscii():
    of ".png": ffPng
    of ".bmp": ffBmp
    of ".jpg", ".jpeg": ffJpg
    else:
      raise newException(PixieError, "Unsupported file extension")
  writeFile(filePath, mask.encodeMask(fileFormat))
