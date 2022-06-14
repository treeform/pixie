import chroma, flatty/binny, pixie/common, pixie/images, pixie/internal

# See: https://qoiformat.org/qoi-specification.pdf

const
  qoiSignature* = "qoif"
  indexLen = 64
  opRgb = 0b11111110'u8
  opRgba = 0b11111111'u8
  opMask2 = 0b11000000'u8
  opIndex = 0b00000000'u8
  opDiff = 0b01000000'u8
  opLuma = 0b10000000'u8
  opRun = 0b11000000'u8

type
  Colorspace* = enum
    sRBG = 0
    Linear = 1

  Qoi* = ref object
    ## Raw QOI image data.
    width*, height*, channels*: int
    colorspace*: Colorspace
    data*: seq[ColorRGBA]

  Index = array[indexLen, ColorRGBA]

proc hash(p: ColorRGBA): int =
  (p.r.int * 3 + p.g.int * 5 + p.b.int * 7 + p.a.int * 11) mod indexLen

proc newImage*(qoi: Qoi): Image =
  ## Creates a new Image from the QOI.
  result = newImage(qoi.width, qoi.height)
  copyMem(result.data[0].addr, qoi.data[0].addr, qoi.data.len * 4)
  result.data.toPremultipliedAlpha()

proc convertToImage*(qoi: Qoi): Image {.raises: [].} =
  ## Converts a QOI into an Image by moving the data. This is faster but can
  ## only be done once.
  type Movable = ref object
    width, height, channels: int
    colorspace: Colorspace
    data: seq[ColorRGBX]

  result = Image()
  result.width = qoi.width
  result.height = qoi.height
  result.data = move cast[Movable](qoi).data
  result.data.toPremultipliedAlpha()

proc decodeQoi*(data: string): Qoi {.raises: [PixieError].} =
  ## Decompress QOI file format data.
  if data.len <= 14 or data[0 .. 3] != qoiSignature:
    raise newException(PixieError, "Invalid QOI header")

  let
    width = data.readUint32(4).swap()
    height = data.readUint32(8).swap()
    channels = data.readUint8(12)
    colorspace = data.readUint8(13)

  if channels notin {3, 4} or colorspace notin {0, 1}:
    raise newException(PixieError, "Invalid QOI header")

  if width.int * height.int > uint32.high.int64:
    raise newException(PixieError, "QOI is too large to decode")

  result = Qoi()
  result.width = width.int
  result.height = height.int
  result.channels = channels.int
  result.colorspace = colorspace.Colorspace
  result.data.setLen(result.width * result.height)

  var
    index: Index
    p = 14
    run: uint8
    px = rgba(0, 0, 0, 255)
  for dst in result.data.mitems:
    if p > data.len - 8:
      raise newException(PixieError, "Underrun of QOI decoder")

    if run > 0:
      dec run
    else:
      let b0 = data.readUint8(p)
      inc p

      case b0:
      of opRgb:
        px.r = data.readUint8(p + 0)
        px.g = data.readUint8(p + 1)
        px.b = data.readUint8(p + 2)
        p += 3
      of opRgba:
        px.r = data.readUint8(p + 0)
        px.g = data.readUint8(p + 1)
        px.b = data.readUint8(p + 2)
        px.a = data.readUint8(p + 3)
        p += 4
      else:
        case b0 and opMask2:
        of opIndex:
          px = index[b0]
        of opDiff:
          px.r = px.r + ((b0 shr 4) and 0x03).uint8 - 2
          px.g = px.g + ((b0 shr 2) and 0x03).uint8 - 2
          px.b = px.b + ((b0 shr 0) and 0x03).uint8 - 2
        of opLuma:
          let
            b1 = data.readUint8(p)
            vg = (b0.uint8 and 0x3f) - 32
          px.r = px.r + vg - 8 + ((b1 shr 4) and 0x0f)
          px.g = px.g + vg
          px.b = px.b + vg - 8 + ((b1 shr 0) and 0x0f)
          inc p
        of opRun:
          run = b0 and 0x3f
        else:
          raise newException(PixieError, "Unexpected QOI op")

      index[hash(px)] = px

    dst = px

  while p < data.len:
    case data[p]:
    of '\0':
      discard
    of '\1':
      break # ignore trailing data
    else:
      raise newException(PixieError, "Invalid QOI padding")
    inc(p)

proc decodeQoiDimensions*(
  data: string
): ImageDimensions {.raises: [PixieError].} =
  ## Decodes the QOI dimensions.
  if data.len <= 12 or data[0 .. 3] != qoiSignature:
    raise newException(PixieError, "Invalid QOI header")

  result.width = data.readUint32(4).swap().int
  result.height = data.readUint32(8).swap().int

proc encodeQoi*(qoi: Qoi): string {.raises: [PixieError].} =
  ## Encodes raw QOI pixels to the QOI file format.

  if qoi.width.int * qoi.height.int > uint32.high.int64:
    raise newException(PixieError, "QOI is too large to encode")

  # Allocate a buffer 3/4 the size of the pathological encoding
  result = newStringOfCap(14 + 8 + qoi.data.len * 3)

  result.add(qoiSignature)
  result.addUint32(qoi.width.uint32.swap())
  result.addUint32(qoi.height.uint32.swap())
  result.addUint8(qoi.channels.uint8)
  result.addUint8(qoi.colorspace.uint8)

  var
    index: Index
    run: uint8
    pxPrev = rgba(0, 0, 0, 255)
  for off, px in qoi.data:
    if px == pxPrev:
      inc run
      if run == 62 or off == qoi.data.high:
        result.addUint8(opRun or (run - 1))
        run = 0
    else:
      if run > 0:
        result.addUint8(opRun or (run - 1))
        run = 0

      let i = hash(px)
      if index[i] == px:
        result.addUint8(opIndex or uint8(i))
      else:
        index[i] = px
        if px.a == pxPrev.a:
          let
            vr = px.r.int - pxPrev.r.int
            vg = px.g.int - pxPrev.g.int
            vb = px.b.int - pxPrev.b.int
            vgr = vr - vg
            vgb = vb - vg
          if (vr > -3) and (vr < 2) and
              (vg > -3) and (vg < 2) and
              (vb > -3) and (vb < 2):
            let b = opDiff or
              (((vr + 2) shl 4) or ((vg + 2) shl 2) or ((vb + 2) shl 0)).uint8
            result.addUint8(b)
          elif vgr > -9 and vgr < 8 and
              vg > -33 and vg < 32 and
              vgb > -9 and vgb < 8:
            result.addUint8(opLuma or (vg + 32).uint8)
            result.addUint8((((vgr + 8) shl 4) or (vgb + 8)).uint8)
          else:
            result.addUint8(opRgb)
            result.addUint8(px.r)
            result.addUint8(px.g)
            result.addUint8(px.b)
        else:
          result.addUint8(opRgba)
          result.addUint8(px.r)
          result.addUint8(px.g)
          result.addUint8(px.b)
          result.addUint8(px.a)

      pxPrev = px

  for _ in 0 .. 6:
    result.addUint8(0x00)

  result.addUint8(0x01)

proc encodeQoi*(image: Image): string {.raises: [PixieError].} =
  ## Encodes an image to the QOI file format.
  let qoi = Qoi()
  qoi.width = image.width
  qoi.height = image.height
  qoi.channels = 4
  qoi.data.setLen(image.data.len)

  copyMem(qoi.data[0].addr, image.data[0].addr, image.data.len * 4)
  qoi.data.toStraightAlpha()

  encodeQoi(qoi)
