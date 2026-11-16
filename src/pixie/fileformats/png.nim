import chroma, flatty/binny, ../common, ../images, ../internal,
    ../simd, zippy, zippy/inflate, crunchy

# See http://www.libpng.org/pub/png/spec/1.2/PNG-Contents.html

let
  pngSignature* = [137.uint8, 80, 78, 71, 13, 10, 26, 10]

type
  ChunkCounts = object
    PLTE, IDAT, tRNS: uint8

  PngHeader = object
    width, height: int
    bitDepth, colorType, compressionMethod, filterMethod, interlaceMethod: uint8

  ColorRGBA16* = object
    r*, g*, b*, a*: uint16

  Png* = ref object
    width*, height*, channels*, bitDepth*: int
    data*: seq[ColorRGBA]
    data16*: seq[ColorRGBA16]

template failInvalid() =
  raise newException(PixieError, "Invalid PNG buffer, unable to load")

template failCRC() =
  raise newException(PixieError, "CRC check failed")

when defined(release):
  {.push checks: off.}

proc decodeHeader(data: pointer): PngHeader =
  let data = cast[ptr UncheckedArray[uint8]](data)
  result.width = data.readUint32(0).swap().int
  result.height = data.readUint32(4).swap().int
  result.bitDepth = data.readUint8(8)
  result.colorType = data.readUint8(9)
  result.compressionMethod = data.readUint8(10)
  result.filterMethod = data.readUint8(11)
  result.interlaceMethod = data.readUint8(12)

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

proc decodePalette(data: pointer, len: int): seq[ColorRGB] =
  if len == 0 or len mod 3 != 0:
    failInvalid()

  result.setLen(len div 3)

  copyMem(result[0].addr, data, len)

proc unfilter(
  uncompressed: pointer, len, height, rowBytes, bpp: int
): seq[uint8] =
  result.setLen(len - height)

  template uncompressedIdx(x, y: int): int =
    x + y * (rowBytes + 1)

  template unfiteredIdx(x, y: int): int =
    x + y * rowBytes

  let uncompressed = cast[ptr UncheckedArray[uint8]](uncompressed)

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
      let
        uncompressedStartIdx = uncompressedIdx(1, y)
        unfilteredStartIx = unfiteredIdx(0, y)
      for x in 0 ..< rowBytes:
        var value = uncompressed[uncompressedStartIdx + x]
        if x - bpp >= 0:
          value += result[unfilteredStartIx + x - bpp]
        result[unfilteredStartIx + x] = value
    of 2: # Up
      let
        uncompressedStartIdx = uncompressedIdx(1, y)
        unfilteredStartIx = unfiteredIdx(0, y)
      var x: int
      when allowSimd and (defined(amd64) or defined(arm64)):
        if y - 1 >= 0:
          for _ in 0 ..< rowBytes div 16:
            when defined(amd64):
              let
                bytes = mm_loadu_si128(uncompressed[uncompressedStartIdx + x].addr)
                up = mm_loadu_si128(result[unfilteredStartIx + x - rowBytes].addr)
              mm_storeu_si128(
                result[unfilteredStartIx + x].addr,
                mm_add_epi8(bytes, up)
              )
            else: # arm64
              let
                bytes = vld1q_u8(uncompressed[uncompressedStartIdx + x].addr)
                up = vld1q_u8(result[unfilteredStartIx + x - rowBytes].addr)
              vst1q_u8(
                result[unfilteredStartIx + x].addr,
                vaddq_u8(bytes, up)
              )
            x += 16
      for x in x ..< rowBytes:
        var value = uncompressed[uncompressedStartIdx + x]
        if y - 1 >= 0:
          value += result[unfilteredStartIx + x - rowBytes]
        result[unfilteredStartIx + x] = value
    of 3: # Average
      let
        uncompressedStartIdx = uncompressedIdx(1, y)
        unfilteredStartIx = unfiteredIdx(0, y)
      for x in 0 ..< rowBytes:
        var
          value = uncompressed[uncompressedStartIdx + x]
          left, up: uint32
        if x - bpp >= 0:
          left = result[unfilteredStartIx + x - bpp]
        if y - 1 >= 0:
          up = result[unfilteredStartIx + x - rowBytes]
        value += ((left + up) div 2).uint8
        result[unfilteredStartIx + x] = value
    of 4: # Paeth
      let
        uncompressedStartIdx = uncompressedIdx(1, y)
        unfilteredStartIx = unfiteredIdx(0, y)
      for x in 0 ..< rowBytes:
        var
          value = uncompressed[uncompressedStartIdx + x]
          left, up, upLeft: int
        if x - bpp >= 0:
          left = result[unfilteredStartIx + x - bpp].int
        if y - 1 >= 0:
          up = result[unfilteredStartIx + x - rowBytes].int
        if x - bpp >= 0 and y - 1 >= 0:
          upLeft = result[unfilteredStartIx + x - rowBytes - bpp].int
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
        result[unfilteredStartIx + x] = value
    else:
      raise newException(PixieError, "Invalid PNG row filter")

proc valuesPerPixel(header: PngHeader): int =
  case header.colorType:
  of 0: 1
  of 2: 3
  of 3: 1
  of 4: 2
  of 6: 4
  else: 0 # Not possible, decodeHeader validates

proc scanlineBytes(width: int, header: PngHeader): int =
  let bitsPerPixel = header.valuesPerPixel * header.bitDepth.int
  (width * bitsPerPixel + 7) div 8

proc filterBytesPerPixel(header: PngHeader): int =
  max((header.valuesPerPixel * header.bitDepth.int + 7) div 8, 1)

proc adam7Size(size, start, step: int): int =
  if size <= start:
    0
  else:
    (size - start + step - 1) div step

proc packedSample(
  unfiltered: openArray[uint8], rowStart, x: int, bitDepth: uint8
): uint8 =
  case bitDepth:
  of 1:
    (unfiltered[rowStart + x div 8] shr (7 - (x mod 8))) and 1
  of 2:
    (unfiltered[rowStart + x div 4] shr (6 - (x mod 4) * 2)) and 3
  of 4:
    (unfiltered[rowStart + x div 2] shr (4 - (x mod 2) * 4)) and 15
  of 8:
    unfiltered[rowStart + x]
  else:
    0 # 16 bit is rejected before image data is decoded.

proc expandSample(value, bitDepth: uint8): uint8 =
  case bitDepth:
  of 1: value * 255
  of 2: value * 85
  of 4: value * 17
  else: value

proc readUint16be(data: openArray[uint8], offset: int): uint16 {.inline.} =
  (data[offset].uint16 shl 8) or data[offset + 1].uint16

proc readUint16be(data: string, offset: int): uint16 {.inline.} =
  (data.readUint8(offset).uint16 shl 8) or data.readUint8(offset + 1).uint16

proc rgba16*(r, g, b, a: uint16): ColorRGBA16 {.inline.} =
  ColorRGBA16(r: r, g: g, b: b, a: a)

proc toUint8(value: uint16): uint8 {.inline.} =
  ((value.uint32 * 255 + 32767) div 65535).uint8

proc toRgba(color: ColorRGBA16): ColorRGBA {.inline.} =
  rgba(
    color.r.toUint8,
    color.g.toUint8,
    color.b.toUint8,
    color.a.toUint8
  )

proc writePixels(
  image: var seq[ColorRGBA],
  header: PngHeader,
  palette: seq[ColorRGB],
  transparency: string,
  unfiltered: openArray[uint8],
  passWidth, passHeight, startX, startY, stepX, stepY: int
) =
  let
    rowBytes = scanlineBytes(passWidth, header)
    specialGray = if transparency.len == 2: transparency[1].int else: -1

  var specialRgb: ColorRGBA
  if transparency.len == 6:
    specialRgb = rgba(
      transparency.readUint8(1),
      transparency.readUint8(3),
      transparency.readUint8(5),
      255
    )

  for passY in 0 ..< passHeight:
    let
      rowStart = passY * rowBytes
      y = startY + passY * stepY

    for passX in 0 ..< passWidth:
      let
        x = startX + passX * stepX
        dst = x + y * header.width

      case header.colorType:
      of 0:
        let value = expandSample(
          packedSample(unfiltered, rowStart, passX, header.bitDepth),
          header.bitDepth
        )
        let alpha = if value.int == specialGray: 0.uint8 else: 255.uint8
        image[dst] = rgba(value, value, value, alpha)
      of 2:
        let
          src = rowStart + passX * 3
          color = rgba(
            unfiltered[src + 0],
            unfiltered[src + 1],
            unfiltered[src + 2],
            255
          )
        image[dst] =
          if transparency.len == 6 and color == specialRgb:
            rgba(color.r, color.g, color.b, 0)
          else:
            color
      of 3:
        let value = packedSample(unfiltered, rowStart, passX, header.bitDepth)
        if value.int >= palette.len:
          failInvalid()

        let
          rgb = palette[value]
          alpha =
            if transparency.len > value.int:
              transparency.readUint8(value.int)
            else:
              255
        image[dst] = rgba(rgb.r, rgb.g, rgb.b, alpha)
      of 4:
        let src = rowStart + passX * 2
        image[dst] = rgba(
          unfiltered[src],
          unfiltered[src],
          unfiltered[src],
          unfiltered[src + 1]
        )
      of 6:
        let src = rowStart + passX * 4
        image[dst] = rgba(
          unfiltered[src + 0],
          unfiltered[src + 1],
          unfiltered[src + 2],
          unfiltered[src + 3]
        )
      else:
        discard # Not possible, decodeHeader validates

proc writePixels16(
  image: var seq[ColorRGBA16],
  header: PngHeader,
  transparency: string,
  unfiltered: openArray[uint8],
  passWidth, passHeight, startX, startY, stepX, stepY: int
) =
  let
    rowBytes = scanlineBytes(passWidth, header)
    specialGray =
      if transparency.len == 2: transparency.readUint16be(0) else: 0.uint16

  var specialRgb: ColorRGBA16
  if transparency.len == 6:
    specialRgb = rgba16(
      transparency.readUint16be(0),
      transparency.readUint16be(2),
      transparency.readUint16be(4),
      uint16.high
    )

  for passY in 0 ..< passHeight:
    let
      rowStart = passY * rowBytes
      y = startY + passY * stepY

    for passX in 0 ..< passWidth:
      let
        x = startX + passX * stepX
        dst = x + y * header.width

      case header.colorType:
      of 0:
        let value = unfiltered.readUint16be(rowStart + passX * 2)
        let alpha =
          if transparency.len == 2 and value == specialGray:
            0.uint16
          else:
            uint16.high
        image[dst] = rgba16(value, value, value, alpha)
      of 2:
        let src = rowStart + passX * 6
        var color = rgba16(
          unfiltered.readUint16be(src + 0),
          unfiltered.readUint16be(src + 2),
          unfiltered.readUint16be(src + 4),
          uint16.high
        )
        if transparency.len == 6 and color == specialRgb:
          color.a = 0
        image[dst] = color
      of 4:
        let
          src = rowStart + passX * 4
          value = unfiltered.readUint16be(src + 0)
        image[dst] = rgba16(
          value,
          value,
          value,
          unfiltered.readUint16be(src + 2)
        )
      of 6:
        let src = rowStart + passX * 8
        image[dst] = rgba16(
          unfiltered.readUint16be(src + 0),
          unfiltered.readUint16be(src + 2),
          unfiltered.readUint16be(src + 4),
          unfiltered.readUint16be(src + 6)
        )
      else:
        discard # 16-bit paletted PNG is not a valid color/bit-depth combo.

proc filteredSize(header: PngHeader): int {.raises: [PixieError].} =
  ## Computes the exact filtered byte count before decompressing image data.
  var size = 0
  proc addPass(width, height: int) {.raises: [PixieError].} =
    ## Adds one nonempty scanline pass without overflowing the output bound.
    if width == 0 or height == 0:
      return
    let rowBytes =
      (width.int64 * header.valuesPerPixel * header.bitDepth.int + 7) div 8 + 1
    if rowBytes > int.high - 16 or
      height.int64 > (int.high - 16 - size).int64 div rowBytes:
        failInvalid()
    size += rowBytes.int * height
  if header.interlaceMethod == 0:
    addPass(header.width, header.height)
  else:
    const
      StartXs = [0, 4, 0, 2, 0, 1, 0]
      StartYs = [0, 0, 4, 0, 2, 0, 1]
      StepXs = [8, 8, 4, 4, 2, 2, 1]
      StepYs = [8, 8, 8, 4, 4, 2, 2]
    for pass in 0 ..< 7:
      addPass(
        adam7Size(header.width, StartXs[pass], StepXs[pass]),
        adam7Size(header.height, StartYs[pass], StepYs[pass])
      )
  size

proc uncompressZlib(
  data: ptr UncheckedArray[uint8],
  len, expected: int
): string {.raises: [PixieError].} =
  ## Validates zlib framing and bounds inflation to the declared PNG pixels.
  if len < 6:
    failInvalid()
  let
    cmf = data[0]
    flg = data[1]
  if (cmf and 15) != 8 or (cmf shr 4) > 7 or
    (cmf.uint16 * 256 + flg.uint16) mod 31 != 0 or (flg and 32) != 0:
      failInvalid()
  try:
    inflate(result, data, len, 2, expected)
    if result.len != expected or
      adler32(result) != data.readUint32(len - 4).swap:
        failInvalid()
  except ZippyError, CrunchyError:
    failInvalid()

proc uncompressIdats(
  data: ptr UncheckedArray[uint8],
  idats: seq[(int, int)],
  expected: int
): string {.raises: [PixieError].} =
  ## Combines IDAT chunks and inflates no more than the declared pixel data.
  if idats.len > 1:
    var imageData: string
    for (start, len) in idats:
      let op = imageData.len
      imageData.setLen(imageData.len + len)
      copyMem(imageData[op].addr, data[start].addr, len)
    result = uncompressZlib(
      cast[ptr UncheckedArray[uint8]](imageData.cstring),
      imageData.len,
      expected
    )
  else:
    let
      (start, len) = idats[0]
      p = data[start].unsafeAddr
    result = uncompressZlib(cast[ptr UncheckedArray[uint8]](p), len, expected)

proc decodeImageData(
  data: ptr UncheckedArray[uint8],
  header: PngHeader,
  palette: seq[ColorRGB],
  transparency: string,
  idats: seq[(int, int)]
): seq[ColorRGBA] =
  if idats.len == 0:
    failInvalid()

  let uncompressed = uncompressIdats(data, idats, header.filteredSize)

  result.setLen(header.width * header.height)

  if header.interlaceMethod == 0:
    let
      rowBytes = scanlineBytes(header.width, header)
      totalBytes = rowBytes * header.height

    # Uncompressed image data should be the total bytes of pixel data plus
    # a filter byte for each row.
    if uncompressed.len != totalBytes + header.height:
      failInvalid()

    let unfiltered = unfilter(
      uncompressed.cstring,
      uncompressed.len,
      header.height,
      rowBytes,
      header.filterBytesPerPixel
    )
    result.writePixels(
      header, palette, transparency, unfiltered,
      header.width, header.height, 0, 0, 1, 1
    )
  else:
    const
      startXs = [0, 4, 0, 2, 0, 1, 0]
      startYs = [0, 0, 4, 0, 2, 0, 1]
      stepXs = [8, 8, 4, 4, 2, 2, 1]
      stepYs = [8, 8, 8, 4, 4, 2, 2]

    var pos: int
    for pass in 0 ..< 7:
      let
        passWidth = adam7Size(header.width, startXs[pass], stepXs[pass])
        passHeight = adam7Size(header.height, startYs[pass], stepYs[pass])

      if passWidth == 0 or passHeight == 0:
        continue

      let
        rowBytes = scanlineBytes(passWidth, header)
        passLen = (rowBytes + 1) * passHeight

      if pos + passLen > uncompressed.len:
        failInvalid()

      let unfiltered = unfilter(
        uncompressed[pos].unsafeAddr,
        passLen,
        passHeight,
        rowBytes,
        header.filterBytesPerPixel
      )
      result.writePixels(
        header, palette, transparency, unfiltered,
        passWidth, passHeight,
        startXs[pass], startYs[pass], stepXs[pass], stepYs[pass]
      )
      inc(pos, passLen)

    if pos != uncompressed.len:
      failInvalid()

proc decodeImageData16(
  data: ptr UncheckedArray[uint8],
  header: PngHeader,
  transparency: string,
  idats: seq[(int, int)]
): seq[ColorRGBA16] =
  if idats.len == 0:
    failInvalid()

  let uncompressed = uncompressIdats(data, idats, header.filteredSize)

  result.setLen(header.width * header.height)

  if header.interlaceMethod == 0:
    let
      rowBytes = scanlineBytes(header.width, header)
      totalBytes = rowBytes * header.height

    # Uncompressed image data should be the total bytes of pixel data plus
    # a filter byte for each row.
    if uncompressed.len != totalBytes + header.height:
      failInvalid()

    let unfiltered = unfilter(
      uncompressed.cstring,
      uncompressed.len,
      header.height,
      rowBytes,
      header.filterBytesPerPixel
    )
    result.writePixels16(
      header, transparency, unfiltered,
      header.width, header.height, 0, 0, 1, 1
    )
  else:
    const
      startXs = [0, 4, 0, 2, 0, 1, 0]
      startYs = [0, 0, 4, 0, 2, 0, 1]
      stepXs = [8, 8, 4, 4, 2, 2, 1]
      stepYs = [8, 8, 8, 4, 4, 2, 2]

    var pos: int
    for pass in 0 ..< 7:
      let
        passWidth = adam7Size(header.width, startXs[pass], stepXs[pass])
        passHeight = adam7Size(header.height, startYs[pass], stepYs[pass])

      if passWidth == 0 or passHeight == 0:
        continue

      let
        rowBytes = scanlineBytes(passWidth, header)
        passLen = (rowBytes + 1) * passHeight

      if pos + passLen > uncompressed.len:
        failInvalid()

      let unfiltered = unfilter(
        uncompressed[pos].unsafeAddr,
        passLen,
        passHeight,
        rowBytes,
        header.filterBytesPerPixel
      )
      result.writePixels16(
        header, transparency, unfiltered,
        passWidth, passHeight,
        startXs[pass], startYs[pass], stepXs[pass], stepYs[pass]
      )
      inc(pos, passLen)

    if pos != uncompressed.len:
      failInvalid()

proc newImage*(png: Png): Image {.raises: [PixieError].} =
  ## Creates a new Image from the PNG.
  result = newImage(png.width, png.height)
  if png.data.len > 0:
    copyMem(result.data[0].addr, png.data[0].addr, png.data.len * 4)
    result.data.toPremultipliedAlpha()
  else:
    for i, color in png.data16:
      result.data[i] = color.toRgba.rgbx()

proc convertToImage*(png: Png): Image {.raises: [].} =
  ## Converts a PNG into an Image by moving the data. This is faster but can
  ## only be done once.
  type Movable = ref object
    width, height, channels, bitDepth: int
    data: seq[ColorRGBX]
    data16: seq[ColorRGBA16]

  result = Image()
  result.width = png.width
  result.height = png.height
  if png.data.len > 0:
    result.data = move cast[Movable](png).data
    result.data.toPremultipliedAlpha()
  else:
    result.data.setLen(png.data16.len)
    for i, color in png.data16:
      result.data[i] = color.toRgba.rgbx()

proc decodePngDimensions*(
  data: pointer, len: int
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes the PNG dimensions.
  if len < (8 + (8 + 13 + 4) + 4): # Magic bytes + IHDR + IEND
    failInvalid()

  let data = cast[ptr UncheckedArray[uint8]](data)

  # PNG file signature
  let signature = cast[array[8, uint8]](data.readUint64(0))
  if signature != pngSignature:
    failInvalid()

  # First chunk must be IHDR
  if data.readUint32(8).swap() != 13 or data.readStr(12, 4) != "IHDR":
    failInvalid()

  let header = decodeHeader(data[16].addr)
  result.width = header.width
  result.height = header.height

proc decodePngDimensions*(
  data: string
): ImageDimensions {.inline, raises: [PixieError].} =
  ## Decodes the PNG dimensions.
  decodePngDimensions(data.cstring, data.len)

proc decodePng*(data: pointer, len: int): Png {.raises: [PixieError].} =
  ## Decodes the PNG data.
  if len < (8 + (8 + 13 + 4) + 4): # Magic bytes + IHDR + IEND
    failInvalid()

  let data = cast[ptr UncheckedArray[uint8]](data)

  # PNG file signature
  let signature = cast[array[8, uint8]](data.readUint64(0))
  if signature != pngSignature:
    failInvalid()

  var
    pos = 8 # After signature
    counts = ChunkCounts()
    header: PngHeader
    palette: seq[ColorRGB]
    transparency: string
    idats: seq[(int, int)]
    prevChunkType: string

  # First chunk must be IHDR
  if data.readUint32(pos).swap() != 13 or
    data.readStr(pos + 4, 4) != "IHDR":
    failInvalid()
  inc(pos, 8)
  header = decodeHeader(data[pos].addr)
  prevChunkType = "IHDR"
  inc(pos, 13)

  let headerCrc = crc32(data[pos - 17].addr, 17)
  if headerCrc != data.readUint32(pos).swap():
    failCRC()
  inc(pos, 4) # CRC

  while true:
    if pos + 8 > len:
      failInvalid()

    let
      chunkLen = data.readUint32(pos).swap().int
      chunkType = data.readStr(pos + 4, 4)
    inc(pos, 8)

    if chunkLen > high(int32).int:
      failInvalid()

    if pos + chunkLen + 4 > len:
      failInvalid()

    case chunkType:
    of "IHDR":
      failInvalid()
    of "PLTE":
      inc counts.PLTE
      if counts.PLTE > 1 or counts.IDAT > 0 or counts.tRNS > 0:
        failInvalid()
      palette = decodePalette(data[pos].addr, chunkLen)
    of "tRNS":
      inc counts.tRNS
      if counts.tRNS > 1 or counts.IDAT > 0:
        failInvalid()
      transparency = data.readStr(pos, chunkLen)
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
      idats.add((pos, chunkLen))
    of "IEND":
      if chunkLen != 0:
        failInvalid()
    else:
      if (chunkType.readUint8(0) and 0b00100000) == 0:
        raise newException(
          PixieError, "Unrecognized PNG critical chunk " & chunkType
        )

    inc(pos, chunkLen)

    let chunkCrc = crc32(data[pos - chunkLen - 4].addr, chunkLen + 4)
    if chunkCrc != data.readUint32(pos).swap():
      failCRC()
    inc(pos, 4) # CRC

    prevChunkType = chunkType

    if pos == len or prevChunkType == "IEND":
      break

  if prevChunkType != "IEND":
    failInvalid()

  result = Png()
  result.width = header.width
  result.height = header.height
  result.channels = 4
  result.bitDepth = header.bitDepth.int
  if header.bitDepth == 16:
    result.data16 = decodeImageData16(data, header, transparency, idats)
  else:
    result.data = decodeImageData(data, header, palette, transparency, idats)

proc decodePng*(data: string): Png {.inline, raises: [PixieError].} =
  ## Decodes the PNG data.
  decodePng(data.cstring, data.len)

proc encodePng*(
  width, height, channels: int, data: pointer, len: int
): string {.raises: [PixieError].} =
  ## Encodes the image data into the PNG file format.
  ## If data points to RGBA data, it is assumed to be straight alpha.

  if width <= 0 or width > int32.high.int:
    raise newException(PixieError, "Invalid PNG width")

  if height <= 0 or height > int32.high.int:
    raise newException(PixieError, "Invalid PNG height")

  if len != width * height * channels:
    raise newException(PixieError, "Invalid PNG data size")

  let colorType = case channels:
    of 1: 0.char
    of 2: 4.char
    of 3: 2.char
    of 4: 6.char
    else:
      raise newException(PixieError, "Invalid PNG number of channels")

  let data = cast[ptr UncheckedArray[uint8]](data)

  # Add the PNG file signature
  for c in pngSignature:
    result.add(c.char)

  # Add IHDR
  result.addUint32(13.uint32.swap())
  result.add("IHDR")
  result.addUint32(width.uint32.swap())
  result.addUint32(height.uint32.swap())
  result.add(8.char)
  result.add(colorType)
  result.add(0.char)
  result.add(0.char)
  result.add(0.char)
  result.addUint32(crc32(result[result.len - 17].addr, 17).swap())

  # Add IDAT
  # Add room for 1 byte before each row for the filter type.
  var
    filtered = newString(width * height * channels + height)
    upRow = newSeq[uint8](width * channels)
    subRow = newSeq[uint8](width * channels)
    avgRow = newSeq[uint8](width * channels)
  for y in 0 ..< height:
    let rowStart = y * width * channels
    for x in 0 ..< width * channels:
      # Move through the image data byte-by-byte
      let dataPos = rowStart + x
      var left, up: uint8
      if x - channels >= 0:
        left = data[dataPos - channels]
      if y - 1 >= 0:
        up = data[(y - 1) * width * channels + x]
      upRow[x] = data[dataPos] - up.uint8
      subRow[x] = data[dataPos] - left.uint8
      let avg = ((left.int + up.int) div 2).uint8
      avgRow[x] = data[dataPos] - avg

    var upRowSum, subRowSum, avgRowSum: uint64
    for i in 0 ..< upRow.len:
      upRowSum += upRow[i]
      subRowSum += subRow[i]
      avgRowSum += avgRow[i]

    let minRowSum = min(min(upRowSum, subRowSum), avgRowSum)

    if upRowSum == minRowSum:
      filtered[rowStart + y] = 2.char # Up filter type
      copyMem(
        filtered[rowStart + y + 1].addr,
        upRow[0].addr,
        upRow.len
      )
    elif subRowSum == minRowSum:
      filtered[rowStart + y] = 1.char # Sub filter type
      copyMem(
        filtered[rowStart + y + 1].addr,
        subRow[0].addr,
        subRow.len
      )
    else:
      filtered[rowStart + y] = 3.char # Average filter type
      copyMem(
        filtered[rowStart + y + 1].addr,
        avgRow[0].addr,
        avgRow.len
      )

  let compressed =
    try:
      compress(filtered, DefaultCompression, dfZlib)
    except ZippyError:
      raise newException(
        PixieError, "Unexpected error compressing PNG image data"
      )
  if compressed.len > int32.high.int:
    raise newException(PixieError, "Compressed PNG image data too large")

  result.addUint32(compressed.len.uint32.swap())
  result.add("IDAT")
  result.add(compressed)
  result.addUint32(crc32(
    result[result.len - compressed.len - 4].addr,
    compressed.len + 4
  ).swap())

  # Add IEND
  result.addUint32(0)
  result.add("IEND")
  result.addUint32(crc32(result[result.len - 4].addr, 4).swap())

proc encodePng*(png: Png): string {.raises: [PixieError].} =
  if png.data.len > 0:
    encodePng(png.width, png.height, 4, png.data[0].addr, png.data.len * 4)
  elif png.data16.len > 0:
    var data = newSeq[ColorRGBA](png.data16.len)
    for i, color in png.data16:
      data[i] = color.toRgba()
    encodePng(png.width, png.height, 4, data[0].addr, data.len * 4)
  else:
    raise newException(PixieError, "PNG has no data")

proc encodePng*(image: Image): string {.raises: [PixieError].} =
  ## Encodes the image data into the PNG file format.
  if image.data.len == 0:
    raise newException(
      PixieError,
      "Image has no data (are height and width 0?)"
    )
  var copy = image.data
  copy.toStraightAlpha()
  encodePng(image.width, image.height, 4, copy[0].addr, copy.len * 4)

when defined(release):
  {.pop.}
