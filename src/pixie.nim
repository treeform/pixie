import bumpy, chroma, flatty/binny, os, pixie/common, pixie/contexts,
    pixie/fileformats/bmp, pixie/fileformats/gif, pixie/fileformats/jpeg,
    pixie/fileformats/png, pixie/fileformats/ppm, pixie/fileformats/qoi,
    pixie/fileformats/svg, pixie/fonts, pixie/images, pixie/internal,
    pixie/paints, pixie/paths, strutils, vmath

export bumpy, chroma, common, contexts, fonts, images, paints, paths, vmath

type
  FileFormat* = enum
    PngFormat, BmpFormat, JpegFormat, GifFormat, QoiFormat, PpmFormat

converter autoStraightAlpha*(c: ColorRGBX): ColorRGBA {.inline, raises: [].} =
  ## Convert a premultiplied alpha RGBA to a straight alpha RGBA.
  c.rgba()

converter autoPremultipliedAlpha*(c: ColorRGBA): ColorRGBX {.inline, raises: [].} =
  ## Convert a straight alpha RGBA to a premultiplied alpha RGBA.
  c.rgbx()

proc decodeImageDimensions*(
  data: string
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes an image's dimensions from memory.
  if data.len > 8 and data.readUint64(0) == cast[uint64](pngSignature):
    decodePngDimensions(data)
  elif data.len > 2 and data.readUint16(0) == cast[uint16](jpegStartOfImage):
    decodeJpegDimensions(data)
  elif data.len > 2 and data.readStr(0, 2) == bmpSignature:
    decodeBmpDimensions(data)
  elif data.len > 6 and data.readStr(0, 6) in gifSignatures:
    decodeGifDimensions(data)
  elif data.len > (14+8) and data.readStr(0, 4) == qoiSignature:
    decodeQoiDimensions(data)
  elif data.len > 9 and data.readStr(0, 2) in ppmSignatures:
    decodePpmDimensions(data)
  else:
    raise newException(PixieError, "Unsupported image file format")

proc decodeImage*(data: string): Image {.raises: [PixieError].} =
  ## Loads an image from memory.
  if data.len > 8 and data.readUint64(0) == cast[uint64](pngSignature):
    decodePng(data).convertToImage()
  elif data.len > 2 and data.readUint16(0) == cast[uint16](jpegStartOfImage):
    decodeJpeg(data)
  elif data.len > 2 and data.readStr(0, 2) == bmpSignature:
    decodeBmp(data)
  elif data.len > 5 and
    (data.readStr(0, 5) == xmlSignature or data.readStr(0, 4) == svgSignature):
    newImage(parseSvg(data))
  elif data.len > 6 and data.readStr(0, 6) in gifSignatures:
    newImage(decodeGif(data))
  elif data.len > (14+8) and data.readStr(0, 4) == qoiSignature:
    decodeQoi(data).convertToImage()
  elif data.len > 9 and data.readStr(0, 2) in ppmSignatures:
    decodePpm(data)
  else:
    raise newException(PixieError, "Unsupported image file format")

proc readImageDimensions*(
  filePath: string
): ImageDimensions {.inline, raises: [PixieError].} =
  ## Decodes an image's dimensions from a file.
  try:
    decodeImageDimensions(readFile(filePath))
  except IOError as e:
    raise newException(PixieError, e.msg, e)

proc readImage*(filePath: string): Image {.inline, raises: [PixieError].} =
  ## Loads an image from a file.
  try:
    decodeImage(readFile(filePath))
  except IOError as e:
    raise newException(PixieError, e.msg, e)

proc encodeImage*(image: Image, fileFormat: FileFormat): string {.raises: [PixieError].} =
  ## Encodes an image into memory.
  case fileFormat:
  of PngFormat:
    image.encodePng()
  of JpegFormat:
    raise newException(PixieError, "Unsupported file format")
  of BmpFormat:
    image.encodeBmp()
  of QoiFormat:
    image.encodeQoi()
  of GifFormat:
    raise newException(PixieError, "Unsupported file format")
  of PpmFormat:
    image.encodePpm()

proc writeFile*(image: Image, filePath: string) {.raises: [PixieError].} =
  ## Writes an image to a file.
  let fileFormat = case splitFile(filePath).ext.toLowerAscii():
    of ".png": PngFormat
    of ".bmp": BmpFormat
    of ".jpg", ".jpeg": JpegFormat
    of ".qoi": QoiFormat
    of ".ppm": PpmFormat
    else:
      raise newException(PixieError, "Unsupported file extension")

  try:
    writeFile(filePath, image.encodeImage(fileFormat))
  except IOError as e:
    raise newException(PixieError, e.msg, e)

proc fill*(image: Image, paint: Paint) {.raises: [PixieError].} =
  ## Fills the image with the paint.
  case paint.kind:
  of SolidPaint:
    fillUnsafe(image.data, paint.color, 0, image.data.len)
  of ImagePaint, TiledImagePaint:
    fillUnsafe(image.data, rgbx(0, 0, 0, 0), 0, image.data.len)
    let path = newPath()
    path.rect(0, 0, image.width.float32, image.height.float32)
    image.fillPath(path, paint)
  of LinearGradientPaint, RadialGradientPaint, AngularGradientPaint:
    image.fillGradient(paint)
