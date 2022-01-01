import std/endians, chroma, flatty/binny
import pixie/[common, images, internal]

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
  Colorspace* = enum sRBG = 0, linear = 1
  Qoi* = ref object
    ## Raw QOI image data.
    data*: seq[ColorRGBA]
    width*, height*, channels*: int
    colorspace*: Colorspace

  Index = array[indexLen, ColorRGBA]

func hash(p: ColorRGBA): int =
  (p.r.int * 3 + p.g.int * 5 + p.b.int * 7 + p.a.int * 11) mod indexLen

func toImage*(qoi: Qoi): Image =
  ## Converts raw QOI data to `Image`.
  result = newImage(qoi.width, qoi.height)
  copyMem(result.data[0].addr, qoi.data[0].addr, qoi.data.len * 4)
  result.data.toPremultipliedAlpha()

func toQoi*(img: Image; channels: range[3..4]): Qoi =
  ## Converts an `Image` to raw QOI data.
  result = Qoi(
    data: newSeq[ColorRGBA](img.data.len),
    width: img.width,
    height: img.height,
    channels: channels)
  result.data.toStraightAlpha()

proc decompressQoi*(data: string): Qoi {.raises: [PixieError].} =
  ## Decompress QOI file format data.
  if data.len <= 14 or data[0 .. 3] != qoiSignature:
    raise newException(PixieError, "Invalid QOI header")
  var
    width, height: uint32
    channels, colorspace: uint8
  block:
    when cpuEndian == bigEndian:
      width = data.readUint32(4)
      height = data.readUint32(8)
    else:
      var (wBe, hBe) = (data.readUint32(4), data.readUint32(8))
      swapEndian32(addr width, addr wBe)
      swapEndian32(addr height, addr hBe)
  channels = data.readUint8(12)
  colorspace = data.readUint8(13)
  if channels notin {3, 4} or colorspace notin {0, 1}:
    raise newException(PixieError, "Invalid QOI header")
  if width.int * height.int > uint32.high.int:
    raise newException(PixieError, "QOI is too large to decode")

  result = Qoi(
    data: newSeq[ColorRGBA](int width * height),
    width: int width,
    height: int height,
    channels: int channels,
    colorspace: Colorspace colorspace)

  var
    index: Index
    p = 14
    run: uint8
    px = rgba(0, 0, 0, 0xff)

  for dst in result.data.mitems:
    if p > data.len-8:
      raise newException(PixieError, "Underrun of QOI decoder")
    if run > 0:
      dec(run)
    else:
      let b0 = data.readUint8(p)
      inc(p)
      case b0
      of opRgb:
        px.r = data.readUint8(p+0)
        px.g = data.readUint8(p+1)
        px.b = data.readUint8(p+2)
        inc(p, 3)
      of opRgba:
        px.r = data.readUint8(p+0)
        px.g = data.readUint8(p+1)
        px.b = data.readUint8(p+2)
        px.a = data.readUint8(p+3)
        inc(p, 4)
      else:
        case b0 and opMask2
        of opIndex:
          px = index[b0]
        of opDiff:
          px.r = px.r + uint8((b0 shr 4) and 0x03) - 2
          px.g = px.g + uint8((b0 shr 2) and 0x03) - 2
          px.b = px.b + uint8((b0 shr 0) and 0x03) - 2
        of opLuma:
          let b1 = data.readUint8(p)
          inc(p)
          let vg = (b0.uint8 and 0x3f) - 32
          px.r = px.r + vg - 8 + ((b1 shr 4) and 0x0f)
          px.g = px.g + vg
          px.b = px.b + vg - 8 + ((b1 shr 0) and 0x0f)
        of opRun:
          run = b0 and 0x3f
        else: assert false
      index[hash(px)] = px
    dst = px
  while p < data.len:
    case data[p]
    of '\0': discard
    of '\1': break # ignore trailing data
    else:
      raise newException(PixieError, "Invalid QOI padding")
    inc(p)

proc decodeQoi*(data: string): Image {.raises: [PixieError].} =
  ## Decodes data in the QOI file format to an `Image`.
  decompressQoi(data).toImage()

proc decodeQoi*(data: seq[uint8]): Image {.inline, raises: [PixieError].} =
  ## Decodes data in the QOI file format to an `Image`.
  decodeQoi(cast[string](data))

proc compressQoi*(qoi: Qoi): string =
  ## Encodes raw QOI pixels to the QOI file format.
  result = newStringOfCap(14 + 8 + qoi.data.len * 3)
    # allocate a buffer 3/4 the size of the pathological encoding
  result.add(qoiSignature)
  when cpuEndian == bigEndian:
    result.addUint32(uint32 qoi.width)
    result.addUint32(uint32 qoi.height)
  else:
    var
      (wLe, hLe) = (uint32 qoi.width, uint32 qoi.height)
    result.setLen(12)
    swapEndian32(addr result[4], addr wLe)
    swapEndian32(addr result[8], addr hLe)
  result.addUint8(uint8 qoi.channels)
  result.addUint8(uint8 qoi.colorspace)

  var
    index: Index
    run: uint8
    pxPrev = rgba(0, 0, 0, 0xff)

  for off, px in qoi.data:
    if px == pxPrev:
      inc run
      if run == 62 or off == qoi.data.high:
        result.addUint8(opRun or pred(run))
        reset run
    else:
      if run > 0:
        result.addUint8(opRun or pred(run))
        reset run
      let i = hash(px)
      if index[i] == px: result.addUint8(opIndex or uint8(i))
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
            let b = opDiff or uint8(
              ((vr + 2) shl 4) or
              ((vg + 2) shl 2) or
              ((vb + 2) shl 0))
            result.addUint8(b)
          elif vgr > -9 and vgr < 8 and
              vg > -33 and vg < 32 and
              vgb > -9 and vgb < 8:
            result.addUint8(opLuma or uint8(vg + 32))
            result.addUint8(uint8 ((vgr + 8) shl 4) or (vgb + 8))
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
  for _ in 0..6: result.addUint8(0x00)
  result.addUint8(0x01)

proc encodeQoi*(img: Image): string {.raises: [].} =
  ## Encodes an image to the QOI file format.
  compressQoi(toQoi(img, 4))
