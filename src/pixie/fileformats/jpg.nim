import flatty/binny, pixie/common, pixie/images

# See http://www.vip.sugovica.hu/Sardi/kepnezo/JPEG%20File%20Layout%20and%20Format.htm

const
  jpgStartOfImage* = [0xFF.uint8, 0xD8]

type
  Component = object
    id, samplingFactors, quantizationTable: uint8

  Jpg = object
    width, height: int
    components: array[3, Component]

template failInvalid() =
  raise newException(PixieError, "Invalid JPG buffer, unable to load")

proc readSegmentLen(data: seq[uint8], pos: int): int =
  if pos + 2 > data.len:
    failInvalid()

  let segmentLen = data.readUint16(pos).swap().int
  if pos + segmentLen > data.len:
    failInvalid()

  segmentLen

proc skipSegment(data: seq[uint8], pos: var int) {.inline.} =
  pos += readSegmentLen(data, pos)

proc decodeSOF(jpg: var Jpg, data: seq[uint8], pos: var int) =
  let segmentLen = readSegmentLen(data, pos)
  pos += 2

  if pos + 6 > data.len:
    failInvalid()

  let
    precision = data[pos].int
    height = data.readUint16(pos + 1).swap().int
    width = data.readUint16(pos + 3).swap().int
    components = data[pos + 5].int

  pos += 6

  if width <= 0:
    raise newException(PixieError, "Invalid JPG width")

  if height <= 0:
    raise newException(PixieError, "Invalid JPG height")

  if precision != 8:
    raise newException(PixieError, "Unsupported JPG bit depth")

  if components != 3:
    raise newException(PixieError, "Unsupported JPG channel count")

  jpg.width = width
  jpg.height = height

  if 8 + components * 3 != segmentLen:
    failInvalid()

  for i in 0 ..< 3:
    jpg.components[i] = Component(
      id: data[pos],
      samplingFactors: data[pos + 1],
      quantizationTable: data[pos + 2]
    )
    pos += 3

proc decodeDHT(data: seq[uint8], pos: var int) =
  skipSegment(data, pos)

proc decodeDQT(data: seq[uint8], pos: var int) =
  skipSegment(data, pos)

proc decodeSOS(data: seq[uint8], pos: var int) =
  let segmentLen = readSegmentLen(data, pos)
  pos += 2

  if segmentLen != 12:
    failInvalid()

  let components = data[pos]
  if components != 3:
    raise newException(PixieError, "Unsupported JPG channel count")

  for i in 0 ..< 3:
    discard

  pos += 10
  pos += 3 # Skip 3 more bytes

  while true:
    if pos >= data.len:
      failInvalid()

    if data[pos] == 0xFF:
      if pos + 1 == data.len:
        failInvalid()
      if data[pos + 1] == 0xD9: # End of Image:
        pos += 2
        break
      elif data[pos + 1] == 0x00:
        discard # Skip the 0x00 byte
      else:
        failInvalid()
    else:
      discard

    inc pos

proc decodeJpg*(data: seq[uint8]): Image =
  ## Decodes the JPEG into an Image.

  if data.len < 4:
    failInvalid()

  if data.readUint16(0) != cast[uint16](jpgStartOfImage):
    failInvalid()

  var
    jpg: Jpg
    pos: int
  while true:
    if pos + 2 > data.len:
      failInvalid()

    let marker = [data[pos], data[pos + 1]]
    pos += 2

    if marker[0] != 0xFF:
      failInvalid()

    case marker[1]:
    of 0xD8: # Start of Image
      discard
    of 0xC0: # Start of Frame
      jpg.decodeSOF(data, pos)
    of 0xC2: # Start of Frame
      raise newException(PixieError, "Progressive JPG not supported")
    of 0xC4: # Define Huffman Tables
      decodeDHT(data, pos)
    of 0xDB: # Define Quantanization Table(s)
      decodeDQT(data, pos)
    # of 0xDD: # Define Restart Interval
    of 0xDA: # Start of Scan
      decodeSOS(data, pos)
      break
    of 0xFE: # Comment
      skipSegment(data, pos)
    of 0xD9: # End of Image
      failInvalid() # Not expected here
    else:
      if (marker[1] and 0xF0) == 0xE0:
        # Skip APPn segments
        skipSegment(data, pos)
      else:
        raise newException(PixieError, "Unsupported JPG segment")

  raise newException(PixieError, "Decoding JPG not supported yet")

proc decodeJpg*(data: string): Image {.inline.} =
  decodeJpg(cast[seq[uint8]](data))

proc encodeJpg*(image: Image): string =
  raise newException(PixieError, "Encoding JPG not supported yet")
