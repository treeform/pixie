import chroma, flatty/binny, std/math, std/strutils, pixie/common, pixie/images, zippy/bitstreams

# See: https://en.wikipedia.org/wiki/GIF

const gifSignatures* = @["GIF87a", "GIF89a"]

type
  Gif* = ref object
    frames*: seq[Image]

template failInvalid() =
  raise newException(PixieError, "Invalid GIF buffer, unable to load")

when defined(release):
  {.push checks: off.}

proc decodeGif*(data: string): Gif {.raises: [PixieError].} =
  ## Decodes GIF data.
  if data.len < 13:
    failInvalid()

  if data[0 .. 5] notin gifSignatures:
    raise newException(PixieError, "Invalid GIF file signature")

  result = Gif()

  let
    screenWidth = data.readInt16(6).int
    screenHeight = data.readInt16(8).int
    globalFlags = data.readUint8(10).int
    hasGlobalColorTable = (globalFlags and 0b10000000) != 0
    globalColorTableSize = 2 ^ ((globalFlags and 0b00000111) + 1)
    bgColorIndex = data.readUint8(11).int
    pixelAspectRatio = data.readUint8(12)

  if not hasGlobalColorTable:
    raise newException(PixieError, "Unsupported GIF, no global color table")

  if bgColorIndex > globalColorTableSize:
    failInvalid()

  if pixelAspectRatio != 0:
    raise newException(PixieError, "Unsupported GIF, pixel aspect ratio")

  var pos = 13

  if pos + globalColorTableSize * 3 > data.len:
    failInvalid()

  var globalColorTable = newSeq[ColorRGBX](globalColorTableSize)
  for i in 0 ..< globalColorTable.len:
    globalColorTable[i] = rgbx(
      data.readUint8(pos + 0),
      data.readUint8(pos + 1),
      data.readUint8(pos + 2),
      255
    )
    pos += 3

  while true:
    if pos + 1 > data.len:
      failInvalid()

    let blockType = data.readUint8(pos)
    inc pos

    case blockType:
    of 0x2c: # Image
      if pos + 9 > data.len:
        failInvalid()

      let
        imageLeftPos = data.readUint16(pos + 0).int
        imageTopPos = data.readUint16(pos + 2).int
        imageWidth = data.readUint16(pos + 4).int
        imageHeight = data.readUint16(pos + 6).int
        imageFlags = data.readUint16(pos + 8)
        hasLocalColorTable = (imageFlags and 0b10000000) != 0
        interlaced = (imageFlags and 0b01000000) != 0
        localColorTableSize = 2 ^ ((imageFlags and 0b00000111) + 1)

      pos += 9

      var localColorTable: seq[ColorRGBX]
      if hasLocalColorTable:
        localColorTable.setLen(localColorTableSize)
        for i in 0 ..< localColorTable.len:
          localColorTable[i] = rgbx(
            data.readUint8(pos + 0),
            data.readUint8(pos + 1),
            data.readUint8(pos + 2),
            255
          )
          pos += 3

      if interlaced:
        raise newException(PixieError, "Interlaced GIF not supported yet")

      if pos + 1 > data.len:
        failInvalid()

      let minCodeSize = data.readUint8(pos).int
      inc pos

      if minCodeSize > 11:
        failInvalid()

      # The image data is contained in a sequence of sub-blocks
      var lzwDataBlocks: seq[(int, int)] # (offset, len)
      while true:
        if pos + 1 > data.len:
          failInvalid()

        let subBlockSize = data.readUint8(pos).int
        inc pos

        if subBlockSize == 0:
          break

        if pos + subBlockSize > data.len:
          failInvalid()

        lzwDataBlocks.add((pos, subBlockSize))

        pos += subBlockSize

      var lzwDataLen: int
      for (_, len) in lzwDataBlocks:
        lzwDataLen += len

      var
        lzwData = newString(lzwDataLen)
        i: int
      for (offset, len) in lzwDataBlocks:
        copyMem(lzwData[i].addr, data[offset].unsafeAddr, len)
        i += len

      let
        clearCode = 1 shl minCodeSize
        endCode = clearCode + 1

      var
        b = BitStreamReader(
          src: cast[ptr UncheckedArray[uint8]](lzwData.cstring),
          len: lzwData.len
        )
        colorIndexes: seq[int]
        codeSize = minCodeSize + 1
        table = newSeq[(int, int)](endCode + 1)
        prev: (int, int)

      while true:
        let code = b.readBits(codeSize).int
        if b.bitsBuffered < 0:
          failInvalid()
        if code == endCode:
          break

        if code == clearCode:
          codeSize = minCodeSize + 1
          table.setLen(endCode + 1)
          prev = (0, 0)
          continue

        # Increase the code size if needed
        if table.len == (1 shl codeSize) - 1 and codeSize < 12:
          inc codeSize

        let start = colorIndexes.len
        if code < table.len: # If we have seen the code before
          if code < clearCode:
            colorIndexes.add(code)
            if prev[1] > 0:
              table.add((prev[0], prev[1] + 1))
            prev = (start, 1)
          else:
            let (offset, len) = table[code]
            for i in 0 ..< len:
              colorIndexes.add(colorIndexes[offset + i])
            table.add((prev[0], prev[1] + 1))
            prev = (start, len)
        else:
          if prev[1] == 0:
            failInvalid()
          for i in 0 ..< prev[1]:
            colorIndexes.add(colorIndexes[prev[0] + i])
          colorIndexes.add(colorIndexes[prev[0]])
          table.add((start, prev[1] + 1))
          prev = (start, prev[1] + 1)

      if colorIndexes.len != imageWidth * imageHeight:
        failInvalid()

      let image = newImage(imageWidth, imageHeight)

      if hasLocalColorTable:
        for i, colorIndex in colorIndexes:
          if colorIndex >= localColorTable.len:
            failInvalid()
          image.data[i] = localColorTable[colorIndex]
      else:
        for i, colorIndex in colorIndexes:
          if colorIndex >= globalColorTable.len:
            failInvalid()
          image.data[i] = globalColorTable[colorIndex]

      result.frames.add(image)

    of 0x21: # Extension
      if pos + 1 > data.len:
        failInvalid()

      let extensionType = data.readUint8(pos + 0)
      inc pos

      case extensionType:
      of 0xf9:
        # Graphic Control Extension
        if pos + 1 > data.len:
          failInvalid()

        let blockSize = data.readUint8(pos).int
        inc pos

        if blockSize != 4:
          failInvalid()

        if pos + blockSize > data.len:
          failInvalid()

        pos += blockSize
        inc pos # Block terminator

      # of 0xfe:
      #   # Comment

      # of 0x01:
      #   # Plain Text

      of 0xff:
        # Application Specific
        if pos + 1 > data.len:
          failInvalid()

        let blockSize = data.readUint8(pos).int
        inc pos

        if blockSize != 11:
          failInvalid()

        if pos + blockSize > data.len:
          failInvalid()

        pos += blockSize

        while true: # Skip data sub-blocks
          if pos + 1 > data.len:
            failInvalid()

          let subBlockSize = data.readUint8(pos).int
          inc pos

          if subBlockSize == 0:
            break

          pos += subBlockSize

      else:
        raise newException(
          PixieError,
          "Unexpected GIF extension type " & toHex(extensionType)
        )

    of 0x3b: # Trailer
      break

    else:
      raise newException(
        PixieError,
        "Unexpected GIF block type " & toHex(blockType)
      )

proc newImage*(gif: Gif): Image {.raises: [].} =
  gif.frames[0]

when defined(release):
  {.pop.}
