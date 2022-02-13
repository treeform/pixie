import bitops, chroma, flatty/binny, pixie/common, pixie/images

# See: https://en.wikipedia.org/wiki/BMP_file_format
# See: https://bmptestsuite.sourceforge.io/

const bmpSignature* = "BM"

template failInvalid() =
  raise newException(PixieError, "Invalid BMP buffer, unable to load")

proc colorMaskShift(color, mask: uint32): uint8 {.inline.} =
  ((color and mask) shr (mask.firstSetBit() - 1)).uint8

proc decodeBmp*(data: string): Image {.raises: [PixieError].} =
  ## Decodes bitmap data into an Image.

  if data.len < 48:
    failInvalid()

  # BMP Header
  if data[0 .. 1] != "BM":
    failInvalid()

  let
    bits = data.readUint16(28).int
    compression = data.readUint32(30).int
    dibHeader = data.readInt32(14).int
  var
    numColors = data.readInt32(46).int
    width = data.readInt32(18).int
    height = data.readInt32(22).int
    offset = data.readUInt32(10).int
    # Default channels if header does not contain them:
    redChannel = 0x00FF0000.uint32
    greenChannel = 0x0000FF00.uint32
    blueChannel = 0x000000FF.uint32
    alphaChannel = 0xFF000000.uint32
    useAlpha = false
    flipVertical = false

  if numColors < 0 or numColors > 256:
    failInvalid()
  if dibHeader notin [40, 108]:
    failInvalid()

  var
    colorTable = newSeq[ColorRGBA](numColors)

  if dibHeader == 108:
    if data.len < 14 + dibHeader:
      failInvalid()

    redChannel = data.readUInt32(54)
    greenChannel = data.readUInt32(58)
    blueChannel = data.readUInt32(62)
    alphaChannel = data.readUInt32(66)
    useAlpha = true

  if bits == 8 and numColors == 0:
    numColors = 256
    colorTable = newSeq[ColorRGBA](numColors)

  if numColors > 0:
    if data.len < 14 + dibHeader + numColors * 4:
      failInvalid()

    var colorOffset = dibHeader + 14
    for i in 0 ..< numColors:
      var rgba: ColorRGBA
      if colorOffset + 3 > data.len - 2:
        failInvalid()
      rgba.r = data.readUint8(colorOffset + 2)
      rgba.g = data.readUint8(colorOffset + 1)
      rgba.b = data.readUint8(colorOffset + 0)
      rgba.a = 255
      colorOffset += 4
      colorTable[i] = rgba

  if redChannel == 0 or greenChannel == 0 or
    blueChannel == 0 or alphaChannel == 0:
    failInvalid()

  if bits notin [1, 4, 8, 32, 24]:
    raise newException(PixieError, "Unsupported BMP data format")

  if compression notin [0, 3]:
    raise newException(PixieError, "Unsupported BMP data format")

  if height < 0:
    height = -height
    flipVertical = true

  result = newImage(width, height)
  let startOffset = offset

  if bits == 1:
    var
      haveBits = 0
      colorBits: uint8 = 0
    for y in 0 ..< result.height:
      # pad the row
      haveBits = 0
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        var rgba: ColorRGBA
        if haveBits == 0:
          if offset >= data.len:
            failInvalid()
          colorBits = data.readUint8(offset)
          haveBits = 8
          offset += 1
        if (colorBits and 0b1000_0000) == 0:
          rgba = colorTable[0]
        else:
          rgba = colorTable[1]
        colorBits = colorBits shl 1
        dec haveBits
        result[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 4:
    var
      haveBits = 0
      colorBits: uint8 = 0
    for y in 0 ..< result.height:
      # pad the row
      haveBits = 0
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        var rgba: ColorRGBA
        if haveBits == 0:
          if offset >= data.len:
            failInvalid()
          colorBits = data.readUint8(offset)
          haveBits = 8
          offset += 1
        let index = (colorBits and 0b1111_0000) shr 4
        if index.int >= numColors:
          failInvalid()
        rgba = colorTable[index]
        colorBits = colorBits shl 4
        haveBits -= 4
        result[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 8:
    for y in 0 ..< result.height:
      # pad the row
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        if offset >= data.len:
          failInvalid()
        var rgba: ColorRGBA
        let index = data.readUint8(offset)
        offset += 1
        if index.int >= numColors:
          failInvalid()
        rgba = colorTable[index]
        result[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 24:
    for y in 0 ..< result.height:
      # pad the row
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        if offset + 2 >= data.len:
          failInvalid()
        var rgba: ColorRGBA
        rgba.r = data.readUint8(offset + 2)
        rgba.g = data.readUint8(offset + 1)
        rgba.b = data.readUint8(offset + 0)
        rgba.a = 255
        offset += 3
        result[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 32:
    for y in 0 ..< result.height:
      for x in 0 ..< result.width:
        if offset + 3 >= data.len:
          failInvalid()
        var rgba: ColorRGBA
        let color = data.readUint32(offset)
        rgba.r = color.colorMaskShift(redChannel)
        rgba.g = color.colorMaskShift(greenChannel)
        rgba.b = color.colorMaskShift(blueChannel)
        if useAlpha:
          rgba.a = color.colorMaskShift(alphaChannel)
        else:
          rgba.a = 255
        offset += 4
        result[x, result.height - y - 1] = rgba.rgbx()

  if flipVertical:
    result.flipVertical()

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
