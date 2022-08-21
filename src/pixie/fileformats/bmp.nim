import bitops, chroma, flatty/binny, pixie/common, pixie/images

# See: https://en.wikipedia.org/wiki/BMP_file_format
# See: https://bmptestsuite.sourceforge.io/
# https://docs.microsoft.com/en-us/windows/win32/gdi/bitmap-header-types
# https://stackoverflow.com/questions/61788908/windows-clipboard-getclipboarddata-for-cf-dibv5-causes-the-image-on-the-clip
# https://stackoverflow.com/questions/44177115/copying-from-and-to-clipboard-loses-image-transparency/46424800#46424800

const
  bmpSignature* = "BM"
  LCS_sRGB = 0x73524742

template failInvalid() =
  raise newException(PixieError, "Invalid BMP buffer, unable to load")

proc colorMaskShift(color, mask: uint32): uint8 {.inline.} =
  ((color and mask) shr (mask.firstSetBit() - 1)).uint8

proc decodeDib*(
  data: pointer, len: int, lpBitmapInfo = false
): Image {.raises: [PixieError].} =
  ## Decodes DIB data into an image.
  if len < 40:
    failInvalid()

  let data = cast[ptr UncheckedArray[uint8]](data)

  # BITMAPINFOHEADER
  var
    headerSize = data.readInt32(0).int
    width = data.readInt32(4).int
    height = data.readInt32(8).int
    planes = data.readUint16(12).int
    bits = data.readUint16(14).int
    compression = data.readInt32(16).int
    colorPaletteSize = data.readInt32(32).int

  if headerSize notin [40, 108, 124]:
    failInvalid()

  if planes != 1:
    failInvalid()

  if bits notin [1, 4, 8, 24, 32]:
    raise newException(PixieError, "Unsupported BMP bit count")

  if compression notin [0, 3]:
    raise newException(PixieError, "Unsupported BMP compression format")

  var
    redMask = 0x00FF0000.uint32
    greenMask = 0x0000FF00.uint32
    blueMask = 0x000000FF.uint32
    alphaMask = 0xFF000000.uint32
    flipVertical: bool
    useAlpha: bool

  if compression == 3:
    if len < 52:
      failInvalid()

    redMask = data.readUInt32(40)
    greenMask = data.readUInt32(44)
    blueMask = data.readUInt32(48)

    if redMask == 0 or blueMask == 0 or greenMask == 0:
      failInvalid()

  if headerSize > 40:
    if len < 56:
      failInvalid()

    alphaMask = data.readUInt32(52)

    useAlpha = alphaMask != 0

  if colorPaletteSize < 0 or colorPaletteSize > 256:
    failInvalid()

  if bits == 8 and colorPaletteSize == 0:
    colorPaletteSize = 256

  var colorPalette = newSeq[ColorRGBA](colorPaletteSize)
  if colorPaletteSize > 0:
    if len < headerSize + colorPaletteSize * 4:
      failInvalid()

    var offset = headerSize
    for i in 0 ..< colorPaletteSize:
      var rgba: ColorRGBA
      if offset + 3 > len - 2:
        failInvalid()
      rgba.r = data[offset + 2]
      rgba.g = data[offset + 1]
      rgba.b = data[offset + 0]
      rgba.a = 255
      offset += 4
      colorPalette[i] = rgba

  if height < 0:
    height = -height
    flipVertical = true

  result = newImage(width, height)

  var startOffset = headerSize + colorPaletteSize * 4
  if compression == 3 and (headerSize == 40 or lpBitmapInfo):
    startOffset += 12

  var offset = startOffset

  if bits == 1:
    var
      haveBits = 0
      colorBits: uint8 = 0
    for y in 0 ..< result.height:
      haveBits = 0
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        var rgba: ColorRGBA
        if haveBits == 0:
          if offset >= len:
            failInvalid()
          colorBits = data[offset]
          haveBits = 8
          offset += 1
        if (colorBits and 0b1000_0000) == 0:
          rgba = colorPalette[0]
        else:
          rgba = colorPalette[1]
        colorBits = colorBits shl 1
        dec haveBits
        result.unsafe[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 4:
    var
      haveBits = 0
      colorBits: uint8 = 0
    for y in 0 ..< result.height:
      haveBits = 0
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        var rgba: ColorRGBA
        if haveBits == 0:
          if offset >= len:
            failInvalid()
          colorBits = data[offset]
          haveBits = 8
          offset += 1
        let index = (colorBits and 0b1111_0000) shr 4
        if index.int >= colorPaletteSize:
          failInvalid()
        rgba = colorPalette[index]
        colorBits = colorBits shl 4
        haveBits -= 4
        result.unsafe[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 8:
    for y in 0 ..< result.height:
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        if offset >= len:
          failInvalid()
        var rgba: ColorRGBA
        let index = data[offset]
        offset += 1
        if index.int >= colorPaletteSize:
          failInvalid()
        rgba = colorPalette[index]
        result.unsafe[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 24:
    for y in 0 ..< result.height:
      let padding = (offset - startOffset) mod 4
      if padding > 0:
        offset += 4 - padding
      for x in 0 ..< result.width:
        if offset + 2 >= len:
          failInvalid()
        var rgba: ColorRGBA
        rgba.r = data[offset + 2]
        rgba.g = data[offset + 1]
        rgba.b = data[offset + 0]
        rgba.a = 255
        offset += 3
        result.unsafe[x, result.height - y - 1] = rgba.rgbx()

  elif bits == 32:
    for y in 0 ..< result.height:
      for x in 0 ..< result.width:
        if offset + 3 >= len:
          failInvalid()
        let color = data.readUint32(offset)
        if useAlpha:
          var rgbx: ColorRGBX
          rgbx.r = color.colorMaskShift(redMask)
          rgbx.g = color.colorMaskShift(greenMask)
          rgbx.b = color.colorMaskShift(blueMask)
          rgbx.a = color.colorMaskShift(alphaMask)
          result.unsafe[x, result.height - y - 1] = rgbx
        else:
          var rgba: ColorRGBA
          rgba.r = color.colorMaskShift(redMask)
          rgba.g = color.colorMaskShift(greenMask)
          rgba.b = color.colorMaskShift(blueMask)
          rgba.a = 255
          result.unsafe[x, result.height - y - 1] = rgba.rgbx()
        offset += 4

  if flipVertical:
    result.flipVertical()

proc decodeBmp*(data: string): Image {.raises: [PixieError].} =
  ## Decodes bitmap data into an image.
  if data.len < 14:
    failInvalid()

  # BMP Header
  if data[0 .. 1] != "BM":
    failInvalid()

  decodeDib(data[14].unsafeAddr, data.len - 14)

proc decodeBmpDimensions*(
  data: string
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes the BMP dimensions.
  if data.len < 26:
    failInvalid()

  # BMP Header
  if data[0 .. 1] != "BM":
    failInvalid()

  result.width = data.readInt32(18).int
  result.height = abs(data.readInt32(22)).int

proc encodeDib*(image: Image): string {.raises: [].} =
  ## Encodes an image into a DIB.

  # BITMAPINFO containing BITMAPV5HEADER
  result.addUint32(124) # Size of this header
  result.addInt32(image.width.int32) # Signed integer
  result.addInt32(image.height.int32) # Signed integer
  result.addUint16(1) # Must be 1 (color planes)
  result.addUint16(32) # Bits per pixels, only support RGBA
  result.addUint32(3) # BI_BITFIELDS, no pixel array compression used
  result.addUint32(32) # Size of the raw bitmap data (including padding)
  result.addUint32(2835) # Print resolution of the image
  result.addUint32(2835) # Print resolution of the image
  result.addUint32(0) # Number of colors in the palette
  result.addUint32(0) # 0 means all colors are important
  result.addUint32(uint32(0x000000FF)) # Red channel
  result.addUint32(uint32(0x0000FF00)) # Green channel
  result.addUint32(uint32(0x00FF0000)) # Blue channel
  result.addUint32(uint32(0xFF000000)) # Alpha channel
  result.addUint32(LCS_sRGB) # Color space
  result.setLen(result.len + 64) # Unused
  result.addUint32(0) # BITMAPINFO bmiColors 0
  result.addUint32(0) # BITMAPINFO bmiColors 1
  result.addUint32(0) # BITMAPINFO bmiColors 2

  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let rgba = image[x, image.height - y - 1].rgba()
      result.addUint32(cast[uint32](rgba))

proc encodeBmp*(image: Image): string {.raises: [].} =
  ## Encodes an image into the BMP file format.

  # BMP Header
  result.add("BM") # The header field used to identify the BMP
  result.addUint32(0) # The size of the BMP file in bytes
  result.addUint16(0) # Reserved
  result.addUint16(0) # Reserved
  result.addUint32(14 + 12 + 124) # The offset to the pixel array

  # DIB
  result.add(encodeDib(image))

  result.writeUint32(2, result.len.uint32)
