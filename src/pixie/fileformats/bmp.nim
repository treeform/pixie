import bitops, chroma, flatty/binny, pixie/common, pixie/images

# See: https://en.wikipedia.org/wiki/BMP_file_format

const bmpSignature* = "BM"

proc colorMaskShift(color: uint32, mask: uint32): uint8 =
  ((color and mask) shr (mask.firstSetBit() - 1)).uint8

proc decodeBmp*(data: string): Image {.raises: [PixieError].} =
  ## Decodes bitmap data into an Image.

  # BMP Header
  if data[0 .. 1] != "BM":
    raise newException(PixieError, "Invalid BMP data")

  let
    width = data.readInt32(18).int
    height = data.readInt32(22).int
    bits = data.readUint16(28).int
    compression = data.readUint32(30).int
    dibHeader = data.readInt32(14).int

  var
    offset = data.readUInt32(10).int
    # Default channels if header does not contain them:
    redChan =   0x00FF0000.uint32
    greenChan = 0x0000FF00.uint32
    blueChan =  0x000000FF.uint32
    alphaChan = 0xFF000000.uint32

  if dibHeader == 108:
    redChan = data.readUInt32(54)
    greenChan = data.readUInt32(58)
    blueChan = data.readUInt32(62)
    alphaChan = data.readUInt32(66)

  if bits notin [32, 24]:
    raise newException(PixieError, "Unsupported BMP data format")

  if compression notin [0, 3]:
    raise newException(PixieError, "Unsupported BMP data format")

  let channels = if bits == 32: 4 else: 3
  if width * height * channels + offset > data.len:
    raise newException(PixieError, "Invalid BMP data size")

  result = newImage(width, height)

  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      var rgba: ColorRGBA
      if bits == 32:
        let color = data.readUint32(offset)
        rgba.r = color.colorMaskShift(redChan)
        rgba.g = color.colorMaskShift(greenChan)
        rgba.b = color.colorMaskShift(blueChan)
        rgba.a = color.colorMaskShift(alphaChan)
        offset += 4
      elif bits == 24:
        rgba.r = data.readUint8(offset + 2)
        rgba.g = data.readUint8(offset + 1)
        rgba.b = data.readUint8(offset + 0)
        rgba.a = 255
        offset += 3
      result[x, result.height - y - 1] = rgba.rgbx()

proc decodeBmp*(data: seq[uint8]): Image {.inline, raises: [PixieError].} =
  ## Decodes bitmap data into an Image.
  decodeBmp(cast[string](data))

proc encodeBmp*(image: Image): string {.raises: [].} =
  ## Encodes an image into the BMP file format.

  # BMP Header
  result.add("BM") # The header field used to identify the BMP
  result.addUint32(0) # The size of the BMP file in bytes.
  result.addUint16(0) # Reserved.
  result.addUint16(0) # Reserved.
  result.addUint32(122) # The offset to the pixel array.

  # DIB Header
  result.addUint32(108) # Size of this header
  result.addInt32(image.width.int32) # Signed integer.
  result.addInt32(image.height.int32) # Signed integer.
  result.addUint16(1) # Must be 1 (color planes).
  result.addUint16(32) # Bits per pixels, only support RGBA.
  result.addUint32(3) # BI_BITFIELDS, no pixel array compression used
  result.addUint32(32) # Size of the raw bitmap data (including padding)
  result.addUint32(2835) # Print resolution of the image
  result.addUint32(2835) # Print resolution of the image
  result.addUint32(0) # Number of colors in the palette
  result.addUint32(0) # 0 means all colors are important
  result.addUint32(uint32(0x000000FF)) # Red channel.
  result.addUint32(uint32(0x0000FF00)) # Green channel.
  result.addUint32(uint32(0x00FF0000)) # Blue channel.
  result.addUint32(uint32(0xFF000000)) # Alpha channel.
  result.add("Win ") # little-endian.
  for i in 0 ..< 48:
    result.addUint8(0) # Unused

  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let rgba = image[x, image.height - y - 1].rgba()
      result.addUint8(rgba.r)
      result.addUint8(rgba.g)
      result.addUint8(rgba.b)
      result.addUint8(rgba.a)

  result.writeUInt32(2, result.len.uint32)
