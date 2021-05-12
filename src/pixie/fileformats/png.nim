import chroma, flatty/binny, math, pixie/common, pixie/images, pixie/internal,
    pixie/masks, zippy, zippy/crc

# See http://www.libpng.org/pub/png/spec/1.2/PNG-Contents.html

const
  pngSignature* = [137.uint8, 80, 78, 71, 13, 10, 26, 10]

type
  ChunkCounts = object
    PLTE, IDAT, tRNS: uint8

  PngHeader = object
    width, height: int
    bitDepth, colorType, compressionMethod, filterMethod, interlaceMethod: uint8

template failInvalid() =
  raise newException(PixieError, "Invalid PNG buffer, unable to load")

# template failCRC() =
#   raise newException(PixieError, "CRC check failed")

when defined(release):
  {.push checks: off.}

proc decodeHeader(data: seq[uint8]): PngHeader =
  result.width = data.readUint32(0).swap().int
  result.height = data.readUint32(4).swap().int
  result.bitDepth = data[8]
  result.colorType = data[9]
  result.compressionMethod = data[10]
  result.filterMethod = data[11]
  result.interlaceMethod = data[12]

  if result.width == 0 or result.width > int32.high.int:
    raise newException(PixieError, "Invalid PNG width")

  if result.height == 0 or result.height > int32.high.int:
    raise newException(PixieError, "Invalid PNG height")

  template failInvalidCombo() =
    raise newException(
      PixieError, "Invalid PNG color type and bit depth combination"
    )

  case result.colorType:
  of 0:
    if result.bitDepth notin [1.uint8, 2, 4, 8, 16]:
      failInvalidCombo()
  of 2:
    if result.bitDepth notin [8.uint8, 16]:
      failInvalidCombo()
  of 3: # PLTE chunk is required, sample depth is always 8 bits
    if result.bitDepth notin [1.uint8, 2, 4, 8]:
      failInvalidCombo()
  of 4:
    if result.bitDepth notin [8.uint8, 16]:
      failInvalidCombo()
  of 6:
    if result.bitDepth notin [8.uint8, 16]:
      failInvalidCombo()
  else:
    failInvalidCombo()

  if result.compressionMethod != 0:
    raise newException(PixieError, "Invalid PNG compression method")

  if result.filterMethod != 0:
    raise newException(PixieError, "Invalid PNG filter method")

  if result.interlaceMethod notin [0.uint8, 1]:
    raise newException(PixieError, "Invalid PNG interlace method")

  # Not yet supported:

  if result.bitDepth == 16:
    raise newException(PixieError, "PNG 16 bit depth not yet supported")

  if result.interlaceMethod != 0:
    raise newException(PixieError, "Interlaced PNG not yet supported")

proc decodePalette(data: seq[uint8]): seq[ColorRGB] =
  if data.len == 0 or data.len mod 3 != 0:
    failInvalid()

  result.setLen(data.len div 3)

  for i in 0 ..< data.len div 3:
    result[i] = cast[ptr ColorRGB](data[i * 3].unsafeAddr)[]

proc unfilter(
  uncompressed: seq[uint8], height, rowBytes, bpp: int
): seq[uint8] =
  result.setLen(uncompressed.len - height)

  template uncompressedIdx(x, y: int): int =
    x + y * (rowBytes + 1)

  template unfiteredIdx(x, y: int): int =
    x + y * rowBytes

  # Unfilter the image data
  for y in 0 ..< height:
    let filterType = uncompressed[uncompressedIdx(0, y)]
    case filterType:
    of 0: # None
      copyMem(
        result[unfiteredIdx(0, y)].addr,
        uncompressed[uncompressedIdx(1, y)].unsafeAddr,
        rowBytes
      )
    of 1: # Sub
      for x in 0 ..< rowBytes:
        var value = uncompressed[uncompressedIdx(x + 1, y)]
        if x - bpp >= 0:
          value += result[unfiteredIdx(x - bpp, y)]
        result[unfiteredIdx(x, y)] = value
    of 2: # Up
      for x in 0 ..< rowBytes:
        var value = uncompressed[uncompressedIdx(x + 1, y)]
        if y - 1 >= 0:
          value += result[unfiteredIdx(x, y - 1)]
        result[unfiteredIdx(x, y)] = value
    of 3: # Average
      for x in 0 ..< rowBytes:
        var
          value = uncompressed[uncompressedIdx(x + 1, y)]
          left, up: int
        if x - bpp >= 0:
          left = result[unfiteredIdx(x - bpp, y)].int
        if y - 1 >= 0:
          up = result[unfiteredIdx(x, y - 1)].int
        value += ((left + up) div 2).uint8
        result[unfiteredIdx(x, y)] = value
    of 4: # Paeth
      for x in 0 ..< rowBytes:
        var
          value = uncompressed[uncompressedIdx(x + 1, y)]
          left, up, upLeft: int
        if x - bpp >= 0:
          left = result[unfiteredIdx(x - bpp, y)].int
        if y - 1 >= 0:
          up = result[unfiteredIdx(x, y - 1)].int
        if x - bpp >= 0 and y - 1 >= 0:
          upLeft = result[unfiteredIdx(x - bpp, y - 1)].int
        template paethPredictor(a, b, c: int): int =
          let
            p = a + b - c
            pa = abs(p - a)
            pb = abs(p - b)
            pc = abs(p - c)
          if pa <= pb and pa <= pc:
            a
          elif pb <= pc:
            b
          else:
            c
        value += paethPredictor(up, left, upLeft).uint8
        result[unfiteredIdx(x, y)] = value
    else:
      discard # Not possible, parseHeader validates

proc decodeImageData(
  header: PngHeader,
  palette: seq[ColorRGB],
  transparency, data: seq[uint8]
): seq[ColorRGBA] =
  result.setLen(header.width * header.height)

  let
    uncompressed = try: uncompress(data) except ZippyError: failInvalid()
    valuesPerPixel =
      case header.colorType:
      of 0: 1
      of 2: 3
      of 3: 1
      of 4: 2
      of 6: 4
      else: 0 # Not possible, parseHeader validates
    valuesPerByte = 8 div header.bitDepth.int
    rowBytes = ceil((header.width.int * valuesPerPixel) / valuesPerByte).int
    totalBytes = rowBytes * header.height.int

  # Uncompressed image data should be the total bytes of pixel data plus
  # a filter byte for each row.
  if uncompressed.len != totalBytes + header.height.int:
    failInvalid()

  let unfiltered = unfilter(
    uncompressed,
    header.height,
    rowBytes,
    max(valuesPerPixel div valuesPerByte, 1)
  )

  case header.colorType:
  of 0:
    let special = if transparency.len == 2: transparency[1].int else: -1
    var bytePos, bitPos: int
    for y in 0 ..< header.height:
      for x in 0 ..< header.width:
        var value = unfiltered[bytePos]
        case header.bitDepth:
        of 1:
          value = (value shr (7 - bitPos)) and 1
          value *= 255
          inc bitPos
        of 2:
          value = (value shr (6 - bitPos)) and 3
          value *= 85
          inc(bitPos, 2)
        of 4:
          value = (value shr (4 - bitPos)) and 15
          value *= 17
          inc(bitPos, 4)
        of 8:
          inc bytePos
        else:
          discard # Not possible, parseHeader validates

        if bitPos == 8:
          inc bytePos
          bitPos = 0

        let alpha = if value.int == special: 0 else: 255
        result[x + y * header.width] = ColorRGBA(
          r: value, g: value, b: value, a: alpha.uint8
        )

      # If we move to a new row, skip to the next full byte
      if bitPos > 0:
        inc bytePos
        bitPos = 0
  of 2:
    var special: ColorRGBA
    if transparency.len == 6: # Need to apply transparency check, slower.
      special.r = transparency[1]
      special.g = transparency[3]
      special.b = transparency[5]
      special.a = 255

      # While we can read an extra byte safely, do so. Much faster.
      for i in 0 ..< header.height * header.width - 1:
        var rgba = cast[ptr ColorRGBA](unfiltered[i * 3].unsafeAddr)[]
        rgba.a = 255
        if rgba == special:
          rgba.a = 0
        result[i] = rgba
    else:
      # While we can read an extra byte safely, do so. Much faster.
      for i in 0 ..< header.height * header.width - 1:
        var rgba = cast[ptr ColorRGBA](unfiltered[i * 3].unsafeAddr)[]
        rgba.a = 255
        result[i] = rgba

    let
      lastOffset = header.height * header.width - 1
      rgb = cast[ptr array[3, uint8]](unfiltered[lastOffset * 3].unsafeAddr)[]
    var rgba = ColorRGBA(r: rgb[0], g: rgb[1], b: rgb[2], a: 255)
    if rgba == special:
      rgba.a = 0
    result[header.height * header.width - 1] = cast[ColorRGBA](rgba)
  of 3:
    var bytePos, bitPos: int
    for y in 0 ..< header.height:
      for x in 0 ..< header.width:
        var value = unfiltered[bytePos]
        case header.bitDepth:
        of 1:
          value = (value shr (7 - bitPos)) and 1
          inc bitPos
        of 2:
          value = (value shr (6 - bitPos)) and 3
          inc(bitPos, 2)
        of 4:
          value = (value shr (4 - bitPos)) and 15
          inc(bitPos, 4)
        of 8:
          inc bytePos
        else:
          discard # Not possible, parseHeader validates

        if bitPos == 8:
          inc bytePos
          bitPos = 0
        if value.int >= palette.len:
          failInvalid()

        let
          rgb = palette[value]
          transparency =
            if transparency.len > value.int:
              transparency[value]
            else:
              255
        result[x + y * header.width] = ColorRGBA(
          r: rgb.r, g: rgb.g, b: rgb.b, a: transparency
        )

      # If we move to a new row, skip to the next full byte
      if bitPos > 0:
        inc bytePos
        bitPos = 0
  of 4:
    for i in 0 ..< header.height * header.width:
      let bytePos = i * 2
      result[i] = ColorRGBA(
        r: unfiltered[bytePos],
        g: unfiltered[bytePos],
        b: unfiltered[bytePos],
        a: unfiltered[bytePos + 1]
      )
  of 6:
    for i in 0 ..< header.height * header.width:
      result[i] = cast[ColorRGBA](unfiltered.readUint32(i * 4))
  else:
    discard # Not possible, parseHeader validates

proc decodePng*(data: seq[uint8]): Image =
  ## Decodes the PNG data into an Image.

  if data.len < (8 + (8 + 13 + 4) + 4): # Magic bytes + IHDR + IEND
    failInvalid()

  # PNG file signature
  let signature = cast[array[8, uint8]](data.readUint64(0))
  if signature != pngSignature:
    failInvalid()

  var
    pos = 8 # After signature
    counts = ChunkCounts()
    header: PngHeader
    palette: seq[ColorRGB]
    transparency, imageData: seq[uint8]
    prevChunkType: string

  # First chunk must be IHDR
  if data.readUint32(pos).swap() != 13 or
    data.readStr(pos + 4, 4) != "IHDR":
    failInvalid()
  inc(pos, 8)
  header = decodeHeader(data[pos ..< pos + 13])
  prevChunkType = "IHDR"
  inc(pos, 13)

  # if crc32(data[pos - 17 ..< pos]) != read32be(data, pos):
  #   failCRC()
  inc(pos, 4) # CRC

  while true:
    if pos + 8 > data.len:
      failInvalid()

    let
      chunkLen = data.readUint32(pos).swap().int
      chunkType = data.readStr(pos + 4, 4)
    inc(pos, 8)

    if chunkLen > high(int32).int:
      failInvalid()

    if pos + chunkLen + 4 > data.len:
      failInvalid()

    case chunkType:
    of "IHDR":
      failInvalid()
    of "PLTE":
      inc counts.PLTE
      if counts.PLTE > 1 or counts.IDAT > 0 or counts.tRNS > 0:
        failInvalid()
      palette = decodePalette(data[pos ..< pos + chunkLen])
    of "tRNS":
      inc counts.tRNS
      if counts.tRNS > 1 or counts.IDAT > 0:
        failInvalid()
      transparency = data[pos ..< pos + chunkLen]
      case header.colorType:
      of 0:
        if transparency.len != 2:
          failInvalid()
      of 2:
        if transparency.len != 6:
          failInvalid()
      of 3:
        if transparency.len > palette.len:
          failInvalid()
      else:
        failInvalid()
    of "IDAT":
      inc counts.IDAT
      if counts.IDAT > 1 and prevChunkType != "IDAT":
        failInvalid()
      if header.colorType == 3 and counts.PLTE == 0:
        failInvalid()
      let op = imageData.len
      imageData.setLen(imageData.len + chunkLen)
      copyMem(imageData[op].addr, data[pos].unsafeAddr, chunkLen)
    of "IEND":
      if chunkLen != 0:
        failInvalid()
    else:
      let bytes = cast[seq[uint8]](chunkType)
      if (bytes[0] and 0b00100000) == 0:
        raise newException(
          PixieError, "Unrecognized PNG critical chunk " & chunkType
        )

    inc(pos, chunkLen)

    # if crc32(data[pos - chunkLen - 4 ..< pos]) != read32be(data, pos):
    #   failCRC()
    inc(pos, 4) # CRC

    prevChunkType = chunkType

    if pos == data.len or prevChunkType == "IEND":
      break

  if prevChunkType != "IEND":
    failInvalid()

  var pixels = decodeImageData(header, palette, transparency, imageData)
  pixels.toPremultipliedAlpha()

  result = Image()
  result.width = header.width
  result.height = header.height
  result.data = cast[seq[ColorRGBX]](pixels)

proc decodePng*(data: string): Image {.inline.} =
  ## Decodes the PNG data into an Image.
  decodePng(cast[seq[uint8]](data))

proc encodePng*(
  width, height, channels: int, data: pointer, len: int
): seq[uint8] =
  ## Encodes the image data into the PNG file format.
  ## If data points to RGBA data, it is assumed to be straight alpha.

  if width <= 0 or width > int32.high.int:
    raise newException(PixieError, "Invalid PNG width")

  if height <= 0 or height > int32.high.int:
    raise newException(PixieError, "Invalid PNG height")

  if len != width * height * channels:
    raise newException(PixieError, "Invalid PNG data size")

  let colorType = case channels:
    of 1: 0.uint8
    of 2: 4
    of 3: 2
    of 4: 6
    else:
      raise newException(PixieError, "Invalid PNG number of channels")

  let data = cast[ptr UncheckedArray[uint8]](data)

  # Add the PNG file signature
  result.add(pngSignature)

  # Add IHDR
  result.addUint32(13.uint32.swap())
  result.addStr("IHDR")
  result.addUint32(width.uint32.swap())
  result.addUint32(height.uint32.swap())
  result.add(8.uint8)
  result.add([colorType, 0, 0, 0])
  result.addUint32(crc32(result[result.len - 17 ..< result.len]).swap())

  # Add IDAT
  # Add room for 1 byte before each row for the filter type.
  var filtered = newSeq[uint8](width * height * channels + height)
  for y in 0 ..< height:
    filtered[y * width * channels + y] = 3 # Average
    for x in 0 ..< width * channels:
      # Move through the image data byte-by-byte
      let
        dataPos = y * width * channels + x
        filteredPos = y * width * channels + y + 1 + x
      var left, up: int
      if x - channels >= 0:
        left = data[dataPos - channels].int
      if y - 1 >= 0:
        up = data[(y - 1) * width * channels + x].int
      let avg = ((left + up) div 2).uint8
      filtered[filteredPos] = data[dataPos] - avg

  let compressed =
    try:
      compress(filtered, BestSpeed, dfZlib)
    except ZippyError:
      raise newException(
        PixieError, "Unexpected error compressing PNG image data"
      )
  if compressed.len > int32.high.int:
    raise newException(PixieError, "Compressed PNG image data too large")

  result.addUint32(compressed.len.uint32.swap())
  result.add(cast[seq[uint8]]("IDAT"))
  result.add(compressed)
  result.addUint32(
    crc32(result[result.len - compressed.len - 4 ..< result.len]).swap()
  )

  # Add IEND
  result.addUint32(0)
  result.addStr("IEND")
  result.addUint32(crc32(result[result.len - 4 ..< result.len]).swap())

proc encodePng*(image: Image): string =
  ## Encodes the image data into the PNG file format.
  if image.data.len == 0:
    raise newException(
      PixieError,
      "Image has no data (are height and width 0?)"
    )
  var copy = image.data
  copy.toStraightAlpha()
  cast[string](encodePng(
    image.width, image.height, 4, copy[0].addr, copy.len * 4
  ))

proc encodePng*(mask: Mask): string =
  ## Encodes the mask data into the PNG file format.
  if mask.data.len == 0:
    raise newException(
      PixieError,
      "Mask has no data (are height and width 0?)"
    )
  cast[string](encodePng(
    mask.width, mask.height, 1, mask.data[0].addr, mask.data.len
  ))

when defined(release):
  {.pop.}
