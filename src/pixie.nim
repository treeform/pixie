import pixie/images, pixie/masks, pixie/paths, pixie/common, pixie/blends

# When reading and writing is disabled, do not import any formats.
when (not defined(pixieNoReadImage)) or (not defined(pixieNoWriteImage)):
  import flatty/binny, os, pixie/fileformats/[bmp, png, jpg, svg]

export images, masks, paths, common, blends

type
  FileFormat* = enum
    ffPng, ffBmp, ffJpg

proc toMask*(image: Image): Mask =
  ## Converts an Image to a Mask.
  result = newMask(image.width, image.height)
  for i in 0 ..< image.data.len:
    result.data[i] = image.data[i].a

proc toImage*(mask: Mask): Image =
  ## Converts a Mask to Image.
  result = newImage(mask.width, mask.height)
  for i in 0 ..< mask.data.len:
    result.data[i].a = mask.data[i]

when not defined(pixieNoReadImage):

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

when not defined(pixieNoWriteImage):

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
      of ".jpg": ffJpg
      of ".jpeg": ffJpg
      else:
        raise newException(PixieError, "Unsupported image file extension")
    image.writeFile(filePath, fileformat)

