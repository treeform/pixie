import chroma, flatty/binny, pixie/common, pixie/images, std/strutils

# See: http://netpbm.sourceforge.net/doc/ppm.html

const ppmSignatures* = @["P3", "P6"]

type
  PpmHeader = object
    version: string
    width, height, maxVal, dataOffset: int

template failInvalid() =
  raise newException(PixieError, "Invalid PPM data")

proc decodeHeader(data: string): PpmHeader {.raises: [PixieError].} =
  if data.len <= 10: # Each part + whitespace
    raise newException(PixieError, "Invalid PPM file header")

  var commentMode, readWhitespace: bool
  var i, readFields: int
  var field: string
  while readFields < 4:
    let c = readUint8(data, i).char
    if c == '#':
      commentMode = true
    elif c == '\n':
      commentMode = false
    if not commentMode:
      if c in Whitespace and not readWhitespace:
        readFields += 1
        readWhitespace = true
        try:
          case readFields:
            of 1:
              result.version = field
            of 2:
              result.width = parseInt(field)
            of 3:
              result.height = parseInt(field)
            of 4:
              result.maxVal = parseInt(field)
            else:
              discard
        except ValueError: failInvalid()
        field = ""
      elif not (c in Whitespace):
        field.add(c)
        readWhitespace = false
    i += 1

    result.dataOffset = i

proc decodeP6Data(data: string, maxVal: int): seq[ColorRGBX] {.raises: [].} =
  let needsUint16 = maxVal > 0xFF

  result = newSeq[ColorRGBX]((
    if needsUint16: data.len / 6
    else: data.len / 3
  ).int)

  # Let's calculate the real maximum value multiplier.
  # rgbx() accepts a maximum value of 0xFF. Most of the time,
  # maxVal is set to 0xFF as well, so in most cases it is 1
  let valueMultiplier = (0xFF / maxVal).uint8

  # if comparison in for loops is expensive, so let's unroll it
  if not needsUint16:
    for i in 0 ..< result.len:
      let
        red = readUint8(data, i + (i * 2)) * valueMultiplier
        green = readUint8(data, i + 1 + (i * 2)) * valueMultiplier
        blue = readUint8(data, i + 2 + (i * 2)) * valueMultiplier
      result[i] = rgbx(red, green, blue, 0xFF)
  else:
    for i in 0 ..< result.len:
      let
        red = readUint16(data, i + (i * 4)).uint8 * valueMultiplier
        green = readUint16(data, i + 2 + (i * 4)).uint8 * valueMultiplier
        blue = readUint16(data, i + 4 + (i * 4)).uint8 * valueMultiplier
      result[i] = rgbx(red, green, blue, 0xFF)

proc decodeP3Data(data: string, maxVal: int): seq[ColorRGBX] {.raises: [PixieError].} =
  var p6data = newStringOfCap(data.splitWhitespace.len)
  try:
    for line in data.splitLines():
      echo line
      for sample in line.split('#', 1)[0].splitWhitespace():
        p6data.add(parseInt(sample).chr)
  except ValueError: failInvalid()

  result = decodeP6Data(p6data, maxVal)

proc decodePpm*(data: string): Image {.raises: [PixieError].} =
  ## Decodes Portable Pixel Map data into an Image.

  let header = decodeHeader(data)

  if not (header.version in ppmSignatures): failInvalid()
  if 0 > header.maxVal or header.maxVal > 0xFFFF: failInvalid()

  result = newImage(header.width, header.height)
  result.data = (
    if header.version == "P3":
      decodeP3Data(data[header.dataOffset .. ^1], header.maxVal)
    else: decodeP6Data(data[header.dataOffset .. ^1], header.maxVal)
  )

proc decodePpm*(data: seq[uint8]): Image {.inline, raises: [PixieError].} =
  ## Decodes Portable Pixel Map data into an Image.
  decodePpm(cast[string](data))

proc encodePpm*(image: Image): string {.raises: [].} =
  ## Encodes an image into the PPM file format (version P6).

  # PPM header
  result.add("P6") # The header field used to identify the PPM
  result.add("\n") # Newline
  result.add($image.width)
  result.add(" ") # Space
  result.add($image.height)
  result.add("\n") # Newline
  result.add("255") # Max color value
  result.add("\n") # Newline

  # PPM image data
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let rgb = image[x, y].rgba()
      # Alpha channel is ignored
      result.addUint8(rgb.r)
      result.addUint8(rgb.g)
      result.addUint8(rgb.b)
