import chroma, flatty/binny, webp_vp8_tables, ../common, ../images

# WebP is a RIFF container around VP8 or VP8L image data.
# See: https://developers.google.com/speed/webp/docs/riff_container

const
  WebpRiffSignature* = "RIFF"
  WebpSignature* = "WEBP"
  WebpVp8Signature* = "VP8 "
  WebpVp8LSignature* = "VP8L"
  WebpVp8XSignature* = "VP8X"
  WebpAlphaSignature* = "ALPH"
  WebpAnimSignature* = "ANIM"
  WebpAnimFrameSignature* = "ANMF"
  WebpIccpSignature* = "ICCP"
  WebpExifSignature* = "EXIF"
  WebpXmpSignature* = "XMP "

type
  WebpCompression* = enum
    UnknownWebpCompression
    LossyWebp
    LosslessWebp

  WebpChunkKind* = enum
    UnknownWebpChunk
    Vp8Chunk
    Vp8LChunk
    Vp8XChunk
    AlphaChunk
    AnimChunk
    AnimFrameChunk
    IccpChunk
    ExifChunk
    XmpChunk

  WebpAlphaInfo* = object
    compressionMethod*, filterMethod*, preprocessing*: int

  WebpChunkInfo* = object
    kind*: WebpChunkKind
    fourcc*: string
    offset*, size*: int

  WebpInfo* = ref object
    ## Parsed WebP container and bitstream header information.
    width*, height*: int
    fileSize*: int
    compression*: WebpCompression
    chunks*: seq[WebpChunkInfo]

    hasVp8X*, hasAlpha*, hasIccp*, hasExif*, hasXmp*, hasAnimation*: bool
    losslessAlpha*: bool
    vp8Version*: int
    vp8ShowFrame*: bool

    vp8Offset*, vp8Size*: int
    vp8LOffset*, vp8LSize*: int
    alphaOffset*, alphaSize*: int
    iccpOffset*, iccpSize*: int
    exifOffset*, exifSize*: int
    xmpOffset*, xmpSize*: int

    alphaInfo*: WebpAlphaInfo
    backgroundColor*: ColorRGBA
    loopCount*, frameCount*: int

  LosslessBitReader = ref object
    data: string
    pos, endPos: int
    buffer: uint64
    nbits: int

  HuffmanTree = ref object
    single: bool
    symbol: uint16
    tableMask: uint16
    primaryTable, secondaryTable: seq[uint16]

  ColorCache = ref object
    bits: int
    colors: seq[array[4, uint8]]

  HuffmanCodeGroup = array[5, HuffmanTree]

  HuffmanInfo = ref object
    xsize: int
    colorCache: ColorCache
    hasColorCache: bool
    image: seq[uint16]
    bits, mask: int
    groups: seq[HuffmanCodeGroup]

  LosslessTransformKind = enum
    PredictorTransform
    ColorTransform
    SubtractGreenTransform
    ColorIndexingTransform

  LosslessTransform = ref object
    kind: LosslessTransformKind
    sizeBits, tableSize: int
    data: seq[uint8]

  LosslessDecoder = ref object
    bitReader: LosslessBitReader
    transforms: array[4, LosslessTransform]
    hasTransform: array[4, bool]
    transformOrder: seq[int]
    width, height: int

  Vp8BoolDecoder = ref object
    data: string
    pos, endPos: int
    value: uint64
    range: uint32
    bitCount: int
    zeroByteAfterEof: bool

  Vp8Segment = object
    ydc, yac: int16
    y2dc, y2ac: int16
    uvdc, uvac: int16
    deltaValues: bool
    quantizerLevel, loopfilterLevel: int8

  Vp8MacroBlock = object
    bpred: array[16, int]
    lumaMode, chromaMode: int
    segmentId: uint8
    coeffsSkipped, nonZeroDct: bool

  Vp8PreviousMacroBlock = object
    bpred: array[4, int]
    complexity: array[9, uint8]

  Vp8Frame = ref object
    width, height: int
    version, pixelType, filterLevel, sharpnessLevel: uint8
    forDisplay, filterType: bool
    ybuf, ubuf, vbuf: seq[uint8]

  Vp8Decoder = ref object
    b: Vp8BoolDecoder
    mbWidth, mbHeight: int
    macroblocks: seq[Vp8MacroBlock]
    frame: Vp8Frame
    segmentsEnabled, segmentsUpdateMap: bool
    segments: array[4, Vp8Segment]
    loopFilterAdjustmentsEnabled: bool
    refDelta, modeDelta: array[4, int]
    partitions: array[8, Vp8BoolDecoder]
    numPartitions: int
    segmentProbs: array[3, uint8]
    tokenProbs: Vp8TokenProbTables
    hasProbSkipFalse: bool
    probSkipFalse: uint8
    top: seq[Vp8PreviousMacroBlock]
    left: Vp8PreviousMacroBlock
    topBorderY, leftBorderY: seq[uint8]
    topBorderU, leftBorderU: seq[uint8]
    topBorderV, leftBorderV: seq[uint8]

when defined(release):
  {.push checks: off.}

{.push raises: [PixieError].}

template failInvalid(reason = "unable to load") =
  raise newException(PixieError, "Invalid WebP, " & reason)

const
  HuffmanCodesPerMetaCode = 5
  CodeLengthCodes = 19
  MaxAllowedCodeLength = 15
  MaxTableBits = 10
  AlphabetSize = [uint16(256 + 24), 256, 256, 256, 40]
  CodeLengthCodeOrder = [
    17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
  ]
  DistanceMap = [
    (0, 1), (1, 0), (1, 1), (-1, 1), (0, 2), (2, 0), (1, 2), (-1, 2),
    (2, 1), (-2, 1), (2, 2), (-2, 2), (0, 3), (3, 0), (1, 3), (-1, 3),
    (3, 1), (-3, 1), (2, 3), (-2, 3), (3, 2), (-3, 2), (0, 4), (4, 0),
    (1, 4), (-1, 4), (4, 1), (-4, 1), (3, 3), (-3, 3), (2, 4), (-2, 4),
    (4, 2), (-4, 2), (0, 5), (3, 4), (-3, 4), (4, 3), (-4, 3), (5, 0),
    (1, 5), (-1, 5), (5, 1), (-5, 1), (2, 5), (-2, 5), (5, 2), (-5, 2),
    (4, 4), (-4, 4), (3, 5), (-3, 5), (5, 3), (-5, 3), (0, 6), (6, 0),
    (1, 6), (-1, 6), (6, 1), (-6, 1), (2, 6), (-2, 6), (6, 2), (-6, 2),
    (4, 5), (-4, 5), (5, 4), (-5, 4), (3, 6), (-3, 6), (6, 3), (-6, 3),
    (0, 7), (7, 0), (1, 7), (-1, 7), (5, 5), (-5, 5), (7, 1), (-7, 1),
    (4, 6), (-4, 6), (6, 4), (-6, 4), (2, 7), (-2, 7), (7, 2), (-7, 2),
    (3, 7), (-3, 7), (7, 3), (-7, 3), (5, 6), (-5, 6), (6, 5), (-6, 5),
    (8, 0), (4, 7), (-4, 7), (7, 4), (-7, 4), (8, 1), (8, 2), (6, 6),
    (-6, 6), (8, 3), (5, 7), (-5, 7), (7, 5), (-7, 5), (8, 4), (6, 7),
    (-6, 7), (7, 6), (-7, 6), (8, 5), (7, 7), (-7, 7), (8, 6), (8, 7)
  ]

const
  Vp8DcPred = 0
  Vp8VPred = 1
  Vp8HPred = 2
  Vp8TmPred = 3
  Vp8BPred = 4

  Vp8BDcPred = 0
  Vp8BTmPred = 1
  Vp8BVePred = 2
  Vp8BHePred = 3
  Vp8BLdPred = 4
  Vp8BRdPred = 5
  Vp8BVrPred = 6
  Vp8BVlPred = 7
  Vp8BHdPred = 8
  Vp8BHuPred = 9

  Vp8Dct0 = 0
  Vp8Dct1 = 1
  Vp8Dct4 = 4
  Vp8DctCat1 = 5
  Vp8DctCat6 = 10
  Vp8DctEob = 11

proc checkBounds(data: string, pos, len: int) {.inline.} =
  if pos < 0 or len < 0 or pos > data.len or len > data.len - pos:
    failInvalid("truncated chunk")

proc readStrChecked(data: string, pos, len: int): string {.inline.} =
  data.checkBounds(pos, len)
  data.readStr(pos, len)

proc readUint8Checked(data: string, pos: int): uint8 {.inline.} =
  data.checkBounds(pos, 1)
  data.readUint8(pos)

proc readUint16le(data: string, pos: int): int {.inline.} =
  data.checkBounds(pos, 2)
  data.readUint16(pos).int

proc readUint24le(data: string, pos: int): int {.inline.} =
  data.checkBounds(pos, 3)
  data.readUint8(pos + 0).int or
    (data.readUint8(pos + 1).int shl 8) or
    (data.readUint8(pos + 2).int shl 16)

proc readUint32le(data: string, pos: int): uint32 {.inline.} =
  data.checkBounds(pos, 4)
  data.readUint32(pos)

proc chunkKind(fourcc: string): WebpChunkKind {.inline.} =
  case fourcc
  of WebpVp8Signature: Vp8Chunk
  of WebpVp8LSignature: Vp8LChunk
  of WebpVp8XSignature: Vp8XChunk
  of WebpAlphaSignature: AlphaChunk
  of WebpAnimSignature: AnimChunk
  of WebpAnimFrameSignature: AnimFrameChunk
  of WebpIccpSignature: IccpChunk
  of WebpExifSignature: ExifChunk
  of WebpXmpSignature: XmpChunk
  else: UnknownWebpChunk

proc checkImageSize(width, height: int) =
  if width <= 0 or height <= 0:
    failInvalid("invalid dimensions")
  if width.int64 * height.int64 > uint32.high.int64:
    failInvalid("image is too large")

proc wrapByte(value: int): uint8 {.inline.} =
  (value and 0xff).uint8

proc subsampleSize(size, bits: int): int {.inline.} =
  (size + (1 shl bits) - 1) shr bits

proc newBitReader(data: string, offset, size: int): LosslessBitReader =
  data.checkBounds(offset, size)
  LosslessBitReader(data: data, pos: offset, endPos: offset + size)

proc fill(bitReader: LosslessBitReader) =
  while bitReader.nbits <= 56 and bitReader.pos < bitReader.endPos:
    bitReader.buffer = bitReader.buffer or
      (bitReader.data.readUint8(bitReader.pos).uint64 shl bitReader.nbits)
    bitReader.nbits += 8
    inc bitReader.pos

proc peek(bitReader: LosslessBitReader, bits: int): uint64 {.inline.} =
  if bits == 0:
    0
  else:
    bitReader.buffer and ((1'u64 shl bits) - 1)

proc consume(bitReader: LosslessBitReader, bits: int) =
  if bitReader.nbits < bits:
    failInvalid("corrupt VP8L bitstream")
  bitReader.buffer = bitReader.buffer shr bits
  bitReader.nbits -= bits

proc readBits(bitReader: LosslessBitReader, bits: int): uint32 =
  if bitReader.nbits < bits:
    bitReader.fill()
  result = bitReader.peek(bits).uint32
  bitReader.consume(bits)

proc nextCodeword(codeword, tableSize: uint16): uint16 =
  if codeword == tableSize - 1:
    return codeword

  var adv = 0
  let diff = codeword xor (tableSize - 1)
  for bit in countdown(15, 0):
    if (diff and (1'u16 shl bit)) != 0:
      adv = bit
      break

  let mask = 1'u16 shl adv
  return (codeword and (mask - 1)) or mask

proc buildSingleNode(symbol: uint16): HuffmanTree =
  HuffmanTree(single: true, symbol: symbol)

proc buildTwoNode(zero, one: uint16): HuffmanTree =
  HuffmanTree(
    tableMask: 1,
    primaryTable: @[(1'u16 shl 12) or zero, (1'u16 shl 12) or one]
  )

proc buildImplicit(codeLengths: seq[uint16]): HuffmanTree =
  var
    numSymbols = 0
    histogram: array[MaxAllowedCodeLength + 1, int]

  for length in codeLengths:
    if length.int > MaxAllowedCodeLength:
      failInvalid("invalid VP8L Huffman code")
    inc histogram[length.int]
    if length != 0:
      inc numSymbols

  if numSymbols == 0:
    failInvalid("invalid VP8L Huffman code")
  if numSymbols == 1:
    for symbol, length in codeLengths:
      if length != 0:
        return buildSingleNode(symbol.uint16)

  var maxLength = MaxAllowedCodeLength
  while maxLength > 1 and histogram[maxLength] == 0:
    dec maxLength

  var
    offsets: array[MaxAllowedCodeLength + 1, int]
    codespaceUsed = 0
  offsets[1] = histogram[0]
  for i in 1 ..< maxLength:
    offsets[i + 1] = offsets[i] + histogram[i]
    codespaceUsed = (codespaceUsed shl 1) + histogram[i]
  codespaceUsed = (codespaceUsed shl 1) + histogram[maxLength]
  if codespaceUsed != (1 shl maxLength):
    failInvalid("invalid VP8L Huffman code")

  let
    tableBits = min(maxLength, MaxTableBits)
    tableSize = 1 shl tableBits
  result = HuffmanTree()
  result.tableMask = (tableSize - 1).uint16
  result.primaryTable.setLen(tableSize)

  var
    nextIndex = offsets
    sortedSymbols = newSeq[uint16](codeLengths.len)
  for symbol, length in codeLengths:
    sortedSymbols[nextIndex[length.int]] = symbol.uint16
    inc nextIndex[length.int]

  var
    codeword = 0.uint16
    i = histogram[0]

  let primaryTableBits = tableBits
  for length in 1 .. primaryTableBits:
    let currentTableEnd = 1 shl length
    for _ in 0 ..< histogram[length]:
      let symbol = sortedSymbols[i]
      inc i
      result.primaryTable[codeword.int] = (length.uint16 shl 12) or symbol
      codeword = nextCodeword(codeword, currentTableEnd.uint16)

    if length < primaryTableBits:
      for j in 0 ..< currentTableEnd:
        result.primaryTable[currentTableEnd + j] = result.primaryTable[j]

  if maxLength > primaryTableBits:
    var
      subtableStart = 0
      subtablePrefix = -1
    let primaryTableMask = (1 shl primaryTableBits) - 1

    for length in (primaryTableBits + 1) .. maxLength:
      let subtableSize = 1 shl (length - primaryTableBits)
      for _ in 0 ..< histogram[length]:
        let prefix = codeword.int and primaryTableMask
        if prefix != subtablePrefix:
          subtablePrefix = prefix
          subtableStart = result.secondaryTable.len
          result.primaryTable[prefix] = (length.uint16 shl 12) or
            subtableStart.uint16
          result.secondaryTable.setLen(subtableStart + subtableSize)

        let symbol = sortedSymbols[i]
        inc i
        result.secondaryTable[
          subtableStart + (codeword.int shr primaryTableBits)
        ] = (symbol shl 4) or length.uint16
        codeword = nextCodeword(codeword, (1 shl length).uint16)

      if length < maxLength and
          (codeword.int and primaryTableMask) == subtablePrefix:
        let oldLen = result.secondaryTable.len
        result.secondaryTable.setLen(oldLen + oldLen - subtableStart)
        for j in subtableStart ..< oldLen:
          result.secondaryTable[oldLen + j - subtableStart] =
            result.secondaryTable[j]
        result.primaryTable[subtablePrefix] =
          ((length + 1).uint16 shl 12) or subtableStart.uint16

proc readSymbol(tree: HuffmanTree, bitReader: LosslessBitReader): uint16 =
  if tree.single:
    return tree.symbol

  bitReader.fill()
  let
    v = bitReader.buffer.uint16
    entry = tree.primaryTable[(v and tree.tableMask).int]
    length = (entry shr 12).int

  if length <= MaxTableBits:
    bitReader.consume(length)
    return entry and 0x0fff

  let
    mask = (1 shl (length - MaxTableBits)) - 1
    secondaryIndex = (entry and 0x0fff).int +
      ((v.int shr MaxTableBits) and mask)
    secondaryEntry = tree.secondaryTable[secondaryIndex]
  bitReader.consume((secondaryEntry and 0x000f).int)
  secondaryEntry shr 4

proc peekSymbol(
  tree: HuffmanTree, bitReader: LosslessBitReader, bits: var int,
  symbol: var uint16
): bool =
  if tree.single:
    bits = 0
    symbol = tree.symbol
    return true

  bitReader.fill()
  let
    v = bitReader.buffer.uint16
    entry = tree.primaryTable[(v and tree.tableMask).int]
    length = (entry shr 12).int
  if length <= MaxTableBits:
    bits = length
    symbol = entry and 0x0fff
    return true

proc insert(colorCache: ColorCache, color: array[4, uint8]) =
  let colorU32 =
    (color[0].uint32 shl 16) or
    (color[1].uint32 shl 8) or
    color[2].uint32 or
    (color[3].uint32 shl 24)
  let index = (
    0x1e35a7bd'u32 * colorU32
  ) shr (32 - colorCache.bits)
  colorCache.colors[index.int] = color

proc lookup(colorCache: ColorCache, index: int): array[4, uint8] =
  if index < 0 or index >= colorCache.colors.len:
    failInvalid("corrupt VP8L color cache")
  colorCache.colors[index]

proc getCopyDistance(
  bitReader: LosslessBitReader,
  prefixCode: uint16
): int =
  if prefixCode < 4:
    return prefixCode.int + 1
  let
    extraBits = ((prefixCode - 2) shr 1).int
    offset = (2 + (prefixCode.int and 1)) shl extraBits
    bits = bitReader.peek(extraBits).int
  bitReader.consume(extraBits)
  offset + bits + 1

proc planeCodeToDistance(xsize, planeCode: int): int =
  if planeCode > 120:
    return planeCode - 120

  let (xoffset, yoffset) = DistanceMap[planeCode - 1]
  return max(1, xoffset + yoffset * xsize)

proc getHuffIndex(info: HuffmanInfo, x, y: int): int =
  if info.bits == 0:
    return 0
  let position = (y shr info.bits) * info.xsize + (x shr info.bits)
  if position < 0 or position >= info.image.len:
    failInvalid("corrupt VP8L meta Huffman image")
  info.image[position].int

proc readHuffmanCodeLengths(
  decoder: LosslessDecoder, codeLengthCodeLengths: seq[uint16],
  numSymbols: uint16
): seq[uint16] =
  let table = buildImplicit(codeLengthCodeLengths)

  var maxSymbol =
    if decoder.bitReader.readBits(1) == 1:
      let
        lengthNBits = 2 + 2 * decoder.bitReader.readBits(3).int
        maxMinusTwo = decoder.bitReader.readBits(lengthNBits).uint16
      if maxMinusTwo > numSymbols - 2:
        failInvalid("corrupt VP8L Huffman lengths")
      2 + maxMinusTwo.int
    else:
      numSymbols.int

  result = newSeq[uint16](numSymbols.int)
  var
    prevCodeLen = 8.uint16
    symbol = 0
  while symbol < numSymbols.int:
    if maxSymbol == 0:
      break
    dec maxSymbol

    decoder.bitReader.fill()
    let codeLen = table.readSymbol(decoder.bitReader)

    if codeLen < 16:
      result[symbol] = codeLen
      inc symbol
      if codeLen != 0:
        prevCodeLen = codeLen
    else:
      let
        usePrev = codeLen == 16
        slot = codeLen - 16
      var
        extraBits: int
        repeatOffset: int
      case slot
      of 0:
        extraBits = 2
        repeatOffset = 3
      of 1:
        extraBits = 3
        repeatOffset = 3
      of 2:
        extraBits = 7
        repeatOffset = 11
      else:
        failInvalid("corrupt VP8L Huffman lengths")
      var repeat = decoder.bitReader.readBits(extraBits).int + repeatOffset
      if symbol + repeat > numSymbols.int:
        failInvalid("corrupt VP8L Huffman lengths")
      let length = if usePrev: prevCodeLen else: 0.uint16
      while repeat > 0:
        result[symbol] = length
        inc symbol
        dec repeat

proc readHuffmanCode(
  decoder: LosslessDecoder, alphabetSize: uint16
): HuffmanTree =
  let simple = decoder.bitReader.readBits(1) == 1

  if simple:
    let
      numSymbols = decoder.bitReader.readBits(1).int + 1
      isFirst8Bits = decoder.bitReader.readBits(1).int
      zeroSymbol = decoder.bitReader.readBits(1 + 7 * isFirst8Bits).uint16
    if zeroSymbol >= alphabetSize:
      failInvalid("corrupt VP8L Huffman symbol")
    if numSymbols == 1:
      result = buildSingleNode(zeroSymbol)
    else:
      let oneSymbol = decoder.bitReader.readBits(8).uint16
      if oneSymbol >= alphabetSize:
        failInvalid("corrupt VP8L Huffman symbol")
      result = buildTwoNode(zeroSymbol, oneSymbol)
  else:
    var codeLengthCodeLengths = newSeq[uint16](CodeLengthCodes)
    let numCodeLengths = 4 + decoder.bitReader.readBits(4).int
    for i in 0 ..< numCodeLengths:
      codeLengthCodeLengths[CodeLengthCodeOrder[i]] =
        decoder.bitReader.readBits(3).uint16

    result = buildImplicit(
      decoder.readHuffmanCodeLengths(codeLengthCodeLengths, alphabetSize)
    )

proc decodeImageData(
  decoder: LosslessDecoder, width, height: int,
  huffmanInfo: HuffmanInfo,
  data: var seq[uint8]
) =
  let numValues = width * height
  var
    index = 0
    nextBlockStart = 0
    tree = huffmanInfo.groups[huffmanInfo.getHuffIndex(0, 0)]

  while index < numValues:
    decoder.bitReader.fill()

    if index >= nextBlockStart:
      let
        x = index mod width
        y = index div width
      nextBlockStart = min((x or huffmanInfo.mask), width - 1) + y * width + 1
      tree = huffmanInfo.groups[huffmanInfo.getHuffIndex(x, y)]

      if tree[0].single and tree[1].single and tree[2].single and tree[3].single:
        let code = tree[0].readSymbol(decoder.bitReader)
        if code < 256:
          let
            n = if huffmanInfo.bits == 0: numValues else: nextBlockStart - index
            value = [
              tree[1].readSymbol(decoder.bitReader).uint8,
              code.uint8,
              tree[2].readSymbol(decoder.bitReader).uint8,
              tree[3].readSymbol(decoder.bitReader).uint8
            ]
          for i in 0 ..< n:
            let dst = (index + i) * 4
            data[dst + 0] = value[0]
            data[dst + 1] = value[1]
            data[dst + 2] = value[2]
            data[dst + 3] = value[3]
          if huffmanInfo.hasColorCache:
            huffmanInfo.colorCache.insert(value)
          index += n
          continue

    let code = tree[0].readSymbol(decoder.bitReader)
    if code < 256:
      let
        green = code.uint8
        red = tree[1].readSymbol(decoder.bitReader).uint8
        blue = tree[2].readSymbol(decoder.bitReader).uint8
        alpha = tree[3].readSymbol(decoder.bitReader).uint8
        dst = index * 4
      data[dst + 0] = red
      data[dst + 1] = green
      data[dst + 2] = blue
      data[dst + 3] = alpha
      if huffmanInfo.hasColorCache:
        huffmanInfo.colorCache.insert([red, green, blue, alpha])
      inc index
    elif code < 256 + 24:
      let
        length = getCopyDistance(decoder.bitReader, code - 256)
        distSymbol = tree[4].readSymbol(decoder.bitReader)
        distCode = getCopyDistance(decoder.bitReader, distSymbol)
        dist = planeCodeToDistance(width, distCode)
      if index < dist or numValues - index < length:
        failInvalid("corrupt VP8L back reference")
      for i in 0 ..< length:
        let
          src = (index - dist + i) * 4
          dst = (index + i) * 4
        data[dst + 0] = data[src + 0]
        data[dst + 1] = data[src + 1]
        data[dst + 2] = data[src + 2]
        data[dst + 3] = data[src + 3]
        if huffmanInfo.hasColorCache:
          huffmanInfo.colorCache.insert([
            data[dst + 0], data[dst + 1], data[dst + 2], data[dst + 3]
          ])
      index += length
    else:
      if not huffmanInfo.hasColorCache:
        failInvalid("missing VP8L color cache")
      let
        color = huffmanInfo.colorCache.lookup((code - 280).int)
        dst = index * 4
      data[dst + 0] = color[0]
      data[dst + 1] = color[1]
      data[dst + 2] = color[2]
      data[dst + 3] = color[3]
      inc index

      var
        bits: int
        nextCode: uint16
      if index < nextBlockStart and tree[0].peekSymbol(
        decoder.bitReader, bits, nextCode
      ) and nextCode >= 280:
        decoder.bitReader.consume(bits)
        let
          nextColor = huffmanInfo.colorCache.lookup((nextCode - 280).int)
          nextDst = index * 4
        data[nextDst + 0] = nextColor[0]
        data[nextDst + 1] = nextColor[1]
        data[nextDst + 2] = nextColor[2]
        data[nextDst + 3] = nextColor[3]
        inc index

proc decodeImageStream(
  decoder: LosslessDecoder, xsize, ysize: int, readMeta: bool,
  data: var seq[uint8]
) =
  var
    colorCache: ColorCache
    hasColorCache: bool
    numHuffGroups = 1
    huffmanBits = 0
    huffmanXSize = 1
    huffmanYSize = 1
    entropyImage: seq[uint16]
  if decoder.bitReader.readBits(1) == 1:
    let bits = decoder.bitReader.readBits(4).int
    if bits notin 1 .. 11:
      failInvalid("invalid VP8L color cache")
    hasColorCache = true
    colorCache = ColorCache(
      bits: bits,
      colors: newSeq[array[4, uint8]](1 shl bits)
    )

  if readMeta and decoder.bitReader.readBits(1) == 1:
    huffmanBits = decoder.bitReader.readBits(3).int + 2
    huffmanXSize = subsampleSize(xsize, huffmanBits)
    huffmanYSize = subsampleSize(ysize, huffmanBits)
    var metaData = newSeq[uint8](huffmanXSize * huffmanYSize * 4)
    decoder.decodeImageStream(huffmanXSize, huffmanYSize, false, metaData)

    entropyImage.setLen(huffmanXSize * huffmanYSize)
    for i in 0 ..< entropyImage.len:
      let metaHuffCode =
        (metaData[i * 4].uint16 shl 8) or metaData[i * 4 + 1].uint16
      entropyImage[i] = metaHuffCode
      numHuffGroups = max(numHuffGroups, metaHuffCode.int + 1)

  let huffmanInfo = HuffmanInfo(
    xsize: huffmanXSize,
    colorCache: colorCache,
    hasColorCache: hasColorCache,
    image: entropyImage,
    bits: huffmanBits,
    mask: if huffmanBits == 0: int.high else: (1 shl huffmanBits) - 1
  )
  huffmanInfo.groups.setLen(numHuffGroups)

  for groupIndex in 0 ..< numHuffGroups:
    for j in 0 ..< HuffmanCodesPerMetaCode:
      var size = AlphabetSize[j]
      if j == 0 and hasColorCache:
        size += (1 shl colorCache.bits).uint16
      huffmanInfo.groups[groupIndex][j] = decoder.readHuffmanCode(size)

  decoder.decodeImageData(xsize, ysize, huffmanInfo, data)

proc readTransforms(decoder: LosslessDecoder): int =
  result = decoder.width

  while decoder.bitReader.readBits(1) == 1:
    let transformType = decoder.bitReader.readBits(2).int
    if decoder.hasTransform[transformType]:
      failInvalid("duplicate VP8L transform")
    decoder.transformOrder.add(transformType)

    case transformType
    of 0:
      let
        sizeBits = decoder.bitReader.readBits(3).int + 2
        blockXSize = subsampleSize(result, sizeBits)
        blockYSize = subsampleSize(decoder.height, sizeBits)
      var predictorData = newSeq[uint8](blockXSize * blockYSize * 4)
      decoder.decodeImageStream(blockXSize, blockYSize, false, predictorData)
      decoder.transforms[transformType] = LosslessTransform(
        kind: PredictorTransform,
        sizeBits: sizeBits,
        data: predictorData
      )
    of 1:
      let
        sizeBits = decoder.bitReader.readBits(3).int + 2
        blockXSize = subsampleSize(result, sizeBits)
        blockYSize = subsampleSize(decoder.height, sizeBits)
      var transformData = newSeq[uint8](blockXSize * blockYSize * 4)
      decoder.decodeImageStream(blockXSize, blockYSize, false, transformData)
      decoder.transforms[transformType] = LosslessTransform(
        kind: ColorTransform,
        sizeBits: sizeBits,
        data: transformData
      )
    of 2:
      decoder.transforms[transformType] = LosslessTransform(
        kind: SubtractGreenTransform
      )
    of 3:
      let colorTableSize = decoder.bitReader.readBits(8).int + 1
      var colorMap = newSeq[uint8](colorTableSize * 4)
      decoder.decodeImageStream(colorTableSize, 1, false, colorMap)
      for i in 4 ..< colorMap.len:
        colorMap[i] = wrapByte(colorMap[i].int + colorMap[i - 4].int)

      let widthBits =
        if colorTableSize <= 2: 3
        elif colorTableSize <= 4: 2
        elif colorTableSize <= 16: 1
        else: 0
      result = subsampleSize(result, widthBits)
      decoder.transforms[transformType] = LosslessTransform(
        kind: ColorIndexingTransform,
        tableSize: colorTableSize,
        data: colorMap
      )
    else:
      failInvalid("invalid VP8L transform")

    decoder.hasTransform[transformType] = true

proc avg2(a, b: uint8): uint8 {.inline.} =
  ((a.uint16 + b.uint16) div 2).uint8

proc clampByte(value: int): uint8 {.inline.} =
  min(max(value, 0), 255).uint8

proc pixelAt(data: seq[uint8], width, x, y: int): array[4, uint8] {.inline.} =
  let offset = (y * width + x) * 4
  [data[offset + 0], data[offset + 1], data[offset + 2], data[offset + 3]]

proc addPredictor(data: var seq[uint8], offset: int, pred: array[4, uint8]) =
  data[offset + 0] = wrapByte(data[offset + 0].int + pred[0].int)
  data[offset + 1] = wrapByte(data[offset + 1].int + pred[1].int)
  data[offset + 2] = wrapByte(data[offset + 2].int + pred[2].int)
  data[offset + 3] = wrapByte(data[offset + 3].int + pred[3].int)

proc predictor(
  data: seq[uint8], width, height, x, y, mode: int
): array[4, uint8] =
  if x == 0 and y == 0:
    return [0'u8, 0, 0, 255]
  if y == 0:
    return data.pixelAt(width, x - 1, y)
  if x == 0:
    return data.pixelAt(width, x, y - 1)

  let
    left = data.pixelAt(width, x - 1, y)
    top = data.pixelAt(width, x, y - 1)
    topLeft = data.pixelAt(width, x - 1, y - 1)
    topRight =
      if x == width - 1: data.pixelAt(width, 0, y)
      else: data.pixelAt(width, x + 1, y - 1)

  case mode
  of 0:
    [0'u8, 0, 0, 255]
  of 1:
    left
  of 2:
    top
  of 3:
    topRight
  of 4:
    topLeft
  of 5:
    [
      avg2(avg2(left[0], topRight[0]), top[0]),
      avg2(avg2(left[1], topRight[1]), top[1]),
      avg2(avg2(left[2], topRight[2]), top[2]),
      avg2(avg2(left[3], topRight[3]), top[3])
    ]
  of 6:
    [avg2(left[0], topLeft[0]), avg2(left[1], topLeft[1]),
      avg2(left[2], topLeft[2]), avg2(left[3], topLeft[3])]
  of 7:
    [avg2(left[0], top[0]), avg2(left[1], top[1]),
      avg2(left[2], top[2]), avg2(left[3], top[3])]
  of 8:
    [avg2(topLeft[0], top[0]), avg2(topLeft[1], top[1]),
      avg2(topLeft[2], top[2]), avg2(topLeft[3], top[3])]
  of 9:
    [avg2(top[0], topRight[0]), avg2(top[1], topRight[1]),
      avg2(top[2], topRight[2]), avg2(top[3], topRight[3])]
  of 10:
    [
      avg2(avg2(left[0], topLeft[0]), avg2(top[0], topRight[0])),
      avg2(avg2(left[1], topLeft[1]), avg2(top[1], topRight[1])),
      avg2(avg2(left[2], topLeft[2]), avg2(top[2], topRight[2])),
      avg2(avg2(left[3], topLeft[3]), avg2(top[3], topRight[3]))
    ]
  of 11:
    var
      predictLeft = 0
      predictTop = 0
    for i in 0 .. 3:
      let predict = left[i].int + top[i].int - topLeft[i].int
      predictLeft += abs(predict - left[i].int)
      predictTop += abs(predict - top[i].int)
    if predictLeft < predictTop: left else: top
  of 12:
    [
      clampByte(left[0].int + top[0].int - topLeft[0].int),
      clampByte(left[1].int + top[1].int - topLeft[1].int),
      clampByte(left[2].int + top[2].int - topLeft[2].int),
      clampByte(left[3].int + top[3].int - topLeft[3].int)
    ]
  of 13:
    var outp: array[4, uint8]
    for i in 0 .. 3:
      let avg = (left[i].int + top[i].int) div 2
      outp[i] = clampByte(avg + (avg - topLeft[i].int) div 2)
    outp
  else:
    [0'u8, 0, 0, 255]

proc applyPredictorTransform(
  data: var seq[uint8], width, height, sizeBits: int, predictorData: seq[uint8]
) =
  let blockXSize = subsampleSize(width, sizeBits)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let
        blockIndex = (y shr sizeBits) * blockXSize + (x shr sizeBits)
        mode =
          if x == 0 or y == 0: 0
          else: predictorData[blockIndex * 4 + 1].int
        offset = (y * width + x) * 4
        pred = predictor(data, width, height, x, y, mode)
      data.addPredictor(offset, pred)

proc signedByte(value: uint8): int {.inline.} =
  if value < 128: value.int else: value.int - 256

proc colorTransformDelta(t, c: uint8): int {.inline.} =
  (signedByte(t) * signedByte(c)) shr 5

proc applyColorTransform(
  data: var seq[uint8], width, height, sizeBits: int, transformData: seq[uint8]
) =
  let blockXSize = subsampleSize(width, sizeBits)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let
        transformOffset = ((y shr sizeBits) * blockXSize + (x shr sizeBits)) * 4
        redToBlue = transformData[transformOffset + 0]
        greenToBlue = transformData[transformOffset + 1]
        greenToRed = transformData[transformOffset + 2]
        offset = (y * width + x) * 4
        green = data[offset + 1]
      var
        red = data[offset + 0].int
        blue = data[offset + 2].int
      red += colorTransformDelta(greenToRed, green)
      blue += colorTransformDelta(greenToBlue, green)
      blue += colorTransformDelta(redToBlue, wrapByte(red))
      data[offset + 0] = wrapByte(red)
      data[offset + 2] = wrapByte(blue)

proc applySubtractGreenTransform(data: var seq[uint8], len: int) =
  for offset in countup(0, len - 1, 4):
    data[offset + 0] = wrapByte(data[offset + 0].int + data[offset + 1].int)
    data[offset + 2] = wrapByte(data[offset + 2].int + data[offset + 1].int)

proc applyColorIndexingTransform(
  data: var seq[uint8], width, height, tableSize: int, tableData: seq[uint8]
) =
  if tableSize <= 0:
    failInvalid("invalid VP8L color table")

  let widthBits =
    if tableSize <= 2: 3
    elif tableSize <= 4: 2
    elif tableSize <= 16: 1
    else: 0
  let
    packedWidth = subsampleSize(width, widthBits)
    pixelsPerPacked = 1 shl widthBits
    bitsPerEntry = 8 div pixelsPerPacked
    mask = (1 shl bitsPerEntry) - 1

  for y in countdown(height - 1, 0):
    for x in countdown(width - 1, 0):
      let
        packedX = x shr widthBits
        packedOffset = (y * packedWidth + packedX) * 4
        shift = (x and (pixelsPerPacked - 1)) * bitsPerEntry
        index = (data[packedOffset + 1].int shr shift) and mask
        dst = (y * width + x) * 4
      if index < tableSize:
        let src = index * 4
        data[dst + 0] = tableData[src + 0]
        data[dst + 1] = tableData[src + 1]
        data[dst + 2] = tableData[src + 2]
        data[dst + 3] = tableData[src + 3]
      else:
        data[dst + 0] = 0
        data[dst + 1] = 0
        data[dst + 2] = 0
        data[dst + 3] = 0

proc decodeLosslessData(
  data: string, offset, size, width, height: int, implicitDimensions: bool
): seq[uint8] =
  let decoder = LosslessDecoder(
    bitReader: newBitReader(data, offset, size),
    width: width,
    height: height
  )

  if not implicitDimensions:
    let signature = decoder.bitReader.readBits(8)
    if signature != 0x2f:
      failInvalid("invalid VP8L signature")
    decoder.width = decoder.bitReader.readBits(14).int + 1
    decoder.height = decoder.bitReader.readBits(14).int + 1
    if decoder.width != width or decoder.height != height:
      failInvalid("inconsistent VP8L dimensions")
    discard decoder.bitReader.readBits(1) # alpha_is_used
    let version = decoder.bitReader.readBits(3)
    if version != 0:
      failInvalid("invalid VP8L version")

  let
    transformedWidth = decoder.readTransforms()
    finalSize = decoder.width * decoder.height * 4
    transformedSize = transformedWidth * decoder.height * 4
  result = newSeq[uint8](finalSize)
  decoder.decodeImageStream(
    transformedWidth, decoder.height, true, result
  )
  result.setLen(transformedSize)

  var
    imageSize = transformedSize
    currentWidth = transformedWidth
  if decoder.transformOrder.len > 0:
    for i in countdown(decoder.transformOrder.high, 0):
      let transform = decoder.transforms[decoder.transformOrder[i]]
      case transform.kind
      of PredictorTransform:
        applyPredictorTransform(
          result, currentWidth, decoder.height, transform.sizeBits, transform.data
        )
      of ColorTransform:
        applyColorTransform(
          result, currentWidth, decoder.height, transform.sizeBits, transform.data
        )
      of SubtractGreenTransform:
        applySubtractGreenTransform(result, imageSize)
      of ColorIndexingTransform:
        currentWidth = decoder.width
        imageSize = finalSize
        result.setLen(finalSize)
        applyColorIndexingTransform(
          result, currentWidth, decoder.height, transform.tableSize, transform.data
        )

  result.setLen(finalSize)

proc newImageFromRgbaBytes(data: seq[uint8], width, height: int): Image =
  result = newImage(width, height)
  for i in 0 ..< width * height:
    result.data[i] = rgba(
      data[i * 4 + 0],
      data[i * 4 + 1],
      data[i * 4 + 2],
      data[i * 4 + 3]
    ).rgbx()

proc newVp8BoolDecoder(data: string, offset, size: int): Vp8BoolDecoder =
  data.checkBounds(offset, size)
  Vp8BoolDecoder(
    data: data,
    pos: offset,
    endPos: offset + size,
    range: 255,
    bitCount: -8
  )

proc loadByte(decoder: Vp8BoolDecoder) =
  if decoder.pos < decoder.endPos:
    decoder.value = (decoder.value shl 8) or
      decoder.data.readUint8(decoder.pos).uint64
    inc decoder.pos
    decoder.bitCount += 8
  elif not decoder.zeroByteAfterEof:
    decoder.value = decoder.value shl 8
    decoder.bitCount += 8
    decoder.zeroByteAfterEof = true
  else:
    failInvalid("truncated VP8 bitstream")

proc readBool(decoder: Vp8BoolDecoder, probability: uint8): bool =
  if decoder.bitCount < 0:
    decoder.loadByte()

  let
    split = 1'u32 + (((decoder.range - 1) * probability.uint32) shr 8)
    bigSplit = split.uint64 shl decoder.bitCount

  if decoder.value >= bigSplit:
    decoder.range -= split
    decoder.value -= bigSplit
    result = true
  else:
    decoder.range = split

  if decoder.range == 0:
    failInvalid("corrupt VP8 bitstream")

  while decoder.range < 128:
    decoder.range = decoder.range shl 1
    dec decoder.bitCount

proc readFlag(decoder: Vp8BoolDecoder): bool {.inline.} =
  decoder.readBool(128)

proc readLiteral(decoder: Vp8BoolDecoder, bits: int): uint8 =
  var value: uint8
  for _ in 0 ..< bits:
    value = (value shl 1) or decoder.readFlag().uint8
  return value

proc readOptionalSignedValue(decoder: Vp8BoolDecoder, bits: int): int =
  if not decoder.readFlag():
    return 0
  let value = decoder.readLiteral(bits).int
  if decoder.readFlag():
    return -value
  return value

proc readTree(
  decoder: Vp8BoolDecoder,
  tree: openArray[int],
  probabilities: openArray[uint8],
  start = 0
): int =
  var index = start
  while true:
    if index < 0 or index >= probabilities.len or index * 2 + 1 >= tree.len:
      failInvalid("invalid VP8 probability tree")
    let branch =
      if decoder.readBool(probabilities[index]): tree[index * 2 + 1]
      else: tree[index * 2]
    if branch <= 0:
      return -branch
    index = branch div 2

proc vp8ClampByte(value: int): uint8 {.inline.} =
  if value <= 0:
    0
  elif value >= 255:
    255
  else:
    value.uint8

proc idct4x4(coeffs: var array[16, int]) =
  const
    Const1 = 20091
    Const2 = 35468

  for i in 0 ..< 4:
    let
      a1 = coeffs[i] + coeffs[8 + i]
      b1 = coeffs[i] - coeffs[8 + i]
      t1 = (coeffs[4 + i] * Const2) shr 16
      t2 = coeffs[12 + i] + ((coeffs[12 + i] * Const1) shr 16)
      c1 = t1 - t2
      t3 = coeffs[4 + i] + ((coeffs[4 + i] * Const1) shr 16)
      t4 = (coeffs[12 + i] * Const2) shr 16
      d1 = t3 + t4
    coeffs[i] = a1 + d1
    coeffs[4 + i] = b1 + c1
    coeffs[12 + i] = a1 - d1
    coeffs[8 + i] = b1 - c1

  for i in 0 ..< 4:
    let
      a1 = coeffs[4 * i] + coeffs[4 * i + 2]
      b1 = coeffs[4 * i] - coeffs[4 * i + 2]
      t1 = (coeffs[4 * i + 1] * Const2) shr 16
      t2 = coeffs[4 * i + 3] + ((coeffs[4 * i + 3] * Const1) shr 16)
      c1 = t1 - t2
      t3 = coeffs[4 * i + 1] + ((coeffs[4 * i + 1] * Const1) shr 16)
      t4 = (coeffs[4 * i + 3] * Const2) shr 16
      d1 = t3 + t4
    coeffs[4 * i] = (a1 + d1 + 4) shr 3
    coeffs[4 * i + 3] = (a1 - d1 + 4) shr 3
    coeffs[4 * i + 1] = (b1 + c1 + 4) shr 3
    coeffs[4 * i + 2] = (b1 - c1 + 4) shr 3

proc iwht4x4(coeffs: var array[16, int]) =
  for i in 0 ..< 4:
    let
      a1 = coeffs[i] + coeffs[12 + i]
      b1 = coeffs[4 + i] + coeffs[8 + i]
      c1 = coeffs[4 + i] - coeffs[8 + i]
      d1 = coeffs[i] - coeffs[12 + i]
    coeffs[i] = a1 + b1
    coeffs[4 + i] = c1 + d1
    coeffs[8 + i] = a1 - b1
    coeffs[12 + i] = d1 - c1

  for y in 0 ..< 4:
    let
      pos = y * 4
      a1 = coeffs[pos] + coeffs[pos + 3]
      b1 = coeffs[pos + 1] + coeffs[pos + 2]
      c1 = coeffs[pos + 1] - coeffs[pos + 2]
      d1 = coeffs[pos] - coeffs[pos + 3]
      a2 = a1 + b1
      b2 = c1 + d1
      c2 = a1 - b1
      d2 = d1 - c1
    coeffs[pos] = (a2 + 3) shr 3
    coeffs[pos + 1] = (b2 + 3) shr 3
    coeffs[pos + 2] = (c2 + 3) shr 3
    coeffs[pos + 3] = (d2 + 3) shr 3

const
  Vp8LumaStride = 21
  Vp8LumaBlockSize = 21 * 17
  Vp8ChromaStride = 9
  Vp8ChromaBlockSize = 9 * 9

proc createBorderLuma(
  mbx, mby, mbWidth: int, top, left: seq[uint8]
): array[Vp8LumaBlockSize, uint8] =
  if mby == 0:
    for x in 1 ..< Vp8LumaStride:
      result[x] = 127
  else:
    for x in 0 ..< 16:
      result[1 + x] = top[mbx * 16 + x]
    for x in 0 ..< 4:
      result[17 + x] =
        if mbx == mbWidth - 1: top[mbx * 16 + 15]
        else: top[mbx * 16 + 16 + x]

  for i in 17 ..< Vp8LumaStride:
    result[4 * Vp8LumaStride + i] = result[i]
    result[8 * Vp8LumaStride + i] = result[i]
    result[12 * Vp8LumaStride + i] = result[i]

  if mbx == 0:
    for y in 0 ..< 16:
      result[(y + 1) * Vp8LumaStride] = 129
  else:
    for y in 0 ..< 16:
      result[(y + 1) * Vp8LumaStride] = left[1 + y]

  result[0] =
    if mby == 0: 127
    elif mbx == 0: 129
    else: left[0]

proc createBorderChroma(
  mbx, mby: int, top, left: seq[uint8]
): array[Vp8ChromaBlockSize, uint8] =
  if mby == 0:
    for x in 1 ..< Vp8ChromaStride:
      result[x] = 127
  else:
    for x in 0 ..< 8:
      result[1 + x] = top[mbx * 8 + x]

  if mbx == 0:
    for y in 0 ..< 8:
      result[(y + 1) * Vp8ChromaStride] = 129
  else:
    for y in 0 ..< 8:
      result[(y + 1) * Vp8ChromaStride] = left[1 + y]

  result[0] =
    if mby == 0: 127
    elif mbx == 0: 129
    else: left[0]

proc addResidue(
  pixels: var openArray[uint8],
  residue: openArray[int],
  blockStart, y0, x0, stride: int
) =
  var
    pos = y0 * stride + x0
    src = blockStart
  for _ in 0 ..< 4:
    for x in 0 ..< 4:
      pixels[pos + x] = vp8ClampByte(pixels[pos + x].int + residue[src + x])
    pos += stride
    src += 4

proc vp8Avg3(left, center, right: uint8): uint8 {.inline.} =
  ((left.uint16 + 2'u16 * center.uint16 + right.uint16 + 2) shr 2).uint8

proc vp8Avg2(center, right: uint8): uint8 {.inline.} =
  ((center.uint16 + right.uint16 + 1) shr 1).uint8

proc predictVpred(
  pixels: var openArray[uint8], size, x0, y0, stride: int
) =
  for y in 0 ..< size:
    for x in 0 ..< size:
      pixels[(y0 + y) * stride + x0 + x] =
        pixels[(y0 - 1) * stride + x0 + x]

proc predictHpred(
  pixels: var openArray[uint8], size, x0, y0, stride: int
) =
  for y in 0 ..< size:
    let left = pixels[(y0 + y) * stride + x0 - 1]
    for x in 0 ..< size:
      pixels[(y0 + y) * stride + x0 + x] = left

proc predictDcpred(
  pixels: var openArray[uint8], size, stride: int, above, left: bool
) =
  var
    sum = 0'u32
    shift = if size == 8: 2 else: 3

  if left:
    for y in 0 ..< size:
      sum += pixels[(y + 1) * stride].uint32
    inc shift

  if above:
    for x in 1 .. size:
      sum += pixels[x].uint32
    inc shift

  let dcValue =
    if not left and not above: 128.uint8
    else: ((sum + (1'u32 shl (shift - 1))) shr shift).uint8

  for y in 0 ..< size:
    for x in 0 ..< size:
      pixels[(y + 1) * stride + 1 + x] = dcValue

proc predictTmpred(
  pixels: var openArray[uint8], size, x0, y0, stride: int
) =
  let topLeft = pixels[(y0 - 1) * stride + x0 - 1].int
  for y in 0 ..< size:
    let leftMinusTopLeft = pixels[(y0 + y) * stride + x0 - 1].int - topLeft
    for x in 0 ..< size:
      pixels[(y0 + y) * stride + x0 + x] = vp8ClampByte(
        leftMinusTopLeft + pixels[(y0 - 1) * stride + x0 + x].int
      )

proc predictBDcpred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  var value = 4'u32
  for x in 0 ..< 4:
    value += pixels[(y0 - 1) * stride + x0 + x].uint32
  for y in 0 ..< 4:
    value += pixels[(y0 + y) * stride + x0 - 1].uint32
  value = value shr 3
  for y in 0 ..< 4:
    for x in 0 ..< 4:
      pixels[(y0 + y) * stride + x0 + x] = value.uint8

proc topPixel(
  pixels: openArray[uint8], x0, y0, stride, offset: int
): uint8 {.inline.} =
  pixels[(y0 - 1) * stride + x0 + offset]

proc leftPixel(
  pixels: openArray[uint8], x0, y0, stride, offset: int
): uint8 {.inline.} =
  pixels[(y0 + offset) * stride + x0 - 1]

proc edgePixel(
  pixels: openArray[uint8], x0, y0, stride, index: int
): uint8 =
  let pos = (y0 - 1) * stride + x0 - 1
  case index
  of 0: pixels[pos + 4 * stride]
  of 1: pixels[pos + 3 * stride]
  of 2: pixels[pos + 2 * stride]
  of 3: pixels[pos + stride]
  else: pixels[pos + index - 4]

proc predictBVePred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  let
    p = pixels[(y0 - 1) * stride + x0 - 1]
    a0 = topPixel(pixels, x0, y0, stride, 0)
    a1 = topPixel(pixels, x0, y0, stride, 1)
    a2 = topPixel(pixels, x0, y0, stride, 2)
    a3 = topPixel(pixels, x0, y0, stride, 3)
    a4 = topPixel(pixels, x0, y0, stride, 4)
    values = [
      vp8Avg3(p, a0, a1), vp8Avg3(a0, a1, a2),
      vp8Avg3(a1, a2, a3), vp8Avg3(a2, a3, a4)
    ]
  for y in 0 ..< 4:
    for x in 0 ..< 4:
      pixels[(y0 + y) * stride + x0 + x] = values[x]

proc predictBHePred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  let
    p = pixels[(y0 - 1) * stride + x0 - 1]
    l0 = leftPixel(pixels, x0, y0, stride, 0)
    l1 = leftPixel(pixels, x0, y0, stride, 1)
    l2 = leftPixel(pixels, x0, y0, stride, 2)
    l3 = leftPixel(pixels, x0, y0, stride, 3)
    values = [
      vp8Avg3(p, l0, l1), vp8Avg3(l0, l1, l2),
      vp8Avg3(l1, l2, l3), vp8Avg3(l2, l3, l3)
    ]
  for y in 0 ..< 4:
    for x in 0 ..< 4:
      pixels[(y0 + y) * stride + x0 + x] = values[y]

proc predictBLdPred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  var a: array[8, uint8]
  for i in 0 ..< 8:
    a[i] = topPixel(pixels, x0, y0, stride, i)
  let values = [
    vp8Avg3(a[0], a[1], a[2]), vp8Avg3(a[1], a[2], a[3]),
    vp8Avg3(a[2], a[3], a[4]), vp8Avg3(a[3], a[4], a[5]),
    vp8Avg3(a[4], a[5], a[6]), vp8Avg3(a[5], a[6], a[7]),
    vp8Avg3(a[6], a[7], a[7])
  ]
  for y in 0 ..< 4:
    for x in 0 ..< 4:
      pixels[(y0 + y) * stride + x0 + x] = values[y + x]

proc predictBRdPred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  var e: array[9, uint8]
  for i in 0 ..< 9:
    e[i] = edgePixel(pixels, x0, y0, stride, i)
  let values = [
    vp8Avg3(e[0], e[1], e[2]), vp8Avg3(e[1], e[2], e[3]),
    vp8Avg3(e[2], e[3], e[4]), vp8Avg3(e[3], e[4], e[5]),
    vp8Avg3(e[4], e[5], e[6]), vp8Avg3(e[5], e[6], e[7]),
    vp8Avg3(e[6], e[7], e[8])
  ]
  for y in 0 ..< 4:
    for x in 0 ..< 4:
      pixels[(y0 + y) * stride + x0 + x] = values[3 - y + x]

proc predictBVrPred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  var e: array[9, uint8]
  for i in 0 ..< 9:
    e[i] = edgePixel(pixels, x0, y0, stride, i)
  pixels[(y0 + 3) * stride + x0] = vp8Avg3(e[1], e[2], e[3])
  pixels[(y0 + 2) * stride + x0] = vp8Avg3(e[2], e[3], e[4])
  pixels[(y0 + 3) * stride + x0 + 1] = vp8Avg3(e[3], e[4], e[5])
  pixels[(y0 + 1) * stride + x0] = vp8Avg3(e[3], e[4], e[5])
  pixels[(y0 + 2) * stride + x0 + 1] = vp8Avg2(e[4], e[5])
  pixels[y0 * stride + x0] = vp8Avg2(e[4], e[5])
  pixels[(y0 + 3) * stride + x0 + 2] = vp8Avg3(e[4], e[5], e[6])
  pixels[(y0 + 1) * stride + x0 + 1] = vp8Avg3(e[4], e[5], e[6])
  pixels[(y0 + 2) * stride + x0 + 2] = vp8Avg2(e[5], e[6])
  pixels[y0 * stride + x0 + 1] = vp8Avg2(e[5], e[6])
  pixels[(y0 + 3) * stride + x0 + 3] = vp8Avg3(e[5], e[6], e[7])
  pixels[(y0 + 1) * stride + x0 + 2] = vp8Avg3(e[5], e[6], e[7])
  pixels[(y0 + 2) * stride + x0 + 3] = vp8Avg2(e[6], e[7])
  pixels[y0 * stride + x0 + 2] = vp8Avg2(e[6], e[7])
  pixels[(y0 + 1) * stride + x0 + 3] = vp8Avg3(e[6], e[7], e[8])
  pixels[y0 * stride + x0 + 3] = vp8Avg2(e[7], e[8])

proc predictBVlPred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  var a: array[8, uint8]
  for i in 0 ..< 8:
    a[i] = topPixel(pixels, x0, y0, stride, i)
  pixels[y0 * stride + x0] = vp8Avg2(a[0], a[1])
  pixels[(y0 + 1) * stride + x0] = vp8Avg3(a[0], a[1], a[2])
  pixels[(y0 + 2) * stride + x0] = vp8Avg2(a[1], a[2])
  pixels[y0 * stride + x0 + 1] = vp8Avg2(a[1], a[2])
  pixels[(y0 + 1) * stride + x0 + 1] = vp8Avg3(a[1], a[2], a[3])
  pixels[(y0 + 3) * stride + x0] = vp8Avg3(a[1], a[2], a[3])
  pixels[(y0 + 2) * stride + x0 + 1] = vp8Avg2(a[2], a[3])
  pixels[y0 * stride + x0 + 2] = vp8Avg2(a[2], a[3])
  pixels[(y0 + 3) * stride + x0 + 1] = vp8Avg3(a[2], a[3], a[4])
  pixels[(y0 + 1) * stride + x0 + 2] = vp8Avg3(a[2], a[3], a[4])
  pixels[(y0 + 2) * stride + x0 + 2] = vp8Avg2(a[3], a[4])
  pixels[y0 * stride + x0 + 3] = vp8Avg2(a[3], a[4])
  pixels[(y0 + 3) * stride + x0 + 2] = vp8Avg3(a[3], a[4], a[5])
  pixels[(y0 + 1) * stride + x0 + 3] = vp8Avg3(a[3], a[4], a[5])
  pixels[(y0 + 2) * stride + x0 + 3] = vp8Avg3(a[4], a[5], a[6])
  pixels[(y0 + 3) * stride + x0 + 3] = vp8Avg3(a[5], a[6], a[7])

proc predictBHdPred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  var e: array[9, uint8]
  for i in 0 ..< 9:
    e[i] = edgePixel(pixels, x0, y0, stride, i)
  pixels[(y0 + 3) * stride + x0] = vp8Avg2(e[0], e[1])
  pixels[(y0 + 3) * stride + x0 + 1] = vp8Avg3(e[0], e[1], e[2])
  pixels[(y0 + 2) * stride + x0] = vp8Avg2(e[1], e[2])
  pixels[(y0 + 3) * stride + x0 + 2] = vp8Avg2(e[1], e[2])
  pixels[(y0 + 2) * stride + x0 + 1] = vp8Avg3(e[1], e[2], e[3])
  pixels[(y0 + 3) * stride + x0 + 3] = vp8Avg3(e[1], e[2], e[3])
  pixels[(y0 + 2) * stride + x0 + 2] = vp8Avg2(e[2], e[3])
  pixels[(y0 + 1) * stride + x0] = vp8Avg2(e[2], e[3])
  pixels[(y0 + 2) * stride + x0 + 3] = vp8Avg3(e[2], e[3], e[4])
  pixels[(y0 + 1) * stride + x0 + 1] = vp8Avg3(e[2], e[3], e[4])
  pixels[(y0 + 1) * stride + x0 + 2] = vp8Avg2(e[3], e[4])
  pixels[y0 * stride + x0] = vp8Avg2(e[3], e[4])
  pixels[(y0 + 1) * stride + x0 + 3] = vp8Avg3(e[3], e[4], e[5])
  pixels[y0 * stride + x0 + 1] = vp8Avg3(e[3], e[4], e[5])
  pixels[y0 * stride + x0 + 2] = vp8Avg3(e[4], e[5], e[6])
  pixels[y0 * stride + x0 + 3] = vp8Avg3(e[5], e[6], e[7])

proc predictBHuPred(
  pixels: var openArray[uint8], x0, y0, stride: int
) =
  let
    l0 = leftPixel(pixels, x0, y0, stride, 0)
    l1 = leftPixel(pixels, x0, y0, stride, 1)
    l2 = leftPixel(pixels, x0, y0, stride, 2)
    l3 = leftPixel(pixels, x0, y0, stride, 3)
  pixels[y0 * stride + x0] = vp8Avg2(l0, l1)
  pixels[y0 * stride + x0 + 1] = vp8Avg3(l0, l1, l2)
  pixels[y0 * stride + x0 + 2] = vp8Avg2(l1, l2)
  pixels[(y0 + 1) * stride + x0] = vp8Avg2(l1, l2)
  pixels[y0 * stride + x0 + 3] = vp8Avg3(l1, l2, l3)
  pixels[(y0 + 1) * stride + x0 + 1] = vp8Avg3(l1, l2, l3)
  pixels[(y0 + 1) * stride + x0 + 2] = vp8Avg2(l2, l3)
  pixels[(y0 + 2) * stride + x0] = vp8Avg2(l2, l3)
  pixels[(y0 + 1) * stride + x0 + 3] = vp8Avg3(l2, l3, l3)
  pixels[(y0 + 2) * stride + x0 + 1] = vp8Avg3(l2, l3, l3)
  for y in 2 ..< 4:
    for x in 0 ..< 4:
      if y == 2 and x < 2:
        continue
      pixels[(y0 + y) * stride + x0 + x] = l3

proc predict4x4(
  pixels: var openArray[uint8],
  stride: int,
  modes: array[16, int],
  residue: openArray[int]
) =
  for sby in 0 ..< 4:
    for sbx in 0 ..< 4:
      let
        i = sbx + sby * 4
        y0 = sby * 4 + 1
        x0 = sbx * 4 + 1
      case modes[i]
      of Vp8BTmPred: predictTmpred(pixels, 4, x0, y0, stride)
      of Vp8BVePred: predictBVePred(pixels, x0, y0, stride)
      of Vp8BHePred: predictBHePred(pixels, x0, y0, stride)
      of Vp8BDcPred: predictBDcpred(pixels, x0, y0, stride)
      of Vp8BLdPred: predictBLdPred(pixels, x0, y0, stride)
      of Vp8BRdPred: predictBRdPred(pixels, x0, y0, stride)
      of Vp8BVrPred: predictBVrPred(pixels, x0, y0, stride)
      of Vp8BVlPred: predictBVlPred(pixels, x0, y0, stride)
      of Vp8BHdPred: predictBHdPred(pixels, x0, y0, stride)
      of Vp8BHuPred: predictBHuPred(pixels, x0, y0, stride)
      else: failInvalid("invalid VP8 intra prediction mode")
      pixels.addResidue(residue, i * 16, y0, x0, stride)

proc signedClamp(value: int): int {.inline.} =
  max(-128, min(127, value))

proc unsignedToSigned(value: uint8): int {.inline.} =
  value.int - 128

proc signedToUnsigned(value: int): uint8 {.inline.} =
  (signedClamp(value) + 128).uint8

proc byteDiff(a, b: uint8): uint8 {.inline.} =
  abs(a.int - b.int).uint8

proc commonAdjustVertical(
  pixels: var seq[uint8], point, stride: int, useOuterTaps: bool
): int =
  let
    p1 = unsignedToSigned(pixels[point - 2 * stride])
    p0 = unsignedToSigned(pixels[point - stride])
    q0 = unsignedToSigned(pixels[point])
    q1 = unsignedToSigned(pixels[point + stride])
    outer = if useOuterTaps: signedClamp(p1 - q1) else: 0
    a0 = signedClamp(outer + 3 * (q0 - p0))
    b = signedClamp(a0 + 3) shr 3
    a = signedClamp(a0 + 4) shr 3
  pixels[point] = signedToUnsigned(q0 - a)
  pixels[point - stride] = signedToUnsigned(p0 + b)
  return a

proc commonAdjustHorizontal(
  pixels: var seq[uint8], start: int, useOuterTaps: bool
): int =
  let
    p1 = unsignedToSigned(pixels[start + 2])
    p0 = unsignedToSigned(pixels[start + 3])
    q0 = unsignedToSigned(pixels[start + 4])
    q1 = unsignedToSigned(pixels[start + 5])
    outer = if useOuterTaps: signedClamp(p1 - q1) else: 0
    a0 = signedClamp(outer + 3 * (q0 - p0))
    b = signedClamp(a0 + 3) shr 3
    a = signedClamp(a0 + 4) shr 3
  pixels[start + 4] = signedToUnsigned(q0 - a)
  pixels[start + 3] = signedToUnsigned(p0 + b)
  return a

proc simpleThresholdVertical(
  edgeLimit: int, pixels: seq[uint8], point, stride: int
): bool =
  byteDiff(pixels[point - stride], pixels[point]).int * 2 +
    byteDiff(pixels[point - 2 * stride], pixels[point + stride]).int div 2 <=
    edgeLimit

proc simpleThresholdHorizontal(
  edgeLimit: int, pixels: seq[uint8], start: int
): bool =
  byteDiff(pixels[start + 3], pixels[start + 4]).int * 2 +
    byteDiff(pixels[start + 2], pixels[start + 5]).int div 2 <= edgeLimit

proc shouldFilterVertical(
  interiorLimit, edgeLimit: uint8, pixels: seq[uint8], point, stride: int
): bool =
  simpleThresholdVertical(edgeLimit.int, pixels, point, stride) and
    byteDiff(pixels[point - 4 * stride], pixels[point - 3 * stride]) <=
      interiorLimit and
    byteDiff(pixels[point - 3 * stride], pixels[point - 2 * stride]) <=
      interiorLimit and
    byteDiff(pixels[point - 2 * stride], pixels[point - stride]) <=
      interiorLimit and
    byteDiff(pixels[point + 3 * stride], pixels[point + 2 * stride]) <=
      interiorLimit and
    byteDiff(pixels[point + 2 * stride], pixels[point + stride]) <=
      interiorLimit and
    byteDiff(pixels[point + stride], pixels[point]) <= interiorLimit

proc shouldFilterHorizontal(
  interiorLimit, edgeLimit: uint8, pixels: seq[uint8], start: int
): bool =
  simpleThresholdHorizontal(edgeLimit.int, pixels, start) and
    byteDiff(pixels[start], pixels[start + 1]) <= interiorLimit and
    byteDiff(pixels[start + 1], pixels[start + 2]) <= interiorLimit and
    byteDiff(pixels[start + 2], pixels[start + 3]) <= interiorLimit and
    byteDiff(pixels[start + 7], pixels[start + 6]) <= interiorLimit and
    byteDiff(pixels[start + 6], pixels[start + 5]) <= interiorLimit and
    byteDiff(pixels[start + 5], pixels[start + 4]) <= interiorLimit

proc highEdgeVarianceVertical(
  threshold: uint8, pixels: seq[uint8], point, stride: int
): bool =
  byteDiff(pixels[point - 2 * stride], pixels[point - stride]) > threshold or
    byteDiff(pixels[point + stride], pixels[point]) > threshold

proc highEdgeVarianceHorizontal(
  threshold: uint8, pixels: seq[uint8], start: int
): bool =
  byteDiff(pixels[start + 2], pixels[start + 3]) > threshold or
    byteDiff(pixels[start + 5], pixels[start + 4]) > threshold

proc simpleSegmentVertical(
  pixels: var seq[uint8], edgeLimit: uint8, point, stride: int
) =
  if simpleThresholdVertical(edgeLimit.int, pixels, point, stride):
    discard pixels.commonAdjustVertical(point, stride, true)

proc simpleSegmentHorizontal(
  pixels: var seq[uint8], edgeLimit: uint8, start: int
) =
  if simpleThresholdHorizontal(edgeLimit.int, pixels, start):
    discard pixels.commonAdjustHorizontal(start, true)

proc subblockFilterVertical(
  pixels: var seq[uint8],
  hevThreshold, interiorLimit, edgeLimit: uint8,
  point, stride: int
) =
  if shouldFilterVertical(interiorLimit, edgeLimit, pixels, point, stride):
    let
      highVariance = highEdgeVarianceVertical(hevThreshold, pixels, point, stride)
      a = (pixels.commonAdjustVertical(point, stride, highVariance) + 1) shr 1
    if not highVariance:
      pixels[point + stride] =
        signedToUnsigned(unsignedToSigned(pixels[point + stride]) - a)
      pixels[point - 2 * stride] =
        signedToUnsigned(unsignedToSigned(pixels[point - 2 * stride]) + a)

proc subblockFilterHorizontal(
  pixels: var seq[uint8],
  hevThreshold, interiorLimit, edgeLimit: uint8,
  start: int
) =
  if shouldFilterHorizontal(interiorLimit, edgeLimit, pixels, start):
    let
      highVariance = highEdgeVarianceHorizontal(hevThreshold, pixels, start)
      a = (pixels.commonAdjustHorizontal(start, highVariance) + 1) shr 1
    if not highVariance:
      pixels[start + 5] = signedToUnsigned(unsignedToSigned(pixels[start + 5]) - a)
      pixels[start + 2] = signedToUnsigned(unsignedToSigned(pixels[start + 2]) + a)

proc macroblockFilterVertical(
  pixels: var seq[uint8],
  hevThreshold, interiorLimit, edgeLimit: uint8,
  point, stride: int
) =
  if shouldFilterVertical(interiorLimit, edgeLimit, pixels, point, stride):
    if not highEdgeVarianceVertical(hevThreshold, pixels, point, stride):
      let
        p2 = unsignedToSigned(pixels[point - 3 * stride])
        p1 = unsignedToSigned(pixels[point - 2 * stride])
        p0 = unsignedToSigned(pixels[point - stride])
        q0 = unsignedToSigned(pixels[point])
        q1 = unsignedToSigned(pixels[point + stride])
        q2 = unsignedToSigned(pixels[point + 2 * stride])
        w = signedClamp(signedClamp(p1 - q1) + 3 * (q0 - p0))
        a0 = signedClamp((27 * w + 63) shr 7)
        a1 = signedClamp((18 * w + 63) shr 7)
        a2 = signedClamp((9 * w + 63) shr 7)
      pixels[point] = signedToUnsigned(q0 - a0)
      pixels[point - stride] = signedToUnsigned(p0 + a0)
      pixels[point + stride] = signedToUnsigned(q1 - a1)
      pixels[point - 2 * stride] = signedToUnsigned(p1 + a1)
      pixels[point + 2 * stride] = signedToUnsigned(q2 - a2)
      pixels[point - 3 * stride] = signedToUnsigned(p2 + a2)
    else:
      discard pixels.commonAdjustVertical(point, stride, true)

proc macroblockFilterHorizontal(
  pixels: var seq[uint8],
  hevThreshold, interiorLimit, edgeLimit: uint8,
  start: int
) =
  if shouldFilterHorizontal(interiorLimit, edgeLimit, pixels, start):
    if not highEdgeVarianceHorizontal(hevThreshold, pixels, start):
      let
        p2 = unsignedToSigned(pixels[start + 1])
        p1 = unsignedToSigned(pixels[start + 2])
        p0 = unsignedToSigned(pixels[start + 3])
        q0 = unsignedToSigned(pixels[start + 4])
        q1 = unsignedToSigned(pixels[start + 5])
        q2 = unsignedToSigned(pixels[start + 6])
        w = signedClamp(signedClamp(p1 - q1) + 3 * (q0 - p0))
        a0 = signedClamp((27 * w + 63) shr 7)
        a1 = signedClamp((18 * w + 63) shr 7)
        a2 = signedClamp((9 * w + 63) shr 7)
      pixels[start + 4] = signedToUnsigned(q0 - a0)
      pixels[start + 3] = signedToUnsigned(p0 + a0)
      pixels[start + 5] = signedToUnsigned(q1 - a1)
      pixels[start + 2] = signedToUnsigned(p1 + a1)
      pixels[start + 6] = signedToUnsigned(q2 - a2)
      pixels[start + 1] = signedToUnsigned(p2 + a2)
    else:
      discard pixels.commonAdjustHorizontal(start, true)

proc newVp8Decoder(): Vp8Decoder =
  Vp8Decoder(
    frame: Vp8Frame(),
    numPartitions: 1,
    segmentProbs: [255.uint8, 255, 255],
    tokenProbs: Vp8CoeffProbs
  )

proc initPartitions(
  decoder: Vp8Decoder, data: string, offset, endPos, n: int
) =
  if n < 1 or n > 8:
    failInvalid("invalid VP8 partition count")

  var pos = offset
  if n > 1:
    data.checkBounds(pos, 3 * (n - 1))
    var sizes = newSeq[int](n - 1)
    for i in 0 ..< n - 1:
      sizes[i] = data.readUint24le(pos + i * 3)
    pos += 3 * (n - 1)

    for i in 0 ..< n - 1:
      if sizes[i] > endPos - pos:
        failInvalid("truncated VP8 partition")
      decoder.partitions[i] = newVp8BoolDecoder(data, pos, sizes[i])
      pos += sizes[i]

  if pos > endPos:
    failInvalid("truncated VP8 partition")
  decoder.partitions[n - 1] = newVp8BoolDecoder(data, pos, endPos - pos)

proc updateTokenProbabilities(decoder: Vp8Decoder) =
  for i in 0 ..< 4:
    for j in 0 ..< 8:
      for k in 0 ..< 3:
        for t in 0 ..< 11:
          if decoder.b.readBool(Vp8CoeffUpdateProbs[i][j][k][t]):
            decoder.tokenProbs[i][j][k][t] = decoder.b.readLiteral(8)

proc clampQuantIndex(value: int): int {.inline.} =
  max(0, min(127, value))

proc readQuantizationIndices(decoder: Vp8Decoder) =
  let
    yacAbs = decoder.b.readLiteral(7).int
    ydcDelta = decoder.b.readOptionalSignedValue(4)
    y2dcDelta = decoder.b.readOptionalSignedValue(4)
    y2acDelta = decoder.b.readOptionalSignedValue(4)
    uvdcDelta = decoder.b.readOptionalSignedValue(4)
    uvacDelta = decoder.b.readOptionalSignedValue(4)
    segmentCount = if decoder.segmentsEnabled: 4 else: 1

  for i in 0 ..< segmentCount:
    let base =
      if decoder.segmentsEnabled:
        if decoder.segments[i].deltaValues:
          decoder.segments[i].quantizerLevel.int + yacAbs
        else:
          decoder.segments[i].quantizerLevel.int
      else:
        yacAbs

    decoder.segments[i].ydc = Vp8DcQuant[clampQuantIndex(base + ydcDelta)]
    decoder.segments[i].yac = Vp8AcQuant[clampQuantIndex(base)]
    decoder.segments[i].y2dc =
      (Vp8DcQuant[clampQuantIndex(base + y2dcDelta)].int * 2).int16
    decoder.segments[i].y2ac =
      (Vp8AcQuant[clampQuantIndex(base + y2acDelta)].int * 155 div 100).int16
    decoder.segments[i].uvdc = Vp8DcQuant[clampQuantIndex(base + uvdcDelta)]
    decoder.segments[i].uvac = Vp8AcQuant[clampQuantIndex(base + uvacDelta)]
    if decoder.segments[i].y2ac < 8:
      decoder.segments[i].y2ac = 8
    if decoder.segments[i].uvdc > 132:
      decoder.segments[i].uvdc = 132

proc readLoopFilterAdjustments(decoder: Vp8Decoder) =
  if decoder.b.readFlag():
    for i in 0 ..< 4:
      decoder.refDelta[i] = decoder.b.readOptionalSignedValue(6)
    for i in 0 ..< 4:
      decoder.modeDelta[i] = decoder.b.readOptionalSignedValue(6)

proc readSegmentUpdates(decoder: Vp8Decoder) =
  decoder.segmentsUpdateMap = decoder.b.readFlag()
  let updateSegmentFeatureData = decoder.b.readFlag()

  if updateSegmentFeatureData:
    let segmentFeatureMode = decoder.b.readFlag()
    for i in 0 ..< 4:
      decoder.segments[i].deltaValues = not segmentFeatureMode
    for i in 0 ..< 4:
      decoder.segments[i].quantizerLevel =
        decoder.b.readOptionalSignedValue(7).int8
    for i in 0 ..< 4:
      decoder.segments[i].loopfilterLevel =
        decoder.b.readOptionalSignedValue(6).int8

  if decoder.segmentsUpdateMap:
    for i in 0 ..< 3:
      decoder.segmentProbs[i] =
        if decoder.b.readFlag(): decoder.b.readLiteral(8)
        else: 255

proc lumaModeToIntra(mode: int): int =
  case mode
  of Vp8DcPred: Vp8BDcPred
  of Vp8VPred: Vp8BVePred
  of Vp8HPred: Vp8BHePred
  of Vp8TmPred: Vp8BTmPred
  else: -1

proc readMacroblockHeader(
  decoder: Vp8Decoder, mbx: int
): Vp8MacroBlock =
  if decoder.segmentsEnabled and decoder.segmentsUpdateMap:
    result.segmentId = decoder.b.readTree(
      Vp8SegmentIdTree, decoder.segmentProbs
    ).uint8

  result.coeffsSkipped =
    if decoder.hasProbSkipFalse: decoder.b.readBool(decoder.probSkipFalse)
    else: false

  result.lumaMode = decoder.b.readTree(
    Vp8KeyframeYModeTree, Vp8KeyframeYModeProbs
  )
  if result.lumaMode < Vp8DcPred or result.lumaMode > Vp8BPred:
    failInvalid("invalid VP8 luma prediction mode")

  let blockMode = lumaModeToIntra(result.lumaMode)
  if blockMode < 0:
    for y in 0 ..< 4:
      for x in 0 ..< 4:
        let
          top = decoder.top[mbx].bpred[x]
          left = decoder.left.bpred[y]
          mode = decoder.b.readTree(
            Vp8KeyframeBpredModeTree,
            Vp8KeyframeBpredModeProbs[top][left]
          )
        if mode < Vp8BDcPred or mode > Vp8BHuPred:
          failInvalid("invalid VP8 intra prediction mode")
        result.bpred[x + y * 4] = mode
        decoder.top[mbx].bpred[x] = mode
        decoder.left.bpred[y] = mode
  else:
    for i in 0 ..< 4:
      result.bpred[12 + i] = blockMode
      decoder.left.bpred[i] = blockMode

  result.chromaMode = decoder.b.readTree(
    Vp8KeyframeUvModeTree, Vp8KeyframeUvModeProbs
  )
  if result.chromaMode < Vp8DcPred or result.chromaMode > Vp8TmPred:
    failInvalid("invalid VP8 chroma prediction mode")

  for i in 0 ..< 4:
    decoder.top[mbx].bpred[i] = result.bpred[12 + i]

proc readCoefficients(
  decoder: Vp8Decoder,
  coeffBlock: var array[16, int],
  partitionIndex, plane, complexity: int,
  dcq, acq: int16
): bool =
  let partition = decoder.partitions[partitionIndex]
  var
    complexityState = complexity
    skip = false
  let firstCoeff = if plane == 0: 1 else: 0

  for i in firstCoeff ..< 16:
    let
      band = Vp8CoeffBands[i].int
      start = if skip: 1 else: 0
      token = partition.readTree(
        Vp8DctTokenTree, decoder.tokenProbs[plane][band][complexityState], start
      )

    var absValue: int
    case token
    of Vp8DctEob:
      break
    of Vp8Dct0:
      skip = true
      result = true
      complexityState = 0
      continue
    of Vp8Dct1 .. Vp8Dct4:
      absValue = token
    of Vp8DctCat1 .. Vp8DctCat6:
      let category = token - Vp8DctCat1
      var extra = 0
      for probability in Vp8ProbDctCat[category]:
        if probability == 0:
          break
        extra = extra + extra + partition.readBool(probability).int
      absValue = Vp8DctCatBase[category].int + extra
    else:
      failInvalid("invalid VP8 DCT token")

    skip = false
    complexityState =
      if absValue == 0: 0
      elif absValue == 1: 1
      else: 2

    if partition.readFlag():
      absValue = -absValue

    let zigzag = Vp8Zigzag[i].int
    coeffBlock[zigzag] = absValue * (if zigzag > 0: acq.int else: dcq.int)
    result = true

proc readResidualData(
  decoder: Vp8Decoder, mb: Vp8MacroBlock, mbx, partitionIndex: int
): tuple[residue: array[384, int], nonZeroDct: bool] =
  let segmentIndex = mb.segmentId.int
  var
    plane = if mb.lumaMode == Vp8BPred: 3 else: 1
    residue: array[384, int]
    nonZeroDct = false

  if plane == 1:
    let
      complexity = decoder.top[mbx].complexity[0].int +
        decoder.left.complexity[0].int
      dcq = decoder.segments[segmentIndex].y2dc
      acq = decoder.segments[segmentIndex].y2ac
    var coeffBlock: array[16, int]
    let hasCoefficients = decoder.readCoefficients(
      coeffBlock, partitionIndex, plane, complexity, dcq, acq
    )
    decoder.left.complexity[0] = hasCoefficients.uint8
    decoder.top[mbx].complexity[0] = hasCoefficients.uint8
    coeffBlock.iwht4x4()
    for k in 0 ..< 16:
      residue[16 * k] = coeffBlock[k]
    plane = 0

  for y in 0 ..< 4:
    var left = decoder.left.complexity[y + 1]
    for x in 0 ..< 4:
      let
        i = x + y * 4
        complexity = decoder.top[mbx].complexity[x + 1].int + left.int
        dcq = decoder.segments[segmentIndex].ydc
        acq = decoder.segments[segmentIndex].yac
      var coeffBlock: array[16, int]
      coeffBlock[0] = residue[i * 16]
      let hasCoefficients = decoder.readCoefficients(
        coeffBlock, partitionIndex, plane, complexity, dcq, acq
      )
      if coeffBlock[0] != 0 or hasCoefficients:
        nonZeroDct = true
        coeffBlock.idct4x4()
      left = hasCoefficients.uint8
      decoder.top[mbx].complexity[x + 1] = hasCoefficients.uint8
      for k in 0 ..< 16:
        residue[i * 16 + k] = coeffBlock[k]
    decoder.left.complexity[y + 1] = left

  plane = 2
  for j in [5, 7]:
    for y in 0 ..< 2:
      var left = decoder.left.complexity[y + j]
      for x in 0 ..< 2:
        let
          i = x + y * 2 + (if j == 5: 16 else: 20)
          complexity = decoder.top[mbx].complexity[x + j].int + left.int
          dcq = decoder.segments[segmentIndex].uvdc
          acq = decoder.segments[segmentIndex].uvac
        var coeffBlock: array[16, int]
        let hasCoefficients = decoder.readCoefficients(
          coeffBlock, partitionIndex, plane, complexity, dcq, acq
        )
        if coeffBlock[0] != 0 or hasCoefficients:
          nonZeroDct = true
          coeffBlock.idct4x4()
        left = hasCoefficients.uint8
        decoder.top[mbx].complexity[x + j] = hasCoefficients.uint8
        for k in 0 ..< 16:
          residue[i * 16 + k] = coeffBlock[k]
      decoder.left.complexity[y + j] = left

  return (residue, nonZeroDct)

proc setChromaBorder(
  leftBorder, topBorder: var seq[uint8],
  chromaBlock: openArray[uint8],
  mbx: int
) =
  leftBorder[0] = chromaBlock[8]
  for i in 0 ..< 8:
    leftBorder[1 + i] = chromaBlock[(i + 1) * Vp8ChromaStride + 8]
  for i in 0 ..< 8:
    topBorder[mbx * 8 + i] = chromaBlock[8 * Vp8ChromaStride + 1 + i]

proc intraPredictLuma(
  decoder: Vp8Decoder,
  mbx, mby: int,
  mb: Vp8MacroBlock,
  residue: openArray[int]
) =
  let lumaWidth = decoder.mbWidth * 16
  var ws = createBorderLuma(
    mbx, mby, decoder.mbWidth, decoder.topBorderY, decoder.leftBorderY
  )

  case mb.lumaMode
  of Vp8VPred: ws.predictVpred(16, 1, 1, Vp8LumaStride)
  of Vp8HPred: ws.predictHpred(16, 1, 1, Vp8LumaStride)
  of Vp8TmPred: ws.predictTmpred(16, 1, 1, Vp8LumaStride)
  of Vp8DcPred: ws.predictDcpred(16, Vp8LumaStride, mby != 0, mbx != 0)
  of Vp8BPred: ws.predict4x4(Vp8LumaStride, mb.bpred, residue)
  else: failInvalid("invalid VP8 luma prediction mode")

  if mb.lumaMode != Vp8BPred:
    for y in 0 ..< 4:
      for x in 0 ..< 4:
        let
          i = x + y * 4
          y0 = 1 + y * 4
          x0 = 1 + x * 4
        ws.addResidue(residue, i * 16, y0, x0, Vp8LumaStride)

  decoder.leftBorderY[0] = ws[16]
  for i in 0 ..< 16:
    decoder.leftBorderY[1 + i] = ws[(i + 1) * Vp8LumaStride + 16]
  for i in 0 ..< 16:
    decoder.topBorderY[mbx * 16 + i] = ws[16 * Vp8LumaStride + 1 + i]

  for y in 0 ..< 16:
    let
      dst = (mby * 16 + y) * lumaWidth + mbx * 16
      src = (1 + y) * Vp8LumaStride + 1
    for x in 0 ..< 16:
      decoder.frame.ybuf[dst + x] = ws[src + x]

proc intraPredictChroma(
  decoder: Vp8Decoder,
  mbx, mby: int,
  mb: Vp8MacroBlock,
  residue: openArray[int]
) =
  let chromaWidth = decoder.mbWidth * 8
  var
    uws = createBorderChroma(mbx, mby, decoder.topBorderU, decoder.leftBorderU)
    vws = createBorderChroma(mbx, mby, decoder.topBorderV, decoder.leftBorderV)

  case mb.chromaMode
  of Vp8DcPred:
    uws.predictDcpred(8, Vp8ChromaStride, mby != 0, mbx != 0)
    vws.predictDcpred(8, Vp8ChromaStride, mby != 0, mbx != 0)
  of Vp8VPred:
    uws.predictVpred(8, 1, 1, Vp8ChromaStride)
    vws.predictVpred(8, 1, 1, Vp8ChromaStride)
  of Vp8HPred:
    uws.predictHpred(8, 1, 1, Vp8ChromaStride)
    vws.predictHpred(8, 1, 1, Vp8ChromaStride)
  of Vp8TmPred:
    uws.predictTmpred(8, 1, 1, Vp8ChromaStride)
    vws.predictTmpred(8, 1, 1, Vp8ChromaStride)
  else:
    failInvalid("invalid VP8 chroma prediction mode")

  for y in 0 ..< 2:
    for x in 0 ..< 2:
      let
        i = x + y * 2
        y0 = 1 + y * 4
        x0 = 1 + x * 4
      uws.addResidue(residue, (16 + i) * 16, y0, x0, Vp8ChromaStride)
      vws.addResidue(residue, (20 + i) * 16, y0, x0, Vp8ChromaStride)

  setChromaBorder(decoder.leftBorderU, decoder.topBorderU, uws, mbx)
  setChromaBorder(decoder.leftBorderV, decoder.topBorderV, vws, mbx)

  for y in 0 ..< 8:
    let
      dst = (mby * 8 + y) * chromaWidth + mbx * 8
      src = (1 + y) * Vp8ChromaStride + 1
    for x in 0 ..< 8:
      decoder.frame.ubuf[dst + x] = uws[src + x]
      decoder.frame.vbuf[dst + x] = vws[src + x]

proc calculateFilterParameters(
  decoder: Vp8Decoder, mb: Vp8MacroBlock
): tuple[filterLevel, interiorLimit, hevThreshold: uint8] =
  let segment = decoder.segments[mb.segmentId.int]
  var filterLevel = decoder.frame.filterLevel.int
  if filterLevel == 0:
    return (0.uint8, 0.uint8, 0.uint8)

  if decoder.segmentsEnabled:
    if segment.deltaValues:
      filterLevel += segment.loopfilterLevel.int
    else:
      filterLevel = segment.loopfilterLevel.int
  filterLevel = max(0, min(63, filterLevel))

  if decoder.loopFilterAdjustmentsEnabled:
    filterLevel += decoder.refDelta[0]
    if mb.lumaMode == Vp8BPred:
      filterLevel += decoder.modeDelta[0]
  filterLevel = max(0, min(63, filterLevel))

  var interiorLimit = filterLevel
  if decoder.frame.sharpnessLevel > 0:
    interiorLimit = interiorLimit shr (
      if decoder.frame.sharpnessLevel > 4: 2 else: 1
    )
    let sharpLimit = 9 - decoder.frame.sharpnessLevel.int
    if interiorLimit > sharpLimit:
      interiorLimit = sharpLimit
  if interiorLimit == 0:
    interiorLimit = 1

  let hevThreshold =
    if filterLevel >= 40: 2
    elif filterLevel >= 15: 1
    else: 0

  (filterLevel.uint8, interiorLimit.uint8, hevThreshold.uint8)

proc loopFilter(decoder: Vp8Decoder, mbx, mby: int, mb: Vp8MacroBlock) =
  let
    lumaWidth = decoder.mbWidth * 16
    chromaWidth = decoder.mbWidth * 8
    params = decoder.calculateFilterParameters(mb)
  if params.filterLevel == 0:
    return

  let
    macroblockEdgeLimit =
      ((params.filterLevel + 2) * 2 + params.interiorLimit).uint8
    subblockEdgeLimit =
      (params.filterLevel * 2 + params.interiorLimit).uint8
    doSubblockFiltering =
      mb.lumaMode == Vp8BPred or (not mb.coeffsSkipped and mb.nonZeroDct)

  if mbx > 0:
    if decoder.frame.filterType:
      for y in 0 ..< 16:
        let point = (mby * 16 + y) * lumaWidth + mbx * 16
        decoder.frame.ybuf.simpleSegmentHorizontal(macroblockEdgeLimit, point - 4)
    else:
      for y in 0 ..< 16:
        let point = (mby * 16 + y) * lumaWidth + mbx * 16
        decoder.frame.ybuf.macroblockFilterHorizontal(
          params.hevThreshold, params.interiorLimit, macroblockEdgeLimit,
          point - 4
        )
      for y in 0 ..< 8:
        let point = (mby * 8 + y) * chromaWidth + mbx * 8
        decoder.frame.ubuf.macroblockFilterHorizontal(
          params.hevThreshold, params.interiorLimit, macroblockEdgeLimit,
          point - 4
        )
        decoder.frame.vbuf.macroblockFilterHorizontal(
          params.hevThreshold, params.interiorLimit, macroblockEdgeLimit,
          point - 4
        )

  if doSubblockFiltering:
    if decoder.frame.filterType:
      for x in countup(4, 12, 4):
        for y in 0 ..< 16:
          let point = (mby * 16 + y) * lumaWidth + mbx * 16 + x
          decoder.frame.ybuf.simpleSegmentHorizontal(subblockEdgeLimit, point - 4)
    else:
      for x in countup(4, 12, 4):
        for y in 0 ..< 16:
          let point = (mby * 16 + y) * lumaWidth + mbx * 16 + x
          decoder.frame.ybuf.subblockFilterHorizontal(
            params.hevThreshold, params.interiorLimit, subblockEdgeLimit,
            point - 4
          )
      for y in 0 ..< 8:
        let point = (mby * 8 + y) * chromaWidth + mbx * 8 + 4
        decoder.frame.ubuf.subblockFilterHorizontal(
          params.hevThreshold, params.interiorLimit, subblockEdgeLimit, point - 4
        )
        decoder.frame.vbuf.subblockFilterHorizontal(
          params.hevThreshold, params.interiorLimit, subblockEdgeLimit, point - 4
        )

  if mby > 0:
    if decoder.frame.filterType:
      for x in 0 ..< 16:
        let point = (mby * 16) * lumaWidth + mbx * 16 + x
        decoder.frame.ybuf.simpleSegmentVertical(
          macroblockEdgeLimit, point, lumaWidth
        )
    else:
      for x in 0 ..< 16:
        let point = (mby * 16) * lumaWidth + mbx * 16 + x
        decoder.frame.ybuf.macroblockFilterVertical(
          params.hevThreshold, params.interiorLimit, macroblockEdgeLimit,
          point, lumaWidth
        )
      for x in 0 ..< 8:
        let point = (mby * 8) * chromaWidth + mbx * 8 + x
        decoder.frame.ubuf.macroblockFilterVertical(
          params.hevThreshold, params.interiorLimit, macroblockEdgeLimit,
          point, chromaWidth
        )
        decoder.frame.vbuf.macroblockFilterVertical(
          params.hevThreshold, params.interiorLimit, macroblockEdgeLimit,
          point, chromaWidth
        )

  if doSubblockFiltering:
    if decoder.frame.filterType:
      for y in countup(4, 12, 4):
        for x in 0 ..< 16:
          let point = (mby * 16 + y) * lumaWidth + mbx * 16 + x
          decoder.frame.ybuf.simpleSegmentVertical(subblockEdgeLimit, point, lumaWidth)
    else:
      for y in countup(4, 12, 4):
        for x in 0 ..< 16:
          let point = (mby * 16 + y) * lumaWidth + mbx * 16 + x
          decoder.frame.ybuf.subblockFilterVertical(
            params.hevThreshold, params.interiorLimit, subblockEdgeLimit,
            point, lumaWidth
          )
      for x in 0 ..< 8:
        let point = (mby * 8 + 4) * chromaWidth + mbx * 8 + x
        decoder.frame.ubuf.subblockFilterVertical(
          params.hevThreshold, params.interiorLimit, subblockEdgeLimit,
          point, chromaWidth
        )
        decoder.frame.vbuf.subblockFilterVertical(
          params.hevThreshold, params.interiorLimit, subblockEdgeLimit,
          point, chromaWidth
        )

proc decodeVp8Frame(
  data: string, offset, size: int, width, height: int
): Vp8Frame =
  if size < 10:
    failInvalid("truncated VP8 header")

  let frameTag =
    data.readUint8Checked(offset + 0).uint32 or
    (data.readUint8Checked(offset + 1).uint32 shl 8) or
    (data.readUint8Checked(offset + 2).uint32 shl 16)
  if (frameTag and 1) != 0:
    failInvalid("VP8 image is not a key frame")
  if data.readUint8Checked(offset + 3) != 0x9d or
      data.readUint8Checked(offset + 4) != 0x01 or
      data.readUint8Checked(offset + 5) != 0x2a:
    failInvalid("invalid VP8 start code")

  let
    firstPartitionSize = (frameTag shr 5).int
    frameWidth = data.readUint16le(offset + 6) and 0x3fff
    frameHeight = data.readUint16le(offset + 8) and 0x3fff
  if frameWidth != width or frameHeight != height:
    failInvalid("inconsistent VP8 dimensions")
  if firstPartitionSize > size - 10:
    failInvalid("truncated VP8 first partition")

  let decoder = newVp8Decoder()
  decoder.frame.width = frameWidth
  decoder.frame.height = frameHeight
  decoder.frame.version = ((frameTag shr 1) and 7).uint8
  decoder.frame.forDisplay = ((frameTag shr 4) and 1) != 0
  decoder.mbWidth = (frameWidth + 15) div 16
  decoder.mbHeight = (frameHeight + 15) div 16

  let
    lumaWidth = decoder.mbWidth * 16
    chromaWidth = decoder.mbWidth * 8
  decoder.top = newSeq[Vp8PreviousMacroBlock](decoder.mbWidth)
  decoder.frame.ybuf = newSeq[uint8](lumaWidth * decoder.mbHeight * 16)
  decoder.frame.ubuf = newSeq[uint8](chromaWidth * decoder.mbHeight * 8)
  decoder.frame.vbuf = newSeq[uint8](chromaWidth * decoder.mbHeight * 8)
  decoder.topBorderY = newSeq[uint8](lumaWidth + 4)
  decoder.leftBorderY = newSeq[uint8](17)
  decoder.topBorderU = newSeq[uint8](chromaWidth)
  decoder.leftBorderU = newSeq[uint8](9)
  decoder.topBorderV = newSeq[uint8](chromaWidth)
  decoder.leftBorderV = newSeq[uint8](9)
  for i in 0 ..< decoder.topBorderY.len:
    decoder.topBorderY[i] = 127
  for i in 0 ..< decoder.leftBorderY.len:
    decoder.leftBorderY[i] = 129
  for i in 0 ..< decoder.topBorderU.len:
    decoder.topBorderU[i] = 127
    decoder.topBorderV[i] = 127
  for i in 0 ..< decoder.leftBorderU.len:
    decoder.leftBorderU[i] = 129
    decoder.leftBorderV[i] = 129

  let
    firstPartitionOffset = offset + 10
    tokenPartitionOffset = firstPartitionOffset + firstPartitionSize
    chunkEnd = offset + size
  decoder.b = newVp8BoolDecoder(data, firstPartitionOffset, firstPartitionSize)

  let colorSpace = decoder.b.readLiteral(1)
  decoder.frame.pixelType = decoder.b.readLiteral(1)
  if colorSpace != 0:
    failInvalid("invalid VP8 color space")

  decoder.segmentsEnabled = decoder.b.readFlag()
  if decoder.segmentsEnabled:
    decoder.readSegmentUpdates()

  decoder.frame.filterType = decoder.b.readFlag()
  decoder.frame.filterLevel = decoder.b.readLiteral(6)
  decoder.frame.sharpnessLevel = decoder.b.readLiteral(3)
  decoder.loopFilterAdjustmentsEnabled = decoder.b.readFlag()
  if decoder.loopFilterAdjustmentsEnabled:
    decoder.readLoopFilterAdjustments()

  decoder.numPartitions = 1 shl decoder.b.readLiteral(2).int
  decoder.initPartitions(
    data, tokenPartitionOffset, chunkEnd, decoder.numPartitions
  )
  decoder.readQuantizationIndices()
  discard decoder.b.readLiteral(1)
  decoder.updateTokenProbabilities()

  decoder.hasProbSkipFalse = decoder.b.readLiteral(1) == 1
  if decoder.hasProbSkipFalse:
    decoder.probSkipFalse = decoder.b.readLiteral(8)

  for mby in 0 ..< decoder.mbHeight:
    let partitionIndex = mby mod decoder.numPartitions
    decoder.left = Vp8PreviousMacroBlock()
    for mbx in 0 ..< decoder.mbWidth:
      var mb = decoder.readMacroblockHeader(mbx)
      let residue =
        if not mb.coeffsSkipped:
          let residual = decoder.readResidualData(mb, mbx, partitionIndex)
          mb.nonZeroDct = residual.nonZeroDct
          residual.residue
        else:
          if mb.lumaMode != Vp8BPred:
            decoder.left.complexity[0] = 0
            decoder.top[mbx].complexity[0] = 0
          for i in 1 ..< 9:
            decoder.left.complexity[i] = 0
            decoder.top[mbx].complexity[i] = 0
          default(array[384, int])

      decoder.intraPredictLuma(mbx, mby, mb, residue)
      decoder.intraPredictChroma(mbx, mby, mb, residue)
      decoder.macroblocks.add(mb)

    for i in 0 ..< decoder.leftBorderY.len:
      decoder.leftBorderY[i] = 129
    for i in 0 ..< decoder.leftBorderU.len:
      decoder.leftBorderU[i] = 129
      decoder.leftBorderV[i] = 129

  for mby in 0 ..< decoder.mbHeight:
    for mbx in 0 ..< decoder.mbWidth:
      decoder.loopFilter(
        mbx, mby, decoder.macroblocks[mby * decoder.mbWidth + mbx]
      )

  decoder.frame

proc yuvMulhi(value: uint8, coefficient: int): int {.inline.} =
  (value.int * coefficient) shr 8

proc yuvClip(value: int): uint8 {.inline.} =
  if value < 0:
    0
  elif value > (256 shl 6) - 1:
    255
  else:
    (value shr 6).uint8

proc yuvToR(y, v: uint8): uint8 {.inline.} =
  yuvClip(yuvMulhi(y, 19077) + yuvMulhi(v, 26149) - 14234)

proc yuvToG(y, u, v: uint8): uint8 {.inline.} =
  yuvClip(yuvMulhi(y, 19077) - yuvMulhi(u, 6419) -
    yuvMulhi(v, 13320) + 8708)

proc yuvToB(y, u: uint8): uint8 {.inline.} =
  yuvClip(yuvMulhi(y, 19077) + yuvMulhi(u, 33050) - 17685)

proc getFancyChroma(
  main, secondary1, secondary2, tertiary: uint8
): uint8 {.inline.} =
  ((9 * main.uint16 + 3 * secondary1.uint16 + 3 * secondary2.uint16 +
    tertiary.uint16 + 8) div 16).uint8

proc frameToRgbaBytes(frame: Vp8Frame): seq[uint8] =
  result = newSeq[uint8](frame.width * frame.height * 4)
  let
    lumaWidth = ((frame.width + 15) div 16) * 16
    chromaWidth = lumaWidth div 2
    chromaPixelWidth = (frame.width + 1) div 2
    chromaPixelHeight = (frame.height + 1) div 2
  for y in 0 ..< frame.height:
    let
      topOnly = y == 0 or (y == frame.height - 1 and (frame.height and 1) == 0)
      mainRow =
        if y == 0: 0
        elif topOnly: chromaPixelHeight - 1
        else: y div 2
      otherRow =
        if topOnly:
          mainRow
        elif (y and 1) != 0:
          min(chromaPixelHeight - 1, mainRow + 1)
        else:
          max(0, mainRow - 1)
      mainBase = mainRow * chromaWidth
      otherBase = otherRow * chromaWidth
    for x in 0 ..< frame.width:
      var
        uValue: uint8
        vValue: uint8
      if x == 0:
        if topOnly:
          uValue = frame.ubuf[mainBase]
          vValue = frame.vbuf[mainBase]
        else:
          uValue = getFancyChroma(
            frame.ubuf[mainBase], frame.ubuf[mainBase],
            frame.ubuf[otherBase], frame.ubuf[otherBase]
          )
          vValue = getFancyChroma(
            frame.vbuf[mainBase], frame.vbuf[mainBase],
            frame.vbuf[otherBase], frame.vbuf[otherBase]
          )
      elif (x and 1) != 0:
        let
          col = (x - 1) div 2
          nextCol = min(chromaPixelWidth - 1, col + 1)
        uValue = getFancyChroma(
          frame.ubuf[mainBase + col], frame.ubuf[mainBase + nextCol],
          frame.ubuf[otherBase + col], frame.ubuf[otherBase + nextCol]
        )
        vValue = getFancyChroma(
          frame.vbuf[mainBase + col], frame.vbuf[mainBase + nextCol],
          frame.vbuf[otherBase + col], frame.vbuf[otherBase + nextCol]
        )
      else:
        let
          col = x div 2
          prevCol = max(0, col - 1)
        uValue = getFancyChroma(
          frame.ubuf[mainBase + col], frame.ubuf[mainBase + prevCol],
          frame.ubuf[otherBase + col], frame.ubuf[otherBase + prevCol]
        )
        vValue = getFancyChroma(
          frame.vbuf[mainBase + col], frame.vbuf[mainBase + prevCol],
          frame.vbuf[otherBase + col], frame.vbuf[otherBase + prevCol]
        )

      let
        yValue = frame.ybuf[y * lumaWidth + x]
        dst = (y * frame.width + x) * 4
      result[dst + 0] = yuvToR(yValue, vValue)
      result[dst + 1] = yuvToG(yValue, uValue, vValue)
      result[dst + 2] = yuvToB(yValue, uValue)
      result[dst + 3] = 255

proc alphaPredictor(
  alpha: seq[uint8], width, x, y, filterMethod: int
): uint8 =
  case filterMethod
  of 0:
    0
  of 1:
    if x == 0 and y == 0:
      0
    elif x == 0:
      alpha[(y - 1) * width + x]
    else:
      alpha[y * width + x - 1]
  of 2:
    if x == 0 and y == 0:
      0
    elif y == 0:
      alpha[y * width + x - 1]
    else:
      alpha[(y - 1) * width + x]
  of 3:
    let (left, top, topLeft) =
      if x == 0 and y == 0:
        (0, 0, 0)
      elif x == 0:
        let value = alpha[(y - 1) * width + x].int
        (value, value, value)
      elif y == 0:
        let value = alpha[y * width + x - 1].int
        (value, value, value)
      else:
        (
          alpha[y * width + x - 1].int,
          alpha[(y - 1) * width + x].int,
          alpha[(y - 1) * width + x - 1].int
        )
    max(0, min(255, left + top - topLeft)).uint8
  else:
    failInvalid("invalid VP8 alpha filter")

proc decodeAlphaData(data: string, info: WebpInfo): seq[uint8] =
  if info.alphaSize < 1:
    failInvalid("invalid ALPH chunk size")
  if info.alphaInfo.preprocessing > 1:
    failInvalid("invalid VP8 alpha preprocessing")
  if info.alphaInfo.compressionMethod > 1:
    failInvalid("invalid VP8 alpha compression")

  let
    payloadOffset = info.alphaOffset + 1
    payloadSize = info.alphaSize - 1
    pixelCount = info.width * info.height
  var residual: seq[uint8]
  case info.alphaInfo.compressionMethod
  of 0:
    if payloadSize < pixelCount:
      failInvalid("truncated VP8 alpha data")
    data.checkBounds(payloadOffset, pixelCount)
    residual = newSeq[uint8](pixelCount)
    for i in 0 ..< pixelCount:
      residual[i] = data.readUint8(payloadOffset + i)
  of 1:
    let rgbaData = decodeLosslessData(
      data, payloadOffset, payloadSize, info.width, info.height, true
    )
    residual = newSeq[uint8](pixelCount)
    for i in 0 ..< pixelCount:
      residual[i] = rgbaData[i * 4 + 1]
  else:
    failInvalid("invalid VP8 alpha compression")

  result = newSeq[uint8](pixelCount)
  for y in 0 ..< info.height:
    for x in 0 ..< info.width:
      let index = y * info.width + x
      result[index] = wrapByte(
        result.alphaPredictor(info.width, x, y,
            info.alphaInfo.filterMethod).int +
        residual[index].int
      )

proc parseVp8Dimensions(
  data: string, offset, size: int, info: WebpInfo
) =
  if size < 10:
    failInvalid("truncated VP8 header")

  let frameTag =
    data.readUint8Checked(offset + 0).uint32 or
    (data.readUint8Checked(offset + 1).uint32 shl 8) or
    (data.readUint8Checked(offset + 2).uint32 shl 16)
  let frameType = frameTag and 1
  if frameType != 0:
    failInvalid("VP8 image is not a key frame")

  info.vp8Version = ((frameTag shr 1) and 0x7).int
  info.vp8ShowFrame = ((frameTag shr 4) and 1) != 0

  if data.readUint8Checked(offset + 3) != 0x9d or
      data.readUint8Checked(offset + 4) != 0x01 or
      data.readUint8Checked(offset + 5) != 0x2a:
    failInvalid("invalid VP8 start code")

  let
    width = data.readUint16le(offset + 6) and 0x3fff
    height = data.readUint16le(offset + 8) and 0x3fff
  checkImageSize(width, height)
  if not info.hasVp8X:
    info.width = width
    info.height = height

proc parseVp8LDimensions(
  data: string, offset, size: int, info: WebpInfo
) =
  if size < 5:
    failInvalid("truncated VP8L header")
  if data.readUint8Checked(offset) != 0x2f:
    failInvalid("invalid VP8L signature")

  let bits = data.readUint32le(offset + 1)
  let
    width = ((bits and 0x3fff) + 1).int
    height = (((bits shr 14) and 0x3fff) + 1).int
    version = ((bits shr 29) and 0x7).int
  if version != 0:
    failInvalid("invalid VP8L version")

  checkImageSize(width, height)
  info.losslessAlpha = ((bits shr 28) and 1) != 0
  if not info.hasVp8X:
    info.width = width
    info.height = height

proc parseVp8X(data: string, offset, size: int, info: WebpInfo) =
  if size != 10:
    failInvalid("invalid VP8X chunk size")

  let flags = data.readUint8Checked(offset)
  info.hasIccp = (flags and 0b00100000) != 0
  info.hasAlpha = (flags and 0b00010000) != 0
  info.hasExif = (flags and 0b00001000) != 0
  info.hasXmp = (flags and 0b00000100) != 0
  info.hasAnimation = (flags and 0b00000010) != 0

  let
    width = data.readUint24le(offset + 4) + 1
    height = data.readUint24le(offset + 7) + 1
  checkImageSize(width, height)
  info.hasVp8X = true
  info.width = width
  info.height = height

proc parseAlpha(data: string, offset, size: int, info: WebpInfo) =
  if size < 1:
    failInvalid("invalid ALPH chunk size")
  let flags = data.readUint8Checked(offset)
  info.alphaInfo.compressionMethod = (flags and 0b00000011).int
  info.alphaInfo.filterMethod = ((flags shr 2) and 0b00000011).int
  info.alphaInfo.preprocessing = ((flags shr 4) and 0b00000011).int
  info.hasAlpha = true

proc parseAnim(data: string, offset, size: int, info: WebpInfo) =
  if size < 6:
    failInvalid("invalid ANIM chunk size")
  let bg = data.readUint32le(offset)
  info.backgroundColor = rgba(
    ((bg shr 16) and 0xff).uint8,
    ((bg shr 8) and 0xff).uint8,
    (bg and 0xff).uint8,
    ((bg shr 24) and 0xff).uint8
  )
  info.loopCount = data.readUint16le(offset + 4)
  info.hasAnimation = true

proc parseAnimFrame(data: string, offset, size: int, info: WebpInfo) =
  if size < 16:
    failInvalid("invalid ANMF chunk size")
  inc info.frameCount

proc decodeWebpInfo*(data: string): WebpInfo {.raises: [PixieError].} =
  ## Decodes WebP container and image-header information.
  if data.len < 12:
    failInvalid("truncated RIFF header")
  if data.readStrChecked(0, 4) != WebpRiffSignature:
    failInvalid("missing RIFF signature")
  if data.readStrChecked(8, 4) != WebpSignature:
    failInvalid("missing WEBP signature")

  result = WebpInfo()
  let riffSize = data.readUint32le(4).int
  if riffSize < 4:
    failInvalid("invalid RIFF size")
  if riffSize > data.len - 8:
    failInvalid("truncated RIFF data")
  result.fileSize = riffSize + 8

  var pos = 12
  while pos < result.fileSize:
    if pos + 8 > result.fileSize:
      failInvalid("truncated chunk header")

    let
      fourcc = data.readStrChecked(pos, 4)
      size = data.readUint32le(pos + 4).int
      payloadOffset = pos + 8
    if size > result.fileSize - payloadOffset:
      failInvalid("truncated " & fourcc & " chunk")

    result.chunks.add(WebpChunkInfo(
      kind: fourcc.chunkKind(),
      fourcc: fourcc,
      offset: payloadOffset,
      size: size
    ))

    case fourcc
    of WebpVp8Signature:
      result.compression = LossyWebp
      result.vp8Offset = payloadOffset
      result.vp8Size = size
      data.parseVp8Dimensions(payloadOffset, size, result)
    of WebpVp8LSignature:
      result.compression = LosslessWebp
      result.vp8LOffset = payloadOffset
      result.vp8LSize = size
      data.parseVp8LDimensions(payloadOffset, size, result)
    of WebpVp8XSignature:
      data.parseVp8X(payloadOffset, size, result)
    of WebpAlphaSignature:
      result.alphaOffset = payloadOffset
      result.alphaSize = size
      data.parseAlpha(payloadOffset, size, result)
    of WebpAnimSignature:
      data.parseAnim(payloadOffset, size, result)
    of WebpAnimFrameSignature:
      data.parseAnimFrame(payloadOffset, size, result)
    of WebpIccpSignature:
      result.iccpOffset = payloadOffset
      result.iccpSize = size
      result.hasIccp = true
    of WebpExifSignature:
      result.exifOffset = payloadOffset
      result.exifSize = size
      result.hasExif = true
    of WebpXmpSignature:
      result.xmpOffset = payloadOffset
      result.xmpSize = size
      result.hasXmp = true
    else:
      discard

    pos = payloadOffset + size
    if (size and 1) != 0:
      if pos >= result.fileSize:
        failInvalid("missing chunk padding")
      inc pos

  checkImageSize(result.width, result.height)
  if result.compression == UnknownWebpCompression and result.frameCount == 0:
    failInvalid("missing image bitstream")

proc decodeWebpInfo*(
  data: pointer, len: int
): WebpInfo {.raises: [PixieError].} =
  ## Decodes WebP container and image-header information from memory.
  if len <= 0:
    failInvalid("empty buffer")
  var s = newString(len)
  copyMem(s[0].addr, data, len)
  decodeWebpInfo(s)

proc decodeWebpDimensions*(
  data: string
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes the WebP dimensions.
  let info = decodeWebpInfo(data)
  result.width = info.width
  result.height = info.height

proc decodeWebpDimensions*(
  data: pointer, len: int
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes the WebP dimensions.
  let info = decodeWebpInfo(data, len)
  result.width = info.width
  result.height = info.height

proc decodeWebp*(data: string): Image {.raises: [PixieError].} =
  ## Decodes a WebP image.
  let info = decodeWebpInfo(data)
  case info.compression
  of LosslessWebp:
    var rgbaData = decodeLosslessData(
      data, info.vp8LOffset, info.vp8LSize, info.width, info.height, false
    )
    if not info.losslessAlpha:
      for i in countup(3, rgbaData.len - 1, 4):
        rgbaData[i] = 255
    newImageFromRgbaBytes(rgbaData, info.width, info.height)
  of LossyWebp:
    var rgbaData = frameToRgbaBytes(
      decodeVp8Frame(data, info.vp8Offset, info.vp8Size, info.width, info.height)
    )
    if info.hasAlpha:
      if info.alphaOffset == 0:
        failInvalid("missing ALPH chunk")
      let alpha = decodeAlphaData(data, info)
      for i in 0 ..< info.width * info.height:
        rgbaData[i * 4 + 3] = alpha[i]
    newImageFromRgbaBytes(rgbaData, info.width, info.height)
  of UnknownWebpCompression:
    raise newException(PixieError, "Invalid WebP, animation decoding is not implemented")

{.pop.}

when defined(release):
  {.pop.}
