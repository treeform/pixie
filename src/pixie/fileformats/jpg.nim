import pixie/common, pixie/images, strutils

# See https://github.com/nothings/stb/blob/master/stb_image.h
# See http://www.vip.sugovica.hu/Sardi/kepnezo/JPEG%20File%20Layout%20and%20Format.htm

const
  jpgStartOfImage* = [0xFF.uint8, 0xD8]
  deZigZag = [
    0.uint8, 1, 8, 16, 9, 2, 3, 10,
    17, 24, 32, 25, 18, 11,  4,  5,
    12, 19, 26, 33, 40, 48, 41, 34,
    27, 20, 13,  6,  7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36,
    29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46,
    53, 60, 61, 54, 47, 55, 62, 63
  ]
  bitmasks = [ # (1 shr n) - 1
    0.uint32, 1, 3, 7, 15, 31, 63, 127, 255, 511,
    1023, 2047, 4095, 8191, 16383, 32767, 65535
  ]
  biases = [ # (-1 shl n) + 1
    0.int32, -1, -3, -7, -15, -31, -63, -127, -255,
    -511, -1023, -2047, -4095, -8191, -16383, -32767
  ]

type
  Huffman = object
    symbols: array[256, uint8]
    deltas: array[17, int]
    maxCodes: array[18, int]

  Component = object
    id, quantizationTable: uint8
    verticalSamplingFactor, horizontalSamplingFactor: int
    width, height: int
    w2, h2: int # TODO what are these
    huffmanDC, huffmanAC: int
    dcPred: int

  DecoderState = object
    buffer: seq[uint8]
    pos, bitCount: int
    bits: uint32
    imageHeight, imageWidth: int
    quantizationTables: array[4, array[64, uint8]]
    huffmanTables: array[2, array[4, Huffman]] # 0 = DC, 1 = AC
    components: array[3, Component]
    maxHorizontalSamplingFactor, maxVerticalSamplingFactor: int
    mcuWidth, mcuHeight, numMcuWide, numMcuHigh: int
    componentOrder: array[3, int]
    hitEOI: bool

template failInvalid() =
  raise newException(PixieError, "Invalid JPG buffer, unable to load")

proc readUint8(state: var DecoderState): uint8 {.inline.} =
  if state.pos >= state.buffer.len:
    failInvalid()
  result = state.buffer[state.pos]
  inc state.pos

proc readUint16be(state: var DecoderState): uint16 =
  (state.readUint8().uint16 shl 8) or state.readUint8()

proc skipBytes(state: var DecoderState, n: int) =
  if state.pos + n > state.buffer.len:
    failInvalid()
  state.pos += n

proc seekToMarker(state: var DecoderState): uint8 =
  var x = state.readUint8()
  while x != 0xFF:
    x = state.readUint8()
  while x == 0xFF:
    x = state.readUint8()
  x

proc decodeDQT(state: var DecoderState) =
  var len = state.readUint16be() - 2
  while len > 0:
    let
      info = state.readUint8()
      table = info and 15
      precision = info shr 4

    if precision != 0:
      raise newException(
        PixieError, "Unsuppored JPG qantization table precision"
      )

    if table > 3:
      failInvalid()

    for i in 0 ..< 64:
      state.quantizationTables[table][deZigZag[i]] = state.readUint8()

    len -= 65

  if len != 0:
    failInvalid()

proc decodeDHT(state: var DecoderState) =
  proc buildHuffman(huffman: var Huffman, counts: array[16, uint8]) =
    var sizes: array[257, uint8]
    block:
      var k: int
      for i in 0.uint8 ..< 16:
        for j in 0.uint8 ..< counts[i]:
          sizes[k] = i + 1
          inc k
      sizes[k] = 0

    var code, j: int
    for i in 1.uint8 .. 16:
      huffman.deltas[i] = j - code
      if sizes[j] == i:
        while sizes[j] == i:
          inc code
          inc j
        if code - 1 >= 1 shl i:
          failInvalid()
      huffman.maxCodes[i] = code shl (16 - i)
      code = code shl 1
    huffman.maxCodes[17] = int.high

  var len = state.readUint16be() - 2
  while len > 0:
    let
      info = state.readUint8()
      table = info and 15
      tableCurrent = info shr 4 # DC or AC

    if tableCurrent > 1 or table > 3:
      failInvalid()

    var
      counts: array[16, uint8]
      numSymbols: uint8
    for i in 0 ..< 16:
      counts[i] = state.readUint8()
      numSymbols += counts[i]

    len -= 17

    state.huffmanTables[tableCurrent][table].buildHuffman(counts)

    for i in 0.uint8 ..< numSymbols:
      state.huffmanTables[tableCurrent][table].symbols[i] = state.readUint8()

    len -= numSymbols

  if len != 0:
    failInvalid()

proc decodeSegment(state: var DecoderState, marker: uint8) =
  case marker:
  of 0xDB: # Define Quantanization Table(s)
    state.decodeDQT()
  of 0xC4: # Define Huffman Tables
    state.decodeDHT()
  else:
    if (marker >= 0xE0 and marker <= 0xEF) or marker == 0xFE:
      let len = state.readUint16be() - 2
      state.skipBytes(len.int)
    else:
      raise newException(
        PixieError, "Unexpected JPG segment marker " & toHex(marker)
      )

proc decodeSOF(state: var DecoderState) =
  var len = state.readUint16be() - 2

  let precision = state.readUint8()
  if precision != 8:
    raise newException(PixieError, "Unsupported JPG bit depth, must be 8")

  state.imageHeight = state.readUint16be().int
  state.imageWidth = state.readUint16be().int

  if state.imageHeight == 0 or state.imageWidth == 0:
    failInvalid()

  let components = state.readUint8()
  if components != 3:
    raise newException(PixieError, "Unsupported JPG component count, must be 3")

  len -= 15

  if len != 0:
    failInvalid()

  for i in 0 ..< 3:
    state.components[i].id = state.readUint8()
    let
      info = state.readUint8()
      vertical = info and 15
      horizontal = info shr 4
      quantizationTable = state.readUint8()

    if quantizationTable > 3:
      failInvalid()

    if vertical == 0 or vertical > 4 or horizontal == 0 or horizontal > 4:
      failInvalid()

    state.components[i].verticalSamplingFactor = vertical.int
    state.components[i].horizontalSamplingFactor = horizontal.int
    state.components[i].quantizationTable = quantizationTable

  for i in 0 ..< 3:
    state.maxVerticalSamplingFactor = max(
      state.maxVerticalSamplingFactor,
      state.components[i].verticalSamplingFactor
    )
    state.maxHorizontalSamplingFactor = max(
      state.maxHorizontalSamplingFactor,
      state.components[i].horizontalSamplingFactor
    )

  state.mcuWidth = state.maxHorizontalSamplingFactor * 8
  state.mcuHeight = state.maxVerticalSamplingFactor * 8
  state.numMcuWide =
    (state.imageWidth + state.mcuWidth - 1) div state.mcuWidth
  state.numMcuHigh =
    (state.imageHeight + state.mcuHeight - 1) div state.mcuHeight

  for i in 0 ..< 3:
    state.components[i].width = (
      state.imageWidth *
      state.components[i].horizontalSamplingFactor +
      state.maxHorizontalSamplingFactor - 1
    ) div state.maxHorizontalSamplingFactor
    state.components[i].height = (
      state.imageHeight *
      state.components[i].verticalSamplingFactor +
      state.maxVerticalSamplingFactor - 1
    ) div state.maxVerticalSamplingFactor

    state.components[i].w2 =
      state.numMcuWide * state.components[i].horizontalSamplingFactor * 8
    state.components[i].h2 =
      state.numMcuHigh * state.components[i].verticalSamplingFactor * 8

proc decodeSOS(state: var DecoderState) =
  var len = state.readUint16be() - 2

  let components = state.readUint8()
  if components != 3:
    raise newException(PixieError, "Unsupported JPG component count, must be 3")

  for i in 0 ..< 3:
    let
      id = state.readUint8()
      info = state.readUint8()
      huffmanAC = info and 15
      huffmanDC = info shr 4

    if huffmanAC > 3 or huffmanDC > 3:
      failInvalid()

    var component: int
    while component < 3:
      if state.components[component].id == id:
        break
      inc component
    if component == 3:
      failInvalid() # Not found

    state.components[component].huffmanAC = huffmanAC.int
    state.components[component].huffmanDC = huffmanDC.int
    state.componentOrder[i] = component

  # Skip 3 bytes
  for i in 0 ..< 3:
    discard state.readUint8()

  len -= 10

  if len != 0:
    failInvalid()

proc fillBits(state: var DecoderState) =
  while state.bitCount <= 24:
    let b = if state.hitEOI: 0.uint32 else: state.readUint8().uint32
    if b == 0xFF:
      let c = state.readUint8()
      if c == 0:
        discard
      elif c == 0xD9:
        state.hitEOI = true
      else:
        failInvalid()
    state.bits = state.bits or (b shl (24 - state.bitCount))
    state.bitCount += 8

proc huffmanDecode(state: var DecoderState, tableCurrent, table: int): uint8 =
  if state.bitCount < 16:
    state.fillBits()

  var
    tmp = (state.bits shr 16).int
    i = 1
  while i < state.huffmanTables[tableCurrent][table].maxCodes.len:
    if tmp < state.huffmanTables[tableCurrent][table].maxCodes[i]:
      break
    inc i

  if i == 17 or i > state.bitCount:
    failInvalid()

  let symbolId = (state.bits shr (32 - i)).int +
    state.huffmanTables[tableCurrent][table].deltas[i]
  result = state.huffmanTables[tableCurrent][table].symbols[symbolId]

  state.bits = state.bits shl i
  state.bitCount -= i

  echo "post-decode: ", state.bitCount, " ", state.bits

template lrot(value: uint32, shift: int): uint32 =
  (value shl shift) or (value shr (32 - shift))

proc extendReceive(state: var DecoderState, t: int): int =
  if state.bitCount < t:
    state.fillBits()

  let sign = (state.bits shr 31).int32
  var k = lrot(state.bits, t)
  state.bits = k and (not bitmasks[t])
  k = k and bitmasks[t]
  state.bitCount -= t
  result = k.int + (biases[t] and (not sign))
  echo "sgn: ", sign
  echo "post: ", state.bits

proc decodeImageBlock(state: var DecoderState, component: int): array[64, int16] =
  let t = state.huffmanDecode(0, state.components[component].huffmanDC).int
  if t < 0:
    failInvalid()

  echo "t: ", t

  let
    diff = if t == 0: 0 else: state.extendReceive(t)
    dc = state.components[component].dcPred + diff
  state.components[component].dcPred = dc
  result[0] = (dc * state.quantizationTables[
    state.components[component].quantizationTable
  ][0].int).int16

  echo "data[0]: ", result[0]

proc decodeImageData(state: var DecoderState) =
  for y in 0 ..< state.numMcuHigh:
    for x in 0 ..< state.numMcuWide:
      for component in state.componentOrder:
        for j in 0 ..< state.components[component].verticalSamplingFactor:
          for i in 0 ..< state.components[component].horizontalSamplingFactor:
            let data = state.decodeImageBlock(component)
            return

proc decodeJpg*(data: seq[uint8]): Image =
  ## Decodes the JPEG into an Image.

  var state = DecoderState()
  state.buffer = data

  if state.readUint8() != 0xFF or state.readUint8() != 0xD8: # SOI
    failInvalid()

  var marker = state.seekToMarker()
  while marker != 0xC0: # SOF
    state.decodeSegment(marker)
    marker = state.seekToMarker()

  state.decodeSOF()

  marker = state.seekToMarker()
  while marker != 0xDA: # Start of Scan
    state.decodeSegment(marker)
    marker = state.seekToMarker()

  state.decodeSOS()

  state.decodeImageData()

  # raise newException(PixieError, "Decoding JPG not supported yet")

proc decodeJpg*(data: string): Image {.inline.} =
  decodeJpg(cast[seq[uint8]](data))

proc encodeJpg*(image: Image): string =
  raise newException(PixieError, "Encoding JPG not supported yet")
