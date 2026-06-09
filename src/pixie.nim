import
  std/[os, strutils],
  bumpy, chroma, flatty/binny, vmath,
  pixie/[common, contexts, fonts, imagebase64, images, internal, paints, paths],
  pixie/fileformats/[bmp, gif, jpeg, png, ppm, qoi, svg, webp]

export bumpy, chroma, common, contexts, fonts, imagebase64, images, paints,
    paths, vmath

type
  FileFormat* = enum
    PngFormat, BmpFormat, JpegFormat, GifFormat, QoiFormat, PpmFormat,
    WebpFormat

converter autoStraightAlpha*(c: ColorRGBX): ColorRGBA {.inline, raises: [].} =
  ## Convert a premultiplied alpha RGBA to a straight alpha RGBA.
  c.rgba()

converter autoPremultipliedAlpha*(c: ColorRGBA): ColorRGBX {.inline, raises: [].} =
  ## Convert a straight alpha RGBA to a premultiplied alpha RGBA.
  c.rgbx()

proc decodeImageDimensions*(
  data: pointer, len: int
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes an image's dimensions from memory.
  if len > 8 and equalMem(data, pngSignature[0].unsafeAddr, 8):
    decodePngDimensions(data, len)
  elif len > 2 and equalMem(data, jpegStartOfImage[0].unsafeAddr, 2):
    decodeJpegDimensions(data, len)
  elif len > 2 and equalMem(data, bmpSignature.cstring, 2):
    decodeBmpDimensions(data, len)
  elif len > 6 and (
    equalMem(data, gifSignatures[0].cstring, 6) or
    equalMem(data, gifSignatures[1].cstring, 6)
  ):
    decodeGifDimensions(data, len)
  elif len > (14 + 8) and equalMem(data, qoiSignature.cstring, 4):
    decodeQoiDimensions(data, len)
  elif len > 9 and (
    equalMem(data, ppmSignatures[0].cstring, 2) or
    equalMem(data, ppmSignatures[1].cstring, 2)
  ):
    decodePpmDimensions(data, len)
  elif len > 12 and
      equalMem(data, WebpRiffSignature.cstring, 4) and
      equalMem(cast[pointer](cast[uint](data) + 8), WebpSignature.cstring, 4):
    decodeWebpDimensions(data, len)
  else:
    raise newException(PixieError, "Unsupported image file format")

proc decodeImageDimensions*(
  data: string
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes an image's dimensions from memory.
  decodeImageDimensions(data.cstring, data.len)

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
  elif data.len > 12 and data.readStr(0, 4) == WebpRiffSignature and
      data.readStr(8, 4) == WebpSignature:
    decodeWebp(data)
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

proc encodeImage*(
  image: Image, fileFormat: FileFormat
): string {.raises: [PixieError].} =
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
  of WebpFormat:
    raise newException(PixieError, "Unsupported file format")

proc writeFile*(image: Image, filePath: string) {.raises: [PixieError].} =
  ## Writes an image to a file.
  let fileFormat = case splitFile(filePath).ext.toLowerAscii():
    of ".png": PngFormat
    of ".bmp": BmpFormat
    of ".jpg", ".jpeg": JpegFormat
    of ".qoi": QoiFormat
    of ".ppm": PpmFormat
    of ".webp": WebpFormat
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
