## Public interface to you library.

import pixie/images, pixie/masks, pixie/paths, pixie/common, pixie/blends,
  pixie/fileformats/bmp, pixie/fileformats/png, flatty/binny

export images, masks, paths, PixieError, blends

type
  FileFormat* = enum
    ffPng, ffBmp

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

proc decodeImage*(data: string | seq[uint8]): Image =
  ## Loads an image from a memory.
  if data.len > 8 and cast[array[8, uint8]](data.readUint64(0)) == pngSignature:
    return decodePng(data)

  if data.len > 2 and data.readStr(0, 2) == "BM":
    return decodeBmp(data)

  raise newException(PixieError, "Unsupported image file format")

proc readImage*(filePath: string): Image =
  ## Loads an image from a file.
  decodeImage(readFile(filePath))

proc encodeImage*(image: Image, fileFormat: FileFormat): string =
  ## Encodes an image into a memory.
  case fileFormat:
  of ffPng:
    image.encodePng()
  of ffBmp:
    image.encodeBmp()

proc writeFile*(image: Image, filePath: string, fileFormat: FileFormat) =
  ## Writes an image to a file.
  writeFile(filePath, image.encodeImage(fileFormat))
