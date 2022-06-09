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

  var
    commentMode, readWhitespace: bool
    i, readFields: int
    field: string
  while readFields < 4:
    let c = readUint8(data, i).char
    if c == '#':
      commentMode = true
    elif c == '\n':
      commentMode = false
    if not commentMode:
      if c in Whitespace and not readWhitespace:
        inc readFields
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
        except ValueError:
          failInvalid()
        field = ""
      elif not (c in Whitespace):
        field.add(c)
        readWhitespace = false
    inc i

    result.dataOffset = i

proc decodeP6Data(data: string, maxVal: int): seq[ColorRGBX] {.raises: [].} =
  let needsUint16 = maxVal > 0xFF

  result = newSeq[ColorRGBX](
    if needsUint16:
      data.len div 6
    else:
      data.len div 3
  )

  # Let's calculate the real maximum value multiplier.
  # rgbx() accepts a maximum value of 255. Most of the time,
  # maxVal is set to 255 as well, so in most cases it is 1
  let valueMultiplier = (255 / maxVal).float32

  # if comparison in for loops is expensive, so let's unroll it
  if not needsUint16:
    for i in 0 ..< result.len:
      let
        red = data.readUint8(i + (i * 2)).float32
        green = data.readUint8(i + 1 + (i * 2)).float32
        blue = data.readUint8(i + 2 + (i * 2)).float32
      result[i] = rgbx(
        (red * valueMultiplier + 0.5).uint8,
        (green * valueMultiplier + 0.5).uint8,
        (blue * valueMultiplier + 0.5).uint8,
        255
      )
  else:
    for i in 0 ..< result.len:
      let
        red = data.readUint16(i + (i * 5)).swap.float32
        green = data.readUint16(i + 2 + (i * 5)).swap.float32
        blue = data.readUint16(i + 4 + (i * 5)).swap.float32
      result[i] = rgbx(
        (red * valueMultiplier + 0.5).uint8,
        (green * valueMultiplier + 0.5).uint8,
        (blue * valueMultiplier + 0.5).uint8,
        255
      )

proc decodeP3Data(data: string, maxVal: int): seq[ColorRGBX] {.raises: [PixieError].} =
  let
    needsUint16 = maxVal > 0xFF
    maxLen =
      if needsUint16:
        data.splitWhitespace.len * 2
      else:
        data.splitWhitespace.len

  var p6data = newStringOfCap(maxLen)
  try:
    if not needsUint16:
      for line in data.splitLines():
        for sample in line.split('#', 1)[0].splitWhitespace():
          p6data.add(parseInt(sample).char)
    else:
      for line in data.splitLines():
        for sample in line.split('#', 1)[0].splitWhitespace():
          p6data.addUint16(parseInt(sample).uint16.swap)
  except ValueError:
    failInvalid()

  result = decodeP6Data(p6data, maxVal)

proc decodePpm*(data: string): Image {.raises: [PixieError].} =
  ## Decodes Portable Pixel Map data into an Image.

  let header = decodeHeader(data)

  if not (header.version in ppmSignatures):
    failInvalid()

  if 0 > header.maxVal or header.maxVal > 0xFFFF:
    failInvalid()

  result = newImage(header.width, header.height)
  result.data =
    if header.version == "P3":
      decodeP3Data(data[header.dataOffset .. ^1], header.maxVal)
    else:
      decodeP6Data(data[header.dataOffset .. ^1], header.maxVal)

proc decodePpmDimensions*(
  data: string
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes the PPM dimensions.
  let header = decodeHeader(data)
  result.width = header.width
  result.height = header.height

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
      let rgb = image[x, y]
      # Alpha channel is ignored
      result.addUint8(rgb.r)
      result.addUint8(rgb.g)
      result.addUint8(rgb.b)
