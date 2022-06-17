import chroma, flatty/binny, pixie/common, pixie/images, pixie/internal

const
  tiffSignatures* = [
    [0x4d.uint8, 0x4d, 0x00, 0x2a],
    [0x49.uint8, 0x49, 0x2a, 0x00]
  ]
  knownTags = [
    0x0100.uint16, # ImageWidth
    0x0101,        # ImageLength
    0x0102,        # BitsPerSample
    0x0103,        # Compression
    0x0106,        # PhotometricInterpretation
    0x0111,        # StripOffsets
    0x0116,        # RowsPerStrip
    0x0117,        # StripByteCounts
    0x0140,        # ColorMap
  ]

type
  Tiff* = ref object
    width*, height*: int
    data*: seq[ColorRGBA]

template failInvalid() =
  raise newException(PixieError, "Invalid TIFF buffer, unable to load")

proc decodeTiff*(data: string): Tiff =
  if data.len < 8:
    failInvalid()

  result = Tiff()

  var
    pos: int
    isBigEndian: bool
    bitsPerSample: seq[int]
    compression: int
    photometricInterpretation: int
    stripOffsets, stripByteCounts: seq[int]
    rowsPerStrip: int
    colorMap: seq[ColorRGBA]

  let signature = cast[array[4, uint8]](data.readUint32(0))
  if signature == tiffSignatures[0]:
    isBigEndian = true
  elif signature == tiffSignatures[1]:
    discard
  else:
    failInvalid()

  pos = 4

  let ifdOffset = data.readUint32(pos).maybeSwap(isBigEndian).int
  pos = ifdOffset # Move to the first IFD offset

  if pos + 2 > data.len:
    failInvalid()

  let numEntries = data.readUint16(pos).maybeSwap(isBigEndian).int
  pos += 2

  for _ in 0 ..< numEntries:
    if pos + 12 > data.len:
      failInvalid()

    let
      tag = data.readUint16(pos + 0).maybeSwap(isBigEndian)
      fieldType = data.readUint16(pos + 2).maybeSwap(isBigEndian)
      numValues = data.readUint32(pos + 4).maybeSwap(isBigEndian).int
      valueOrOffset = pos + 8

    pos += 12

    if tag notin knownTags:
      continue

    let bytesPerValue =
      case fieldType:
      of 1:
        1
      of 2:
        1
      of 3:
        2
      of 4:
        4
      else:
        raise newException(PixieError, "Unsupported field type " & $fieldType)

    var valueOffset =
      if numValues * bytesPerValue <= 4:
        valueOrOffset
      else:
        data.readUint32(valueOrOffset).maybeSwap(isBigEndian).int

    proc readValue(offset: int): int =
      case fieldType:
      of 1:
        if offset + 1 > data.len:
          failInvalid()
        data.readUint8(offset).maybeSwap(isBigEndian).int
      of 3:
        if offset + 2 > data.len:
          failInvalid()
        data.readUint16(offset).maybeSwap(isBigEndian).int
      of 4:
        if offset + 4 > data.len:
          failInvalid()
        data.readUint32(offset).maybeSwap(isBigEndian).int
      else:
        raise newException(PixieError, "Unsupported field type " & $fieldType)

    case tag:
    of knownTags[0]:
      if numValues != 1:
        failInvalid()
      result.width = readValue(valueOffset)
    of knownTags[1]:
      if numValues != 1:
        failInvalid()
      result.height = readValue(valueOffset)
    of knownTags[2]:
      for _ in 0 ..< numValues:
        bitsPerSample.add(readValue(valueOffset))
        valueOffset += bytesPerValue
    of knownTags[3]:
      if numValues != 1:
        failInvalid()
      compression = readValue(valueOffset)
    of knownTags[4]:
      if numValues != 1:
        failInvalid()
      photometricInterpretation = readValue(valueOffset)
    of knownTags[5]:
      for _ in 0 ..< numValues:
        stripOffsets.add(readValue(valueOffset))
        valueOffset += bytesPerValue
    of knownTags[6]:
      if numValues != 1:
        failInvalid()
      rowsPerStrip = readValue(valueOffset)
    of knownTags[7]:
      for _ in 0 ..< numValues:
        stripByteCounts.add(readValue(valueOffset))
        valueOffset += bytesPerValue
    of knownTags[8]:
      if fieldType != 3:
        failInvalid()
      var values: seq[int]
      for _ in 0 ..< numValues:
        values.add(readValue(valueOffset))
        valueOffset += bytesPerValue
      colorMap.setLen(numValues div 3)
      for i in 0 ..< colorMap.len:
        colorMap[i] = rgba(
          ((values[i].float32 / 65535) * 255).uint8,
          ((values[i + colorMap.len].float32 / 65535) * 255).uint8,
          ((values[i + 2 * colorMap.len].float32 / 65535) * 255).uint8,
          255
        )
    else:
      discard

  if result.width == 0 or result.height == 0:
    failInvalid()

  if stripOffsets.len != stripByteCounts.len:
    failInvalid()

  if bitsPerSample.len == 0:
    failInvalid()

  for i, bits in bitsPerSample:
    if bits notin {8}:
      raise newException(
        PixieError,
        "TIFF bits per sample of " & $bits & " not supported yet"
      )

  # Check the bits per sample are all equal
  for i in 0 ..< bitsPerSample.len:
    for j in 0 ..< bitsPerSample.len:
      if bitsPerSample[i] != bitsPerSample[j]:
        failInvalid()

  var decompressed: string
  case compression:
  of 1: # No compression
    var stripDataLen: int
    for byteCount in stripByteCounts:
      stripDataLen += byteCount

    decompressed.setLen(stripDataLen)

    var at: int
    for i, offset in stripOffsets:
      let byteCount = stripByteCounts[i]
      if offset + byteCount > data.len:
        failInvalid()
      copyMem(decompressed[at].addr, data[offset].unsafeAddr, byteCount)
      at += byteCount

  # of 5: # LZW

  else:
    raise newException(
      PixieError,
      "TIFF compression " & $compression & " not supported yet"
    )

  result.data.setLen(result.width * result.height)

  case photometricInterpretation:
  of 2: # RGB
    if bitsPerSample.len == 4: # 32 bit RGBA
      raise newException(PixieError, "RGBA TIFF not supported yet")
    elif bitsPerSample.len == 3: # 24 bit RGB
      if decompressed.len div 3 != result.data.len:
        failInvalid()
      for i in 0 ..< result.data.len:
        let decompressedIdx = i * 3
        result.data[i] = rgba(
          decompressed[decompressedIdx + 0].uint8,
          decompressed[decompressedIdx + 1].uint8,
          decompressed[decompressedIdx + 2].uint8,
          255
        )
    else:
      failInvalid()

  of 3: # Color Map
    if decompressed.len != result.data.len:
      failInvalid()
    for i in 0 ..< result.data.len:
      let colorMapIndex = decompressed[i].int
      if colorMapIndex > colorMap.len:
        failInvalid()
      result.data[i] = colorMap[colorMapIndex]

  else:
    raise newException(
      PixieError,
      "TIFF photometric interpretation " & $photometricInterpretation &
      " not supported yet"
    )

proc newImage*(tiff: Tiff): Image =
  result = newImage(tiff.width, tiff.height)
  copyMem(result.data[0].addr, tiff.data[0].addr, tiff.data.len * 4)
  result.data.toPremultipliedAlpha()

proc convertToImage*(tiff: Tiff): Image {.raises: [].} =
  ## Converts a PNG into an Image by moving the data. This is faster but can
  ## only be done once.
  type Movable = ref object
    width, height, channels: int
    data: seq[ColorRGBX]

  result = Image()
  result.width = tiff.width
  result.height = tiff.height
  result.data = move cast[Movable](tiff).data
  result.data.toPremultipliedAlpha()
