import flatty/binny, math, pixie/common, pixie/paths, tables, unicode, vmath

## See https://docs.microsoft.com/en-us/typography/opentype/spec/

export tables

type
  EncodingRecord* = object
    platformID*: uint16
    encodingID*: uint16
    offset*: uint32

  CmapTable* = ref object
    version*: uint16
    numTables*: uint16
    encodingRecords*: seq[EncodingRecord]
    runeToGlyphId*: Table[Rune, uint16]
    glyphIdToRune*: Table[uint16, Rune]

  HeadTable* = ref object
    majorVersion*: uint16
    minorVersion*: uint16
    fontRevision*: float32
    checkSumAdjustment*: uint32
    magicNumber*: uint32
    flags*: uint16
    unitsPerEm*: uint16
    created*: float64
    modified*: float64
    xMin*: int16
    yMin*: int16
    xMax*: int16
    yMax*: int16
    macStyle*: uint16
    lowestRecPPEM*: uint16
    fontDirectionHint*: int16
    indexToLocFormat*: int16
    glyphDataFormat*: int16

  HheaTable* = ref object
    majorVersion*: uint16
    minorVersion*: uint16
    ascender*: int16
    descender*: int16
    lineGap*: int16
    advanceWidthMax*: uint16
    minLeftSideBearing*: int16
    minRightSideBearing*: int16
    xMaxExtent*: int16
    caretSlopeRise*: int16
    caretSlopeRun*: int16
    caretOffset*: int16
    metricDataFormat*: int16
    numberOfHMetrics*: uint16

  MaxpTable* = ref object
    version*: float32
    numGlyphs*: uint16
    maxPoints*: uint16
    maxContours*: uint16
    maxCompositePoints*: uint16
    maxCompositeContours*: uint16
    maxZones*: uint16
    maxTwilightPoints*: uint16
    maxStorage*: uint16
    maxFunctionDefs*: uint16
    maxInstructionDefs*: uint16
    maxStackElements*: uint16
    maxSizeOfInstructions*: uint16
    maxComponentElements*: uint16
    maxComponentDepth*: uint16

  LongHorMetricRecord* = object
    advanceWidth*: uint16
    leftSideBearing*: int16

  HmtxTable* = ref object
    hMetrics*: seq[LongHorMetricRecord]
    leftSideBearings*: seq[int16]

  NameRecord* = object
    platformID*: uint16
    encodingID*: uint16
    languageID*: uint16
    nameID*: uint16
    length*: uint16
    offset*: uint16

  NameTable* = ref object
    format*: uint16
    count*: uint16
    stringOffset*: uint16
    nameRecords*: seq[NameRecord]

  OS2Table* = ref object
    version*: uint16
    xAvgCharWidth*: int16
    usWeightClass*: uint16
    usWidthClass*: uint16
    fsType*: uint16
    ySubscriptXSize*: int16
    ySubscriptYSize*: int16
    ySubscriptXOffset*: int16
    ySubscriptYOffset*: int16
    ySuperscriptXSize*: int16
    ySuperscriptYSize*: int16
    ySuperscriptXOffset*: int16
    ySuperscriptYOffset*: int16
    yStrikeoutSize*: int16
    yStrikeoutPosition*: int16
    sFamilyClass*: int16
    panose*: array[10, uint8]
    ulUnicodeRange1*: uint32
    ulUnicodeRange2*: uint32
    ulUnicodeRange3*: uint32
    ulUnicodeRange4*: uint32
    achVendID*: string
    fsSelection*: uint16
    usFirstCharIndex*: uint16
    usLastCharIndex*: uint16
    sTypoAscender*: int16
    sTypoDescender*: int16
    sTypoLineGap*: int16
    usWinAscent*: uint16
    usWinDescent*: uint16
    ulCodePageRange1*: uint32
    ulCodePageRange2*: uint32
    sxHeight*: int16
    sCapHeight*: int16
    usDefaultChar*: uint16
    usBreakChar*: uint16
    usMaxContext*: uint16
    usLowerOpticalPointSize*: uint16
    usUpperOpticalPointSize*: uint16

  LocaTable* = ref object
    offsets*: seq[uint32]

  GlyfTable* = ref object
    offsets*: seq[uint32]

  KernPair* = object
    left*: uint16
    right*: uint16
    value*: int16

  KernSubTable* = object
    version*: uint16
    length*: uint16
    coverage*: uint16
    nPairs*: uint16
    searchRange*: uint16
    entrySelector*: uint16
    rangeShift*: uint16
    kernPairs*: seq[KernPair]

  KernTable* = ref object
    version*: uint16
    nTables*: uint16
    subTables*: seq[KernSubTable]

  TableRecord* = object
    tag*: string
    checksum*: uint32
    offset*: uint32
    length*: uint32

  OpenType* = ref object
    buf*: string
    version*: uint32
    numTables*: uint16
    searchRange*: uint16
    entrySelector*: uint16
    rangeShift*: uint16
    tableRecords*: Table[string, TableRecord]
    cmap*: CmapTable
    head*: HeadTable
    hhea*: HheaTable
    maxp*: MaxpTable
    hmtx*: HmtxTable
    name*: NameTable
    os2*: OS2Table
    loca*: LocaTable
    glyf*: GlyfTable
    kern*: KernTable

proc eofCheck(buf: string, readTo: int) {.inline.} =
  if readTo > buf.len:
    raise newException(PixieError, "Unexpected error reading font data, EOF")

proc failUnsupported() =
  raise newException(PixieError, "Unsupported font data")

proc readUint16Seq(buf: string, offset, len: int): seq[uint16] =
  result = newSeq[uint16](len)
  for i in 0 ..< len:
    result[i] = buf.readUint16(offset + i * 2).swap()

proc readFixed32(buf: string, offset: int): float32 =
  ## Packed 32-bit value with major and minor version numbers.
  ceil(buf.readInt32(offset).swap().float32 / 65536.0 * 100000.0) / 100000.0

proc readFixed16(buf: string, offset: int): float32 =
  ## Reads 16-bit signed fixed number with the low 14 bits of fraction (2.14).
  buf.readInt16(offset).swap().float32 / 16384.0

proc readLongDateTime(buf: string, offset: int): float64 =
  ## Date and time represented in number of seconds since 12:00 midnight,
  ## January 1, 1904, UTC.
  buf.readInt64(offset).swap().float64 - 2082844800

proc parseCmapTable(buf: string, offset: int): CmapTable =
  var i = offset
  buf.eofCheck(i + 4)

  result = CmapTable()
  result.version = buf.readUint16(i + 0).swap()
  result.numTables = buf.readUint16(i + 2).swap()
  i += 4

  for j in 0 ..< result.numTables.int:
    buf.eofCheck(i + 8)

    var encodingRecord: EncodingRecord
    encodingRecord.platformID = buf.readUint16(i + 0).swap()
    encodingRecord.encodingID = buf.readUint16(i + 2).swap()
    encodingRecord.offset = buf.readUint32(i + 4).swap()
    i += 8

    if encodingRecord.platformID == 3:
      # Windows
      var i = offset + encodingRecord.offset.int
      buf.eofCheck(i + 2)

      let format = buf.readUint16(i + 0).swap()
      if format == 4:
        type Format4 = object
          format: uint16
          length: uint16
          language: uint16
          segCountX2: uint16
          searchRange: uint16
          entrySelector: uint16
          rangeShift: uint16
          endCodes: seq[uint16]
          reservedPad: uint16
          startCodes: seq[uint16]
          idDeltas: seq[uint16]
          idRangeOffsets: seq[uint16]

        buf.eofCheck(i + 14)

        var subTable: Format4
        subTable.format = format
        subTable.length = buf.readUint16(i + 2).swap()
        subTable.language = buf.readUint16(i + 4).swap()
        subTable.segCountX2 = buf.readUint16(i + 6).swap()
        let segCount = (subtable.segCountX2 div 2).int
        subTable.searchRange = buf.readUint16(i + 8).swap()
        subTable.entrySelector = buf.readUint16(i + 10).swap()
        subTable.rangeShift = buf.readUint16(i + 12).swap()
        i += 14

        buf.eofCheck(i + 2 + 4 * segCount * 2)

        subTable.endCodes = buf.readUint16Seq(i, segCount)
        i += segCount * 2
        subTable.reservedPad = buf.readUint16(i + 0).swap()
        i += 2
        subTable.startCodes = buf.readUint16Seq(i, segCount)
        i += segCount * 2
        subTable.idDeltas = buf.readUint16Seq(i, segCount)
        i += segCount * 2
        let idRangeOffsetPos = i
        subTable.idRangeOffsets = buf.readUint16Seq(i, segCount)
        i += segCount * 2

        for k in 0 ..< segCount:
          let
            endCode = subTable.endCodes[k]
            startCode = subTable.startCodes[k]
            idDelta = subTable.idDeltas[k].int
            idRangeOffset = subTable.idRangeOffsets[k].int
          for c in startCode .. endCode:
            var glyphId: int
            if idRangeOffset != 0:
              var glyphIdOffset = idRangeOffsetPos + k * 2
              glyphIdOffset += idRangeOffset
              glyphIdOffset += (c - startCode).int * 2
              buf.eofCheck(glyphIdOffset + 2)
              glyphId = buf.readUint16(glyphIdOffset).swap().int
              if glyphId != 0:
                glyphId = (glyphId + idDelta) and 0xFFFF
            else:
              glyphId = (c.int + idDelta) and 0xFFFF

            if c != 65535:
              result.runeToGlyphId[Rune(c)] = glyphId.uint16
              result.glyphIdToRune[glyphId.uint16] = Rune(c)
      else:
        # TODO implement other Windows encodingIDs
        discard
    else:
      # TODO implement other cmap platformIDs
      discard

proc parseHeadTable(buf: string, offset: int): HeadTable =
  buf.eofCheck(offset + 54)

  result = HeadTable()
  result.majorVersion = buf.readUint16(offset + 0).swap()
  if result.majorVersion != 1:
    failUnsupported()
  result.minorVersion = buf.readUint16(offset + 2).swap()
  if result.minorVersion != 0:
    failUnsupported()
  result.fontRevision = buf.readFixed32(offset + 4)
  result.checkSumAdjustment = buf.readUint32(offset + 8).swap()
  result.magicNumber = buf.readUint32(offset + 12).swap()
  result.flags = buf.readUint16(offset + 16).swap()
  result.unitsPerEm = buf.readUint16(offset + 18).swap()
  result.created = buf.readLongDateTime(offset + 20)
  result.modified = buf.readLongDateTime(offset + 28)
  result.xMin = buf.readInt16(offset + 36).swap()
  result.yMin = buf.readInt16(offset + 38).swap()
  result.xMax = buf.readInt16(offset + 40).swap()
  result.yMax = buf.readInt16(offset + 42).swap()
  result.macStyle = buf.readUint16(offset + 44).swap()
  result.lowestRecPPEM = buf.readUint16(offset + 46).swap()
  result.fontDirectionHint = buf.readInt16(offset + 48).swap()
  result.indexToLocFormat = buf.readInt16(offset + 50).swap()
  result.glyphDataFormat = buf.readInt16(offset + 52).swap()
  if result.glyphDataFormat != 0:
    failUnsupported()

proc parseHheaTable(buf: string, offset: int): HheaTable =
  buf.eofCheck(offset + 36)

  result = HheaTable()
  result.majorVersion = buf.readUint16(offset + 0).swap()
  if result.majorVersion != 1:
    failUnsupported()
  result.minorVersion = buf.readUint16(offset + 2).swap()
  if result.minorVersion != 0:
    failUnsupported()
  result.ascender = buf.readInt16(offset + 4).swap()
  result.descender = buf.readInt16(offset + 6).swap()
  result.lineGap = buf.readInt16(offset + 8).swap()
  result.advanceWidthMax = buf.readUint16(offset + 10).swap()
  result.minLeftSideBearing = buf.readInt16(offset + 12).swap()
  result.minRightSideBearing = buf.readInt16(offset + 14).swap()
  result.xMaxExtent = buf.readInt16(offset + 16).swap()
  result.caretSlopeRise = buf.readInt16(offset + 18).swap()
  result.caretSlopeRun = buf.readInt16(offset + 20).swap()
  result.caretOffset = buf.readInt16(offset + 22).swap()
  discard buf.readUint16(offset + 24).swap() # Reserved, discard
  discard buf.readUint16(offset + 26).swap() # Reserved, discard
  discard buf.readUint16(offset + 28).swap() # Reserved, discard
  discard buf.readUint16(offset + 30).swap() # Reserved, discard
  result.metricDataFormat = buf.readInt16(offset + 32).swap()
  if result.metricDataFormat != 0:
    failUnsupported()
  result.numberOfHMetrics = buf.readUint16(offset + 34).swap()

proc parseMaxpTable(buf: string, offset: int): MaxpTable =
  buf.eofCheck(offset + 32)

  result = MaxpTable()
  result.version = buf.readFixed32(offset + 0)
  if result.version != 1.0:
    failUnsupported()
  result.numGlyphs = buf.readUint16(offset + 4).swap()
  result.maxPoints = buf.readUint16(offset + 6).swap()
  result.maxContours = buf.readUint16(offset + 8).swap()
  result.maxCompositePoints = buf.readUint16(offset + 10).swap()
  result.maxCompositeContours = buf.readUint16(offset + 12).swap()
  result.maxZones = buf.readUint16(offset + 14).swap()
  result.maxTwilightPoints = buf.readUint16(offset + 16).swap()
  result.maxStorage = buf.readUint16(offset + 18).swap()
  result.maxFunctionDefs = buf.readUint16(offset + 20).swap()
  result.maxInstructionDefs = buf.readUint16(offset + 22).swap()
  result.maxStackElements = buf.readUint16(offset + 24).swap()
  result.maxSizeOfInstructions = buf.readUint16(offset + 26).swap()
  result.maxComponentElements = buf.readUint16(offset + 28).swap()
  result.maxComponentDepth = buf.readUint16(offset + 30).swap()

proc parseHmtxTable(
  buf: string, offset: int, hhea: HheaTable, maxp: MaxpTable
): HmtxTable =
  var i = offset

  let
    hMetricsSize = hhea.numberOfHMetrics.int * 4
    leftSideBearingsSize = (maxp.numGlyphs - hhea.numberOfHMetrics).int * 2

  buf.eofCheck(i + hMetricsSize + leftSideBearingsSize)

  result = HmtxTable()
  for glyph in 0 ..< maxp.numGlyphs.int:
    if glyph < hhea.numberOfHMetrics.int:
      var record = LongHorMetricRecord()
      record.advanceWidth = buf.readUint16(i + 0).swap()
      record.leftSideBearing = buf.readInt16(i + 2).swap()
      result.hMetrics.add(record)
      i += 4
    else:
      result.leftSideBearings.add(buf.readInt16(i).swap())
      i += 2

proc parseNameTable(buf: string, offset: int): NameTable =
  var i = offset

  buf.eofCheck(i + 6)

  result = NameTable()
  result.format = buf.readUint16(i + 0).swap()
  if result.format != 0:
    failUnsupported()
  result.count = buf.readUint16(i + 2).swap()
  result.stringOffset = buf.readUint16(i + 4).swap()

  i += 6

  buf.eofCheck(i + result.count.int * 12)

  for j in 0 ..< result.count.int:
    var record: NameRecord
    record.platformID = buf.readUint16(i + 0).swap()
    record.encodingID = buf.readUint16(i + 2).swap()
    record.languageID = buf.readUint16(i + 4).swap()
    record.nameID = buf.readUint16(i + 6).swap()
    record.length = buf.readUint16(i + 8).swap()
    record.offset = buf.readUint16(i + 10).swap()
    i += 12

proc parseOS2Table(buf: string, offset: int): OS2Table =
  var i = offset

  buf.eofCheck(i + 78)

  result = OS2Table()
  result.version = buf.readUint16(i + 0).swap()
  result.xAvgCharWidth = buf.readInt16(i + 2).swap()
  result.usWeightClass = buf.readUint16(i + 4).swap()
  result.usWidthClass = buf.readUint16(i + 6).swap()
  result.fsType = buf.readUint16(i + 8).swap()
  result.ySubscriptXSize = buf.readInt16(i + 10).swap()
  result.ySubscriptYSize = buf.readInt16(i + 12).swap()
  result.ySubscriptXOffset = buf.readInt16(i + 14).swap()
  result.ySubscriptYOffset = buf.readInt16(i + 16).swap()
  result.ySuperscriptXSize = buf.readInt16(i + 18).swap()
  result.ySuperscriptYSize = buf.readInt16(i + 20).swap()
  result.ySuperscriptXOffset = buf.readInt16(i + 22).swap()
  result.ySuperscriptYOffset = buf.readInt16(i + 24).swap()
  result.yStrikeoutSize = buf.readInt16(i + 26).swap()
  result.yStrikeoutPosition = buf.readInt16(i + 28).swap()
  result.sFamilyClass = buf.readInt16(i + 30).swap()
  i += 32
  for i in 0 ..< 10:
    result.panose[i] = buf.readUint8(i + i)
  i += 10
  result.ulUnicodeRange1 = buf.readUint32(i + 0).swap()
  result.ulUnicodeRange2 = buf.readUint32(i + 4).swap()
  result.ulUnicodeRange3 = buf.readUint32(i + 8).swap()
  result.ulUnicodeRange4 = buf.readUint32(i + 12).swap()
  result.achVendID = buf.readStr(i + 16, 4)
  result.fsSelection = buf.readUint16(i + 20).swap()
  result.usFirstCharIndex = buf.readUint16(i + 22).swap()
  result.usLastCharIndex = buf.readUint16(i + 24).swap()
  result.sTypoAscender = buf.readInt16(i + 26).swap()
  result.sTypoDescender = buf.readInt16(i + 28).swap()
  result.sTypoLineGap = buf.readInt16(i + 30).swap()
  result.usWinAscent = buf.readUint16(i + 32).swap()
  result.usWinDescent = buf.readUint16(i + 34).swap()
  i += 36

  if result.version >= 1.uint16:
    buf.eofCheck(i + 8)
    result.ulCodePageRange1 = buf.readUint32(i + 0).swap()
    result.ulCodePageRange2 = buf.readUint32(i + 4).swap()
    i += 8

  if result.version >= 2.uint16:
    buf.eofCheck(i + 10)
    result.sxHeight = buf.readInt16(i + 0).swap()
    result.sCapHeight = buf.readInt16(i + 2).swap()
    result.usDefaultChar = buf.readUint16(i + 4).swap()
    result.usBreakChar = buf.readUint16(i + 6).swap()
    result.usMaxContext = buf.readUint16(i + 8).swap()
    i += 10

  if result.version >= 5.uint16:
    buf.eofCheck(i + 4)
    result.usLowerOpticalPointSize = buf.readUint16(i + 0).swap()
    result.usUpperOpticalPointSize = buf.readUint16(i + 2).swap()
    i += 4

proc parseLocaTable(
  buf: string, offset: int, head: HeadTable, maxp: MaxpTable
): LocaTable =
  var i = offset

  result = LocaTable()
  if head.indexToLocFormat == 0:
    # uint16
    buf.eofCheck(i + maxp.numGlyphs.int * 2)
    for _ in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(buf.readUint16(i).swap().uint32 * 2)
      i += 2
  else:
    # uint32
    buf.eofCheck(i + maxp.numGlyphs.int * 4)
    for _ in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(buf.readUint32(i).swap())
      i += 4

proc parseGlyfTable(buf: string, offset: int, loca: LocaTable): GlyfTable =
  result = GlyfTable()
  result.offsets.setLen(loca.offsets.len)
  for glyphId in 0 ..< loca.offsets.len:
    result.offsets[glyphId] = offset.uint32 + loca.offsets[glyphId]

proc parseKernTable(buf: string, offset: int): KernTable =
  var i = offset

  buf.eofCheck(i + 2)

  result = KernTable()
  result.version = buf.readUint16(i + 0).swap()
  i += 2

  if result.version == 0:
    buf.eofCheck(i + 2)
    result.nTables = buf.readUint16(i + 0).swap()
    i += 2

    for _ in 0 ..< result.nTables.int:
      buf.eofCheck(i + 14)

      var subTable: KernSubTable
      subtable.version = buf.readUint16(i + 0).swap()
      if subTable.version != 0:
        failUnsupported()
      subTable.length = buf.readUint16(i + 2).swap()
      subTable.coverage = buf.readUint16(i + 4).swap()
      if subTable.coverage shr 8 != 0:
        failUnsupported()
      subTable.nPairs = buf.readUint16(i + 6).swap()
      subTable.searchRange = buf.readUint16(i + 8).swap()
      subTable.entrySelector = buf.readUint16(i + 10).swap()
      subTable.rangeShift = buf.readUint16(i + 12).swap()
      i += 14

      for _ in 0 ..< subTable.nPairs.int:
        buf.eofCheck(i + 6)

        var pair: KernPair
        pair.left = buf.readUint16(i + 0).swap()
        pair.right = buf.readUint16(i + 2).swap()
        pair.value = buf.readInt16(i + 4).swap()
        subTable.kernPairs.add(pair)
        i += 6

      result.subTables.add(subTable)
  elif result.version == 1:
    discard # Mac format
  else:
    failUnsupported()

proc getGlyphId*(opentype: OpenType, rune: Rune): uint16 =
  if rune in opentype.cmap.runeToGlyphId:
    result = opentype.cmap.runeToGlyphId[rune]
  else:
    discard # Index 0 is the "missing character" glyph

proc parseGlyph(opentype: OpenType, glyphId: uint16): Path

proc parseGlyphPath(buf: string, offset, numberOfContours: int): Path =
  if numberOfContours < 0:
    raise newException(PixieError, "Glyph numberOfContours must be >= 0")
  if numberOfContours == 0:
    return

  var i = offset

  buf.eofCheck(i + 2 * numberOfContours + 2)

  let endPtsOfContours = buf.readUint16Seq(i, numberOfContours)
  i += 2 * numberOfContours

  let instructionLength = buf.readUint16(i + 0).swap().int
  i += 2

  buf.eofCheck(instructionLength)

  # let instructions = buf.readUint8Seq(i, instructionLength)
  i += instructionLength

  let
    numPoints = endPtsOfContours[^1].int + 1
    flags = block:
      var
        flags: seq[uint8]
        point = 0
      while point < numPoints:
        buf.eofCheck(i + 1)
        let flag = buf.readUint8(i)
        flags.add(flag)
        i += 1
        point += 1

        if (flag and 0b1000) != 0: # REPEAT_FLAG
          buf.eofCheck(i + 1)
          let repeatCount = buf.readUint8(i).int
          i += 1
          for j in 0 ..< repeatCount:
            flags.add(flag)
            point += 1
      flags

  type TtfCoordinate = object
    x*: float32
    y*: float32
    isOnCurve*: bool

  var points = newSeq[TtfCoordinate](numPoints)

  var prevX = 0
  for point, flag in flags:
    var x: int
    if (flag and 0b10) != 0:
      buf.eofCheck(i + 1)
      x = buf.readUint8(i).int
      i += 1
      if (flag and 0b10000) == 0:
        x = -x
    else:
      if (flag and 0b10000) != 0:
        x = 0
      else:
        buf.eofCheck(i + 2)
        x = buf.readInt16(i).swap().int
        i += 2
    prevX += x
    points[point].x = prevX.float32
    points[point].isOnCurve = (flag and 1) != 0

  var prevY = 0
  for point, flag in flags:
    var y: int
    if (flag and 0b100) != 0:
      buf.eofCheck(i + 1)
      y = buf.readUint8(i).int
      i += 1
      if (flag and 0b100000) == 0:
        y = -y
    else:
      if (flag and 0b100000) != 0:
        y = 0
      else:
        buf.eofCheck(i + 2)
        y = buf.readInt16(i).swap().int
        i += 2
    prevY += y
    points[point].y = prevY.float32

  var
    contours: seq[seq[TtfCoordinate]]
    startIdx = 0
  for endIdx in endPtsOfContours:
    contours.add(points[startIdx .. endIdx.int])
    startIdx = endIdx.int + 1

  for contour in contours:
    var prev, curr, next: TtfCoordinate
    curr = contour[^1]
    next = contour[0]

    if curr.isOnCurve:
      result.moveTo(curr.x, curr.y)
    else:
      if next.isOnCurve:
        result.moveTo(next.x, next.y)
      else:
        result.moveTo((curr.x + next.x) / 2, (curr.y + next.y) / 2)

    for point in 0 ..< contour.len:
      prev = curr
      curr = next
      next = contour[(point + 1) mod contour.len]

      if curr.isOnCurve:
        result.lineTo(curr.x, curr.y)
      else:
        var next2 = next
        if not next.isOnCurve:
          next2 = TtfCoordinate(
            x: (curr.x + next.x) / 2,
            y: (curr.y + next.y) / 2
          )

        result.quadraticCurveTo(curr.x, curr.y, next2.x, next2.y)

    result.closePath()

proc parseCompositeGlyph(opentype: OpenType, offset: int): Path =
  var
    i = offset
    moreComponents = true
  while moreComponents:
    opentype.buf.eofCheck(i + 4)

    let flags = opentype.buf.readUint16(i + 0).swap()

    i += 2

    type TtfComponent = object
      glyphId: uint16
      xScale: float32
      scale01: float32
      scale10: float32
      yScale: float32
      dx: float32
      dy: float32
      matchedPoints: array[2, int]

    var component = TtfComponent()
    component.glyphId = opentype.buf.readUint16(i + 0).swap()
    component.xScale = 1
    component.yScale = 1

    i += 2

    if (flags and 1) != 0: # The arguments are uint16
      opentype.buf.eofCheck(i + 4)
      if (flags and 0b10) != 0: # The arguments are offets
        component.dx = opentype.buf.readInt16(i + 0).swap().float32
        component.dy = opentype.buf.readInt16(i + 2).swap().float32
      else: # The arguments are matched points
        component.matchedPoints = [
          opentype.buf.readUint16(i + 0).swap().int,
          opentype.buf.readUint16(i + 2).swap().int
        ]
      i += 4
    else: # The arguments are uint8
      opentype.buf.eofCheck(i + 2)
      if (flags and 0b10) != 0: # Arguments are offsets
        component.dx = opentype.buf.readInt8(i + 0).float32
        component.dy = opentype.buf.readInt8(i + 1).float32
      else: # The arguments are matched points
        component.matchedPoints = [
          opentype.buf.readInt8(i + 0).int,
          opentype.buf.readInt8(i + 1).int
        ]
      i += 2

    # TODO: ROUND_XY_TO_GRID

    if (flags and 0b1000) != 0: # WE_HAVE_A_SCALE
      opentype.buf.eofCheck(i + 2)
      component.xScale = opentype.buf.readFixed16(i + 0)
      component.yScale = component.xScale
      i += 2
    elif (flags and 0b1000000) != 0: # WE_HAVE_AN_X_AND_Y_SCALE
      opentype.buf.eofCheck(i + 4)
      component.xScale = opentype.buf.readFixed16(i + 0)
      component.yScale = opentype.buf.readFixed16(i + 2)
      i += 4
    elif (flags and 0b10000000) != 0: # WE_HAVE_A_TWO_BY_TWO
      opentype.buf.eofCheck(i + 8)
      component.xScale = opentype.buf.readFixed16(i + 0)
      component.scale10 = opentype.buf.readFixed16(i + 2)
      component.scale01 = opentype.buf.readFixed16(i + 4)
      component.yScale = opentype.buf.readFixed16(i + 6)
      i += 8

    # if (flags and 0b100000000) != 0: # WE_HAVE_INSTRUCTIONS
    #   discard
    # elif (flags and 0b1000000000) != 0: # USE_MY_METRICS
    #   discard
    # elif (flags and 0b10000000000) != 0: # OVERLAP_COMPOUND
    #   discard
    # elif (flags and 0b100000000000) != 0: # SCALED_COMPONENT_OFFSET
    #   discard
    # elif (flags and 0b1000000000000) != 0: # UNSCALED_COMPONENT_OFFSET
    #   discard

    var subPath = opentype.parseGlyph(component.glyphId)
    subPath.transform(mat3(
      component.xScale, component.scale10, 0.0,
      component.scale01, component.yScale, 0.0,
      component.dx, component.dy, 1.0
    ))

    result.commands.add(subPath.commands)

    moreComponents = (flags and 0b100000) != 0

proc parseGlyph(opentype: OpenType, glyphId: uint16): Path =
  if glyphId.int >= opentype.glyf.offsets.len:
    raise newException(PixieError, "Invalid glyph ID " & $glyphId)

  let glyphOffset = opentype.glyf.offsets[glyphId]

  if glyphId.int + 1 < opentype.glyf.offsets.len and
    glyphOffset == opentype.glyf.offsets[glyphId + 1]:
    # Empty glyph
    return

  var i = glyphOffset.int
  opentype.buf.eofCheck(i + 10)

  let
    numberOfContours = opentype.buf.readInt16(i + 0).swap().int
    # xMin = opentype.buf.readInt16(i + 2).swap()
    # yMin = opentype.buf.readInt16(i + 4).swap()
    # xMax = opentype.buf.readInt16(i + 6).swap()
    # yMax = opentype.buf.readInt16(i + 8).swap()

  i += 10

  if numberOfContours < 0:
    opentype.parseCompositeGlyph(i)
  else:
    parseGlyphPath(opentype.buf, i, numberOfContours)

proc parseGlyph*(opentype: OpenType, rune: Rune): Path =
  opentype.parseGlyph(opentype.getGlyphId(rune))

proc parseOpenType*(buf: string): OpenType =
  result = OpenType()
  result.buf = buf

  var i: int

  buf.eofCheck(i + 12)

  result.version = buf.readUint32(i + 0).swap()
  result.numTables = buf.readUint16(i + 4).swap()
  result.searchRange = buf.readUint16(i + 6).swap()
  result.entrySelector = buf.readUint16(i + 8).swap()
  result.rangeShift = buf.readUint16(i + 10).swap()

  i += 12

  buf.eofCheck(i + result.numTables.int * 16)

  for j in 0 ..< result.numTables.int:
    var tableRecord: TableRecord
    tableRecord.tag = buf.readStr(i + 0, 4)
    tableRecord.checksum = buf.readUint32(i + 4).swap()
    tableRecord.offset = buf.readUint32(i + 8).swap()
    tableRecord.length = buf.readUint32(i + 12).swap()
    result.tableRecords[tableRecord.tag] = tableRecord
    i += 16

  const requiredTables = [
    "cmap", "head", "hhea", "hmtx", "maxp", "name", "OS/2", "loca", "glyf"
  ]
  for table in requiredTables:
    if table notin result.tableRecords:
      raise newException(PixieError, "Missing required font table " & table)

  result.cmap = parseCmapTable(buf, result.tableRecords["cmap"].offset.int)
  result.head = parseHeadTable(buf, result.tableRecords["head"].offset.int)
  result.hhea = parseHheaTable(buf, result.tableRecords["hhea"].offset.int)
  result.maxp = parseMaxpTable(buf, result.tableRecords["maxp"].offset.int)
  result.hmtx = parseHmtxTable(
    buf, result.tableRecords["hmtx"].offset.int, result.hhea, result.maxp
  )
  result.name = parseNameTable(buf, result.tableRecords["name"].offset.int)
  result.os2 = parseOS2Table(buf, result.tableRecords["OS/2"].offset.int)
  result.loca = parseLocaTable(
    buf, result.tableRecords["loca"].offset.int, result.head, result.maxp
  )
  result.glyf = parseGlyfTable(
    buf, result.tableRecords["glyf"].offset.int, result.loca
  )

  if "kern" in result.tableRecords:
    result.kern = parseKernTable(buf, result.tableRecords["kern"].offset.int)
