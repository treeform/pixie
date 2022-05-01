import pixie/common, pixie/images, flatty/binny, math, strutils, print, tables

## * https://github.com/daviddrysdale/libjpeg
## * https://www.youtube.com/watch?v=Kv1Hiv3ox8I
## * https://dev.exiv2.org/projects/exiv2/wiki/The_Metadata_in_JPEG_files
## * https://www.media.mit.edu/pia/Research/deepview/exif.html
## * https://www.ccoderun.ca/programming/2017-01-31_jpeg/
## * http://imrannazar.com/Let%27s-Build-a-JPEG-Decoder%3A-Concepts

type
  QuantizationTable = object
    id*: uint8
    data: array[64, uint8]

  Component* = object
    id*: uint8
    samplingFactorX*: uint8
    samplingFactorY*: uint8
    quantizationTableId*: uint8

    dctabsel*: uint8
    actabsel*: uint8

    # width*: int32
    # height*: int32
    # data*: seq[uint8]

  Jpeg* = ref object
    width*: int
    height*: int
    bitsPerPixel*: uint8
    components*: seq[Component]
    quantizationTables: seq[QuantizationTable]
    huffmanTables: Table[uint8, TableRef[(int, uint16), uint8]]

template failInvalid() =
  raise newException(PixieError, "Invalid JPEG buffer, unable to load")

template failInvalid(msg: string) =
  raise newException(PixieError, "Invalid JPEG buffer, " & msg)


const zigzag = @[
  00, 01, 08, 16, 09, 02, 03, 10,
  17, 24, 32, 25, 18, 11, 04, 05,
  12, 19, 26, 33, 40, 48, 41, 34,
  27, 20, 13, 06, 07, 14, 21, 28,
  35, 42, 49, 56, 57, 50, 43, 36,
  29, 22, 15, 23, 30, 37, 44, 51,
  58, 59, 52, 45, 38, 31, 39, 46,
  53, 60, 61, 54, 47, 55, 62, 63
]

proc clampByte*(x: int32): uint8 =
  ## Clips value to 00-FF
  clamp(x, 0.int32 .. 0xFF.int32).uint8

const
  W1*: int32 = 2841
  W2*: int32 = 2676
  W3*: int32 = 2408
  W5*: int32 = 1609
  W6*: int32 = 1108
  W7*: int32 = 565

proc decodeSOF0(jpeg: Jpeg, data: string, offset: int) =
  ## SOF0 (start of frame)
  echo "decodeSOF0"

  jpeg.bitsPerPixel = data.readUint8(offset)
  if jpeg.bitsPerPixel != 8:
    failInvalid($jpeg.bitsPerPixel & " bits per pixel not supported")

  jpeg.width = data.readUint16(offset + 1).swap().int
  jpeg.height = data.readUint16(offset + 3).swap().int

  let numComponents = data.readUint8(offset + 5)
  if numComponents notin {1, 3}:
    failInvalid($numComponents & " components not supported")
  jpeg.components.setLen(numComponents)

  for i in 0 ..< numComponents.int:
    jpeg.components[i].id = data.readUint8(offset + 6 + i * 3 + 0)
    let samplingFactor = data.readUint8(offset + 6 + i * 3 + 1)
    jpeg.components[i].samplingFactorX = samplingFactor and 0x0F
    jpeg.components[i].samplingFactorY = samplingFactor shr 4
    jpeg.components[i].quantizationTableId = data.readUint8(offset + 8 + i * 3)

  echo jpeg.width, "x", jpeg.height

proc decodeAPP0(jpeg: Jpeg, data: string, offset: int) =
  echo "decodeAPP0"

proc decodeSOF2(jpeg: Jpeg, data: string, offset: int) =
  failInvalid("progressive not supported")

proc decodeDHT(jpeg: Jpeg, data: string, offset: int, length: int) =
  echo "decodeDHT"
  #print offset, length
  var at = offset

  # A counter of how many bytes have been read
  var ctr = 0
  # The incrementing code to be used to build the map
  var code: uint16 = 0

  # First byte of a DHT segment is the table ID, between 0 and 31
  var tableId = data.readUint8(at)
  jpeg.huffmanTables[tableId] = newTable[(int, uint16), uint8]()
  inc at

  # Next sixteen bytes are the counts for each code length
  var counts: array[16, uint8]
  for i in 0 ..< 16:
    counts[i] = data.readUint8(at)
    echo "count ", counts[i]
    inc at

  # Remaining bytes are the data values to be mapped
  # Build the Huffman map of (length, code) -> value
  for i in 0 ..< 16:
    echo "-- ", counts[i].int
    for j in 0 ..< counts[i].int:
      jpeg.huffmanTables[tableId][(i + 1, code)] = data.readUint8(at)
      echo " -> ", data.readUint8(at)
      inc at
      inc code
      inc ctr
    code = code shl 1
  #print jpeg.huffmanTables[tableId]

proc decodeDQT(jpeg: Jpeg, data: string, offset: int) =
  echo "decodeDQT"
  var table = QuantizationTable()
  table.id = data.readUint8(offset)
  for i in 0 ..< 64:
    table.data[i] = data.readUint8(offset + 1 + i)
    echo table.data[i]
  jpeg.quantizationTables.add(table)

proc decodeDRI(jpeg: Jpeg, data: string, offset: int) =
  echo "decodeDRI"

proc decodeBlock(jpeg: Jpeg, data: string, offset: int) =
  echo "decodeBlock"

proc decodeSOS(jpeg: Jpeg, data: string, offset, length: int) =
  echo "decodeSOS"

  var at = offset
  var numComponents = data.readUint8(at)
  inc at
  if numComponents.int != jpeg.components.len:
    failInvalid("number of components does not match")

  for component in jpeg.components.mitems:
    var id = data.readUint8(at)
    inc at
    if component.id != id:
      failInvalid("component ids don't not match")
    echo "component ", component.id
    var tab = data.readUint8(at)
    inc at
    component.dctabsel = tab shr 4
    component.actabsel = (tab and 1) or 2
    echo "dctabsel ", component.dctabsel, " actabsel ", component.actabsel

  if data.readUint8(at) != 0: failInvalid()
  inc at
  if data.readUint8(at) != 63: failInvalid()
  inc at
  if data.readUint8(at) != 0: failInvalid()
  inc at

  at = offset + length

  for mby in 0 ..< jpeg.width div 8:
    for mbx in 0 ..< jpeg.width div 8:
      echo "blockgroup ", mbx, ",", mby
      for i, component in jpeg.components:
        echo "block ", i, ":", 0, ",", 0
        jpeg.decodeBlock(data, at)

proc decodeExif(jpeg: Jpeg, data: string, offset: int) =
  echo "decodeExif"

proc decodeJpeg*(data: string): Jpeg =
  result = Jpeg()
  if data.len < 2:
    failInvalid("too small")
  var at = 0
  if data.readUint16(at).swap() != 0xFFD8:
    failInvalid("invalid header")

  at += 2
  while at + 1 < data.len:
    let chunkId = data.readUint16(at).swap()
    at += 2

    if chunkId == 0XFFD9:
      ## End of Image
      echo "decodeEOI"
      return

    let chunkLen = data.readUint16(at).swap().int - 2

    at += 2
    case chunkId:
      of 0xFFC0:
        # Start Of Frame (Baseline DCT)
        result.decodeSOF0(data, at)
        at += chunkLen
      of 0xFFC2:
        # Start Of Frame (Progressive DCT)
        result.decodeSOF2(data, at)
        at += chunkLen
      of 0xFFC4:
        # Define Huffman Table
        result.decodeDHT(data, at, chunkLen)
        at += chunkLen
      of 0xFFDB:
        # Define Quantization Table(s)
        result.decodeDQT(data, at)
        at += chunkLen
      of 0xFFDD:
        # Define Restart Interval
        result.decodeDRI(data, at)
        at += chunkLen
      of 0xFFDA:
        # Start Of Scan
        result.decodeSOS(data, at, chunkLen)
        at += chunkLen
        # Skip encoded data
        while true:
          if data.readUint8(at) == 0xFF and data.readUint8(at + 1) != 00:
            break
          at += 1
      of 0xFFFE:
        # Comment
        at += chunkLen
      of 0XFFE0:
        # Application-specific
        result.decodeAPP0(data, at)
        at += chunkLen
      of 0xFFE1:
        # Exif
        result.decodeExif(data, at)
        at += chunkLen
      of 0xFFE2..0xFFEF:
        # Application-specific
        at += chunkLen
      else:
        failInvalid("invalid chunk " & chunkId.toHex())

echo "start"
let fileName = "tests/fileformats/jpg/master/black.jpg"
echo fileName
let data = readFile(fileName)
var jpeg = decodeJpeg(data)
#print jpeg
