import chroma, flatty/binny, math, pixie/common, pixie/images, zippy/bitstreams

const gifSignatures* = @["GIF87a", "GIF89a"]

# See: https://en.wikipedia.org/wiki/GIF

template failInvalid() =
  raise newException(PixieError, "Invalid GIF buffer, unable to load")

when defined(release):
  {.push checks: off.}

proc decodeGif*(data: string): Image =
  ## Decodes GIF data into an Image.

  if data.len <= 13: failInvalid()
  let version = data[0 .. 5]
  if version notin gifSignatures:
    raise newException(PixieError, "Invalid GIF file signature")

  let
    # Read information about the image.
    width = data.readInt16(6).int
    height = data.readInt16(8).int
    flags = data.readUint8(10).int
    hasColorTable = (flags and 0x80) != 0
    originalDepth = ((flags and 0x70) shr 4) + 1
    colorTableSorted = (flags and 0x8) != 0
    colorTableSize = 2 ^ ((flags and 0x7) + 1)
    bgColorIndex = data.readUint8(11)
    pixelAspectRatio = data.readUint8(11)

  result = newImage(width, height)

  # Read the main color table.
  var
    colors: seq[ColorRGBA]
    i = 13
  if hasColorTable:
    if i + colorTableSize * 3 >= data.len: failInvalid()
    for c in 0 ..< colorTableSize:
      let
        r = data.readUint8(i + 0)
        g = data.readUint8(i + 1)
        b = data.readUint8(i + 2)
      colors.add(rgba(r, g, b, 255))
      i += 3

  # Read the image blocks.
  while true:
    let blockType = data.readUint8(i)
    i += 1
    case blockType:
    of 0x2c: # Read IMAGE block.
      if i + 9 >= data.len: failInvalid()
      let
        left = data.readUint16(i + 0)
        top = data.readUint16(i + 2)
        w = data.readUint16(i + 4).int
        h = data.readUint16(i + 6).int
        flags = data.readUint8(i + 8)

        hasColorTable = (flags and 0x80) != 0
        interlace = (flags and 0x40) != 0
        colorTableSorted = (flags and 0x8) != 0
        colorTableSize = 2 ^ ((flags and 0x7) + 1)

      i += 9

      # Make sure we support the GIF features.
      if left != 0 or top != 0 or w != result.width or h != result.height:
        raise newException(PixieError, "GIF block offsets not supported")

      if hasColorTable:
        raise newException(
          PixieError, "GIF color table per block not yet supported"
        )

      if interlace:
        raise newException(PixieError, "Interlaced GIF not yet supported")

      # Read the lzw data chunks.
      if i >= data.len: failInvalid()
      let lzwMinBitSize = data.readUint8(i)
      i += 1
      var lzwData = ""
      while true:
        if i >= data.len: failInvalid()
        let lzwEncodedLen = data.readUint8(i)
        i += 1
        if lzwEncodedLen == 0:
          # Stop reading when chunk len is 0.
          break
        if i + lzwEncodedLen.int > data.len: failInvalid()
        lzwData.add data[i ..< i + lzwEncodedLen.int]
        i += lzwEncodedLen.int

      let
        clearCode = 1 shl lzwMinBitSize
        endCode = clearCode + 1

      # Turn full lzw data into bit stream.
      var
        bs = initBitStream(cast[seq[uint8]](lzwData))
        bitSize = lzwMinBitSize + 1
        currentCodeTableMax = (1 shl (bitSize)) - 1
        codeLast: int = -1
        codeTable: seq[seq[int]]
        colorIndexes: seq[int]

      # Main decode loop.
      while codeLast != endCode:
        if bs.pos + bitSize.int > bs.data.len * 8: failInvalid()
        var
          # Read variable bits out of the table.
          codeId = bs.readBits(bitSize).int
          # Some time we need to carry over table information.
          carryOver: seq[int]

        if codeId == clearCode:
          # Clear and re-init the tables.
          bitSize = lzwMinBitSize + 1
          currentCodeTableMax = (1 shl (bitSize)) - 1
          codeLast = -1
          codeTable.setLen(0)
          for x in 0 ..< endCode + 1:
            codeTable.add(@[x])

        elif codeId == endCode:
          # Exit we are done.
          break

        elif codeId < codeTable.len and codeTable[codeId].len > 0:
          # Its in the current table, use it.
          let current = codeTable[codeId]
          colorIndexes.add(current)
          carryOver = @[current[0]]

        elif codeLast notin [-1, clearCode, endCode]:
          # Its in the current table use it.
          if codeLast >= codeTable.len: failInvalid()
          var previous = codeTable[codeLast]
          carryOver = @[previous[0]]
          colorIndexes.add(previous & carryOver)

        if codeTable.len == currentCodeTableMax and bitSize < 12:
          # We need to expand the codeTable max and the bit size.
          inc bitSize
          currentCodeTableMax = (1 shl (bitSize)) - 1

        if codeLast notin [-1, clearCode, endCode]:
          # We had some left over and need to expand table.
          if codeLast >= codeTable.len: failInvalid()
          codeTable.add(codeTable[codeLast] & carryOver)

        codeLast = codeId

      # Convert color indexes into real colors.
      for j, idx in colorIndexes:
        if idx >= colors.len or j >= result.data.len: failInvalid()
        result.data[j] = colors[idx].rgbx()

    of 0x21: # Read EXTENSION block.
      # Skip over all extensions (mostly animation information).
      let extentionType = data.readUint8(i)
      inc i
      let byteLen = data.readUint8(i)
      inc i
      i += byteLen.int
      doAssert data.readUint8(i) == 0
      inc i
    of 0x3b: # Read TERMINAL block.
      # Exit block byte - we are done.
      return
    else:
      raise newException(PixieError, "Invalid GIF block type")

when defined(release):
  {.pop.}
