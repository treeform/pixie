import pixie/common, pixie/images, strutils

# See https://github.com/nothings/stb/blob/master/stb_image.h

const
  fastBits = 9
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
    codes: array[256, uint16]
    symbols: array[256, uint8]
    sizes: array[257, uint8]
    deltas: array[17, int]
    maxCodes: array[18, int]
    fast: array[1 shl fastBits, uint8]

  ResampleProc = proc(dst, line0, line1: ptr UncheckedArray[uint8],
    widthPreExpansion, horizontalExpansionFactor: int
  ): ptr UncheckedArray[uint8]

  Resample = object
    horizontalExpansionFactor, verticalExpansionFactor: int
    yStep, yPos, widthPreExpansion: int
    line0, line1: ptr UncheckedArray[uint8]
    resample: ResampleProc

  Component = object
    id, quantizationTable: uint8
    horizontalSamplingFactor, verticalSamplingFactor: int
    width, height: int
    widthStride, heightStride: int
    huffmanDC, huffmanAC: int
    dcPred: int
    widthCoeff, heightCoeff: int
    data, coeff, lineBuf: seq[uint8]

  DecoderState = object
    buffer: seq[uint8]
    pos, bitCount: int
    bits: uint32
    imageHeight, imageWidth: int
    quantizationTables: array[4, array[64, uint8]]
    huffmanTables: array[2, array[4, Huffman]] # 0 = DC, 1 = AC
    components: array[3, Component]
    scanComponents: int
    spectralStart, spectralEnd: int
    successiveApproxLow, successiveApproxHigh: int
    maxHorizontalSamplingFactor, maxVerticalSamplingFactor: int
    mcuWidth, mcuHeight, numMcuWide, numMcuHigh: int
    componentOrder: array[3, int]
    progressive, hitEOI: bool

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
    block:
      var k: int
      for i in 0.uint8 ..< 16:
        for j in 0.uint8 ..< counts[i]:
          huffman.sizes[k] = i + 1
          inc k
      huffman.sizes[k] = 0

    var code, j: int
    for i in 1.uint8 .. 16:
      huffman.deltas[i] = j - code
      if huffman.sizes[j] == i:
        while huffman.sizes[j] == i:
          huffman.codes[j] = code.uint16
          inc code
          inc j
        if code - 1 >= 1 shl i:
          failInvalid()
      huffman.maxCodes[i] = code shl (16 - i)
      code = code shl 1
    huffman.maxCodes[17] = int.high

    for i in 0 ..< huffman.fast.len:
      huffman.fast[i] = 255

    for i in 0 ..< j:
      let size = huffman.sizes[i]
      if size <= fastBits:
        let fast = huffman.codes[i].int shl (fastBits - size)
        for k in 0 ..< 1 shl (fastBits - size):
          huffman.fast[fast + k] = i.uint8

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

    state.components[i].widthStride =
      state.numMcuWide * state.components[i].horizontalSamplingFactor * 8
    state.components[i].heightStride =
      state.numMcuHigh * state.components[i].verticalSamplingFactor * 8

    state.components[i].data.setLen(
      state.components[i].widthStride * state.components[i].heightStride
    )

    if state.progressive:
      state.components[i].widthCoeff = state.components[i].widthStride div 8
      state.components[i].heightCoeff = state.components[i].heightStride div 8
      state.components[i].coeff.setLen(
        state.components[i].widthStride * state.components[i].heightStride
      )

proc decodeSOS(state: var DecoderState) =
  var len = state.readUint16be() - 2

  state.scanComponents = state.readUint8().int

  if state.scanComponents notin [1, 3]:
    raise newException(PixieError, "Unsupported JPG scan component count")

  if not state.progressive and state.scanComponents != 3:
    raise newException(PixieError, "Unsupported JPG scan component count")

  for i in 0 ..< state.scanComponents:
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

  state.spectralStart = state.readUint8().int
  state.spectralEnd = state.readUint8().int

  let aa = state.readUint8().int
  state.successiveApproxLow = aa and 15
  state.successiveApproxHigh = aa shr 4

  if state.progressive:
    if state.spectralStart > 63 or state.spectralEnd > 63:
      failInvalid()
    if state.spectralEnd > state.spectralEnd:
      failInvalid()
    if state.successiveApproxHigh > 13 or state.successiveApproxLow > 13:
      failInvalid()
  else:
    if state.spectralStart != 0:
      failInvalid()
    if state.successiveApproxHigh != 0 or state.successiveApproxLow != 0:
      failInvalid()
    state.spectralEnd = 63

  len -= 4 + 2 * state.scanComponents.uint16

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

  let
    fastId = (state.bits shr (32 - fastBits)) and ((1 shl fastBits) - 1)
    fast = state.huffmanTables[tableCurrent][table].fast[fastId]
  if fast < 255:
    let size = state.huffmanTables[tableCurrent][table].sizes[fast].int
    if size > state.bitCount:
      failInvalid()

    result = state.huffmanTables[tableCurrent][table].symbols[fast]
    state.bits = state.bits shl size
    state.bitCount -= size
  else:
    var
      tmp = (state.bits shr 16).int
      i = fastBits + 1
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

template lrot(value: uint32, shift: int): uint32 =
  (value shl shift) or (value shr (32 - shift))

proc extendReceive(state: var DecoderState, t: int): int {.inline.} =
  if state.bitCount < t:
    state.fillBits()

  let sign = cast[int32](state.bits) shr 31
  var k = lrot(state.bits, t)
  state.bits = k and (not bitmasks[t])
  k = k and bitmasks[t]
  state.bitCount -= t
  result = k.int + (biases[t] and (not sign))

proc decodeBlock(
  state: var DecoderState, component: int
): array[64, int16] =
  let t = state.huffmanDecode(0, state.components[component].huffmanDC).int
  if t < 0:
    failInvalid()

  let
    diff = if t == 0: 0 else: state.extendReceive(t)
    dc = state.components[component].dcPred + diff
  state.components[component].dcPred = dc
  result[0] = (dc * state.quantizationTables[
    state.components[component].quantizationTable
  ][0].int).int16

  var i = 1
  while i < 64:
    if state.bitCount < 16:
      state.fillBits()
    let
      rs = state.huffmanDecode(1, state.components[component].huffmanAC)
      s = rs and 15
      r = rs shr 4
    if s == 0:
      if rs != 0xF0:
        break
      i += 16
    else:
      i += r.int
      let zig = deZigZag[i]
      result[zig] = (state.extendReceive(s.int) * state.quantizationTables[
        state.components[component].quantizationTable
      ][zig].int).int16
      inc i

proc clamp(x: int): uint8 {.inline.} =
  if cast[uint](x) > 255:
    if x < 0:
      return 0
    if x > 255:
      return 255
  x.uint8

template idct1D(s0, s1, s2, s3, s4, s5, s6, s7: int32) =
  template f2f(x: float32): int32 = (x * 4096 + 0.5).int32
  template fsh(x: int32): int32 = x * 4096
  p2 = s2
  p3 = s6
  p1 = (p2 + p3) * f2f(0.5411961f)
  t2 = p1 + p3*f2f(-1.847759065f)
  t3 = p1 + p2*f2f(0.765366865f)
  p2 = s0
  p3 = s4
  t0 = fsh(p2 + p3)
  t1 = fsh(p2 - p3)
  x0 = t0 + t3
  x3 = t0 - t3
  x1 = t1 + t2
  x2 = t1 - t2
  t0 = s7
  t1 = s5
  t2 = s3
  t3 = s1
  p3 = t0 + t2
  p4 = t1 + t3
  p1 = t0 + t3
  p2 = t1 + t2
  p5 = (p3 + p4) * f2f(1.175875602f)
  t0 = t0 * f2f(0.298631336f)
  t1 = t1 * f2f(2.053119869f)
  t2 = t2 * f2f(3.072711026f)
  t3 = t3 * f2f(1.501321110f)
  p1 = p5 + p1*f2f(-0.899976223f)
  p2 = p5 + p2*f2f(-2.562915447f)
  p3 = p3 * f2f(-1.961570560f)
  p4 = p4 * f2f(-0.390180644f)
  t3 += p1 + p4
  t2 += p2 + p3
  t1 += p2 + p4
  t0 += p1 + p3

proc idctBlock(component: var Component, offset: int, data: array[64, int16]) =
  var values: array[64, int32]
  for i in 0 ..< 8:
    if data[i + 8] == 0 and
      data[i + 16] == 0 and
      data[i + 24] == 0 and
      data[i + 32] == 0 and
      data[i + 40] == 0 and
      data[i + 48] == 0 and
      data[i + 56] == 0:
      let dcterm = data[i] * 4
      values[i + 0] = dcterm
      values[i + 8] = dcterm
      values[i + 16] = dcterm
      values[i + 24] = dcterm
      values[i + 32] = dcterm
      values[i + 40] = dcterm
      values[i + 48] = dcterm
      values[i + 56] = dcterm
    else:
      var t0, t1, t2, t3, p1, p2, p3, p4, p5, x0, x1, x2, x3: int32
      idct1D(
        data[i + 0],
        data[i + 8],
        data[i + 16],
        data[i + 24],
        data[i + 32],
        data[i + 40],
        data[i + 48],
        data[i + 56]
      )
      x0 += 512
      x1 += 512
      x2 += 512
      x3 += 512
      values[i + 0] = (x0 + t3) shr 10
      values[i + 56] = (x0 - t3) shr 10
      values[i + 8] = (x1 + t2) shr 10
      values[i + 48] = (x1 - t2) shr 10
      values[i + 16] = (x2 + t1) shr 10
      values[i + 40] = (x2 - t1) shr 10
      values[i + 24] = (x3 + t0) shr 10
      values[i + 32] = (x3 - t0) shr 10

  for i in 0 ..< 8:
    let
      valuesPos = i * 8
      outPos = i * component.widthStride + offset

    var t0, t1, t2, t3, p1, p2, p3, p4, p5, x0, x1, x2, x3: int32
    idct1D(
      values[valuesPos + 0],
      values[valuesPos + 1],
      values[valuesPos + 2],
      values[valuesPos + 3],
      values[valuesPos + 4],
      values[valuesPos + 5],
      values[valuesPos + 6],
      values[valuesPos + 7]
    )

    x0 += 65536 + (128 shl 17)
    x1 += 65536 + (128 shl 17)
    x2 += 65536 + (128 shl 17)
    x3 += 65536 + (128 shl 17)

    component.data[outPos + 0] = clamp((x0 + t3) shr 17)
    component.data[outPos + 7] = clamp((x0 - t3) shr 17)
    component.data[outPos + 1] = clamp((x1 + t2) shr 17)
    component.data[outPos + 6] = clamp((x1 - t2) shr 17)
    component.data[outPos + 2] = clamp((x2 + t1) shr 17)
    component.data[outPos + 5] = clamp((x2 - t1) shr 17)
    component.data[outPos + 3] = clamp((x3 + t0) shr 17)
    component.data[outPos + 4] = clamp((x3 - t0) shr 17)

proc idctBlockDC(component: var Component, offset: int) =
  discard

proc decodeScanData(state: var DecoderState) =
  if state.progressive:
    if state.scanComponents == 1:
      discard
    else:
      discard
  else:
    for y in 0 ..< state.numMcuHigh:
      for x in 0 ..< state.numMcuWide:
        for comp in state.componentOrder:
          for j in 0 ..< state.components[comp].verticalSamplingFactor:
            for i in 0 ..< state.components[comp].horizontalSamplingFactor:
              let
                data = state.decodeBlock(comp)
                rowPos = (
                  x * state.components[comp].horizontalSamplingFactor + i
                ) * 8
                column = (
                  y * state.components[comp].verticalSamplingFactor + j
                ) * 8
              state.components[comp].idctBlock(
                state.components[comp].widthStride * column + rowPos,
                data
              )

proc finishProgressive(state: var DecoderState) =
  discard

proc resampleRowH1V1(
  dst, a, b: ptr UncheckedArray[uint8],
  widthPreExpansion, horizontalExpansionFactor: int
): ptr UncheckedArray[uint8] =
  a

proc resampleRowH1V2(
  dst, a, b: ptr UncheckedArray[uint8],
  widthPreExpansion, horizontalExpansionFactor: int
): ptr UncheckedArray[uint8] =
  for i in 0 ..< widthPreExpansion:
    dst[i] = ((3 * a[i].int + b[i].int + 2) shr 2).uint8
  dst

proc resampleRowH2V1(
  dst, a, b: ptr UncheckedArray[uint8],
  widthPreExpansion, horizontalExpansionFactor: int
): ptr UncheckedArray[uint8] =
  if widthPreExpansion == 1:
    dst[0] = a[0]
    dst[1] = dst[0]
  else:
    dst[0] = a[0]
    dst[1] = ((a[0].int * 3 + a[1].int + 2) shr 2).uint8
    for i in 1 ..< widthPreExpansion - 1:
      let n = 3 * a[i].int + 2
      dst[i * 2 + 0] = ((n + a[i - 1].int) shr 2).uint8
      dst[i * 2 + 1] = ((n + a[i + 1].int) shr 2).uint8

    dst[widthPreExpansion * 2 + 0] = ((
      a[widthPreExpansion - 2].int * 3 + a[widthPreExpansion - 1].int + 2
    ) shr 2).uint8
    dst[widthPreExpansion * 2 + 1] = (a[widthPreExpansion - 1]) shr 2
  dst

proc resampleRowH2V2(
  dst, a, b: ptr UncheckedArray[uint8],
  widthPreExpansion, horizontalExpansionFactor: int
): ptr UncheckedArray[uint8] =
  if widthPreExpansion == 1:
    dst[0] = ((3 * a[0].int + b[0].int + 2) shr 2).uint8
    dst[1] = dst[0]
  else:
    var
      t0: int
      t1 = 3 * a[0].int + b[0].int
    dst[0] = ((t1 + 2) shr 2).uint8
    for i in 1 ..< widthPreExpansion:
      t0 = t1
      t1 = 3 * a[i].int + b[i].int
      dst[i * 2 - 1] = ((3 * t0 + t1 + 8) shr 4).uint8
      dst[i * 2 + 0] = ((3 * t1 + t0 + 8) shr 4).uint8
    dst[widthPreExpansion * 2 - 1] = ((t1 + 2) shr 2).uint8
  dst

proc yCbCrToRgb(dst, py, pcb, pcr: ptr UncheckedArray[uint8], width: int) =
  template float2Fixed(x: float32): int =
    (x * 4096 + 0.5).int shl 8

  var pos: int
  for i in 0 ..< width:
    let
      yFixed = (py[][i].int shl 20) + (1 shl 19)
      cb = pcb[][i].int - 128
      cr = pcr[][i].int - 128
    var
      r = yFixed + cr * float2Fixed(1.40200)
      g = yFixed +
        (cr * -float2Fixed(0.71414)) +
        ((cb * -float2Fixed(0.34414)) and -65536)
      b = yFixed + cb * float2Fixed(1.77200)
    dst[pos + 0] = clamp(r shr 20)
    dst[pos + 1] = clamp(g shr 20)
    dst[pos + 2] = clamp(b shr 20)
    dst[pos + 3] = 255
    pos += 4

proc decodeJpg*(data: seq[uint8]): Image =
  ## Decodes the JPEG into an Image.

  var state = DecoderState()
  state.buffer = data

  if state.readUint8() != 0xFF or state.readUint8() != 0xD8: # SOI
    failInvalid()

  var marker = state.seekToMarker()
  while marker != 0xC0 and marker != 0xC1 and marker != 0xC2:
    # Baseline DCT or Extended DCT or Progressive DCT
    state.decodeSegment(marker)
    marker = state.seekToMarker()

  state.progressive = marker == 0xC2
  state.decodeSOF()

  while true:
    marker = state.seekToMarker()
    if marker == 0xDA: # Start of Scan
      state.decodeSOS()
      state.decodeScanData()
    else:
      state.decodeSegment(marker)
    if state.hitEOI:
      break

  if state.progressive:
    state.finishProgressive()

  result = newImage(state.imageWidth, state.imageHeight)

  var resamples: array[3, Resample]
  for i in 0 ..< 3:
    resamples[i].horizontalExpansionFactor =
      state.maxHorizontalSamplingFactor div
      state.components[i].horizontalSamplingFactor
    resamples[i].verticalExpansionFactor =
      state.maxVerticalSamplingFactor div
      state.components[i].verticalSamplingFactor
    resamples[i].yStep = resamples[i].verticalExpansionFactor shr 1
    resamples[i].widthPreExpansion = (
      state.imageWidth + resamples[i].horizontalExpansionFactor - 1
    ) div resamples[i].horizontalExpansionFactor

    resamples[i].line0 = cast[ptr UncheckedArray[uint8]](
      state.components[i].data[0].addr
    )
    resamples[i].line1 = cast[ptr UncheckedArray[uint8]](
      state.components[i].data[0].addr
    )
    state.components[i].lineBuf.setLen(state.imageWidth + 3)

    if resamples[i].horizontalExpansionFactor == 1 and
      resamples[i].verticalExpansionFactor == 1:
      resamples[i].resample = resampleRowH1V1
    elif resamples[i].horizontalExpansionFactor == 1 and
      resamples[i].verticalExpansionFactor == 2:
      resamples[i].resample = resampleRowH1V2
    elif resamples[i].horizontalExpansionFactor == 2 and
      resamples[i].verticalExpansionFactor == 1:
      resamples[i].resample = resampleRowH2V1
    elif resamples[i].horizontalExpansionFactor == 2 and
      resamples[i].verticalExpansionFactor == 2:
      resamples[i].resample = resampleRowH2V2
    else:
      failInvalid()

  var componentOutputs: array[3, ptr UncheckedArray[uint8]]
  for y in 0 ..< state.imageHeight:
    for i in 0 ..< 3:
      let yBottom =
        resamples[i].yStep >= (resamples[i].verticalExpansionFactor shr 1)
      componentOutputs[i] = resamples[i].resample(
        cast[ptr UncheckedArray[uint8]](state.components[i].lineBuf[0].addr),
        if yBottom: resamples[i].line1 else: resamples[i].line0,
        if yBottom: resamples[i].line0 else: resamples[i].line1,
        resamples[i].widthPreExpansion,
        resamples[i].horizontalExpansionFactor
      )

      inc resamples[i].yStep
      if resamples[i].yStep >= resamples[i].verticalExpansionFactor:
        resamples[i].yStep = 0
        resamples[i].line0 = resamples[i].line1
        inc resamples[i].yPos
        if resamples[i].yPos < state.components[i].height:
          resamples[i].line1 = cast[ptr UncheckedArray[uint8]](
            state.components[i].data[
              resamples[i].yPos * state.components[i].widthStride
            ].addr
          )

    let dst = cast[ptr UncheckedArray[uint8]](
      result.data[state.imageWidth * y].addr
    )
    yCbCrToRgb(
      dst,
      componentOutputs[0],
      componentOutputs[1],
      componentOutputs[2],
      state.imageWidth
    )

proc decodeJpg*(data: string): Image {.inline.} =
  decodeJpg(cast[seq[uint8]](data))

proc encodeJpg*(image: Image): string =
  raise newException(PixieError, "Encoding JPG not supported yet")
