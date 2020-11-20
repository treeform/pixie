import ../images, flatty/binny, flatty/hexPrint, chroma, sequtils, print

# See: https://en.wikipedia.org/wiki/BMP_file_format

proc decodeBmp*(data: string): Image =
  ## Decodes bitmap data into an Image.

  # BMP Header
  doAssert data[0..1] == "BM"
  let
    width = data.readInt32(0x12).int
    height = data.readInt32(0x16).int
    bits = data.readUint16(0x1C)
    compression = data.readUint32(0x1E)
  var
    offset = data.readUInt32(0xA).int

  doAssert bits in {32, 24}
  doAssert compression in {0, 3}

  result = newImage(width, height)

  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      var rgba: ColorRGBA
      if bits == 32:
        rgba.r = data.readUint8(offset + 0)
        rgba.g = data.readUint8(offset + 1)
        rgba.b = data.readUint8(offset + 2)
        rgba.a = data.readUint8(offset + 3)
        offset += 4
      elif bits == 24:
        rgba.r = data.readUint8(offset + 2)
        rgba.g = data.readUint8(offset + 1)
        rgba.b = data.readUint8(offset + 0)
        rgba.a = 255
        offset += 3
      result[x, result.height - y - 1] = rgba

proc encodeBmp*(image: Image): string =
  ## Encodes an image into bitmap data.

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
      let rgba = image[x, image.height - y - 1]
      result.addUint8(rgba.r)
      result.addUint8(rgba.g)
      result.addUint8(rgba.b)
      result.addUint8(rgba.a)

  result.writeUInt32(2, result.len.uint32)
