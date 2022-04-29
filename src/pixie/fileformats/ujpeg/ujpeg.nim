##  uJPEG (MicroJPEG) -- KeyJ's Small Baseline JPEG Decoder
##  based on NanoJPEG -- KeyJ's Tiny Baseline JPEG Decoder
##  version 1.3 (2012-03-05)
##  by Martin J. Fiedler <martin.fiedler@gmx.net>
##
##  This software is published under the terms of KeyJ's Research License,
##  version 0.2. Usage of this software is subject to the following conditions:
##  0. There's no warranty whatsoever. The author(s) of this software can not
##     be held liable for any damages that occur when using this software.
##  1. This software may be used freely for both non-commercial and commercial
##     purposes.
##  2. This software may be redistributed freely as long as no fees are charged
##     for the distribution and this license information is included.
##  3. This software may be modified freely except for this license information,
##     which must not be changed in any way.
##  4. If anything other than configuration, indentation or comments have been
##     altered in the code, the original author(s) must receive a copy of the
##     modified code.


proc printf(formatstr: cstring) {.header: "<stdio.h>", varargs.}

proc `+`[T](data: ptr T, stride: SomeInteger): ptr T =
  cast[ptr T](cast[int](data) + cast[int](stride) * sizeof(T))

proc `[]`[T](data: ptr T, index: SomeInteger): var T =
  (data + index)[]

proc `[]=`[T](data: ptr T, index: SomeInteger, value: T) =
  (data + index)[] = value

proc inc[T](data: var ptr T, stride: SomeInteger = 1) =
  data = data + stride

proc exit(code: int32) =
  quit(code)

proc malloc(size: int): pointer =
  alloc(size)

proc free(data: pointer) =
  dealloc(data)

proc free[T](data: var ptr T) =
  free(cast[pointer](data))

proc memset[T](data: ptr T, what: uint8, size: SomeInteger) =
  var data8 = cast[ptr uint8](data)
  for i in 0 ..< size:
    data8[i] = what

proc memcmp(data: ptr uint8, str: cstring, size: uint32): int32 =
  var strData = cast[ptr uint8](str)
  for i in 0 ..< size:
    if strData[i] != data[i]:
      return i.int32
  return 0

proc memcpy(dest, source: pointer; size: Natural) =
  copyMem(dest, source, size)

template addr(x: untyped) = unsafeAddr(x)

##  plane (color component) structure

type
  ujPlane* {.bycopy.} = object
    width*: int32              ##  visible width
    height*: int32             ##  visible height
    stride*: int32             ##  line size in bytes
    pixels*: ptr uint8          ##  pixel data


##  data type for uJPEG image handles

type
  ujImage* = pointer
  ujVLCCode* {.bycopy.} = object
    bits*: uint8
    code*: uint8

  ujComponent* {.bycopy.} = object
    width*: int32
    height*: int32
    stride*: int32
    pixels*: ptr uint8
    cid*: int32
    ssx*: int32
    ssy*: int32
    qtsel*: int32
    actabsel*: int32
    dctabsel*: int32
    dcpred*: int32

  ujContext* {.bycopy.} = object
    pos*: ptr uint8
    valid*: int32
    decoded*: int32
    no_decode*: int32
    fast_chroma*: int32
    size*: int32
    length*: int32
    width*: int32
    height*: int32
    mbwidth*: int32
    mbheight*: int32
    mbsizex*: int32
    mbsizey*: int32
    ncomp*: int32
    comp*: array[3, ujComponent]
    qtused*: int32
    qtavail*: int32
    qtab*: array[4, array[64, uint8]]
    vlctab*: array[4, array[65536, ujVLCCode]]
    buf*: int32
    bufbits*: int32
    block64*: array[64, int32]
    rstinterval*: int32
    rgb*: ptr uint8
    exif_le*: int32
    co_sited_chroma*: int32



type constructujContext = ujContext

var ujZZ*: array[64, char] = [cast[char](0), cast[char](1), cast[char](8),
                         cast[char](16), cast[char](9), cast[char](2),
                         cast[char](3), cast[char](10), cast[char](17),
                         cast[char](24), cast[char](32), cast[char](25),
                         cast[char](18), cast[char](11), cast[char](4),
                         cast[char](5), cast[char](12), cast[char](19),
                         cast[char](26), cast[char](33), cast[char](40),
                         cast[char](48), cast[char](41), cast[char](34),
                         cast[char](27), cast[char](20), cast[char](13),
                         cast[char](6), cast[char](7), cast[char](14),
                         cast[char](21), cast[char](28), cast[char](35),
                         cast[char](42), cast[char](49), cast[char](56),
                         cast[char](57), cast[char](50), cast[char](43),
                         cast[char](36), cast[char](29), cast[char](22),
                         cast[char](15), cast[char](23), cast[char](30),
                         cast[char](37), cast[char](44), cast[char](51),
                         cast[char](58), cast[char](59), cast[char](52),
                         cast[char](45), cast[char](38), cast[char](31),
                         cast[char](39), cast[char](46), cast[char](53),
                         cast[char](60), cast[char](61), cast[char](54),
                         cast[char](47), cast[char](55), cast[char](62),
                         cast[char](63)]

proc ujClip*(x: int32): uint8 =
  ##  return (x < 0) ? 0 : ((x > 0xFF) ? 0xFF : (uint8)x);
  if x < 0:
    return 0
  elif x > 0xFF:
    return 0xFF
  else:
    return cast[uint8](x)

## /////////////////////////////////////////////////////////////////////////////

var W1*: int32 = 2841

var W2*: int32 = 2676

var W3*: int32 = 2408

var W5*: int32 = 1609

var W6*: int32 = 1108

var W7*: int32 = 565

proc ujRowIDCT*(blk: ptr int32) =
  var
    x0: int32
    x1: int32
    x2: int32
    x3: int32
    x4: int32
    x5: int32
    x6: int32
    x7: int32
    x8: int32
  ## if (!((x1 = blk[4] << 11) | (x2 = blk[6]) | (x3 = blk[2]) | (x4 = blk[1]) | (x5 = blk[7]) | (x6 = blk[5]) | (x7 = blk[3])))
  x1 = blk[4] shl 11
  x2 = blk[6]
  x3 = blk[2]
  x4 = blk[1]
  x5 = blk[7]
  x6 = blk[5]
  x7 = blk[3]
  if not ((x1 != 0) or (x2 != 0) or (x3 != 0) or (x4 != 0) or (x5 != 0) or (x6 != 0) or (x7 != 0)):
    var value: int32 = blk[0] shl 3
    blk[0] = value
    blk[1] = value
    blk[2] = value
    blk[3] = value
    blk[4] = value
    blk[5] = value
    blk[6] = value
    blk[7] = value
    return
  x0 = (blk[0] shl 11) + 128
  x8 = W7 * (x4 + x5)
  x4 = x8 + (W1 - W7) * x4
  x5 = x8 - (W1 + W7) * x5
  x8 = W3 * (x6 + x7)
  x6 = x8 - (W3 - W5) * x6
  x7 = x8 - (W3 + W5) * x7
  x8 = x0 + x1
  dec(x0, x1)
  x1 = W6 * (x3 + x2)
  x2 = x1 - (W2 + W6) * x2
  x3 = x1 + (W2 - W6) * x3
  x1 = x4 + x6
  dec(x4, x6)
  x6 = x5 + x7
  dec(x5, x7)
  x7 = x8 + x3
  dec(x8, x3)
  x3 = x0 + x2
  dec(x0, x2)
  x2 = (181 * (x4 + x5) + 128) shr 8
  x4 = (181 * (x4 - x5) + 128) shr 8
  blk[0] = (x7 + x1) shr 8
  blk[1] = (x3 + x2) shr 8
  blk[2] = (x0 + x4) shr 8
  blk[3] = (x8 + x6) shr 8
  blk[4] = (x8 - x6) shr 8
  blk[5] = (x0 - x4) shr 8
  blk[6] = (x3 - x2) shr 8
  blk[7] = (x7 - x1) shr 8

proc ujColIDCT*(blk: ptr int32; orgData: ptr uint8; stride: int32) =
  var data: ptr uint8 = orgData
  var
    x0: int32
    x1: int32
    x2: int32
    x3: int32
    x4: int32
    x5: int32
    x6: int32
    x7: int32
    x8: int32
  ## if (!((x1 = blk[8 * 4] << 8) | (x2 = blk[8 * 6]) | (x3 = blk[8 * 2]) | (x4 = blk[8 * 1]) | (x5 = blk[8 * 7]) | (x6 = blk[8 * 5]) | (x7 = blk[8 * 3])))
  x1 = blk[8 * 4] shl 8
  x2 = blk[8 * 6]
  x3 = blk[8 * 2]
  x4 = blk[8 * 1]
  x5 = blk[8 * 7]
  x6 = blk[8 * 5]
  x7 = blk[8 * 3]
  if not ((x1 != 0) or (x2 != 0) or (x3 != 0) or (x4 != 0) or (x5 != 0) or (x6 != 0) or (x7 != 0)):
    x1 = cast[int32](ujClip(((blk[0] + 32) shr 6) + 128))
    x0 = 8
    while x0 != 0:
      data[] = cast[uint8](x1)
      inc(data, stride)
      dec(x0)
    return
  x0 = (blk[0] shl 8) + 8192
  x8 = W7 * (x4 + x5) + 4
  x4 = (x8 + (W1 - W7) * x4) shr 3
  x5 = (x8 - (W1 + W7) * x5) shr 3
  x8 = W3 * (x6 + x7) + 4
  x6 = (x8 - (W3 - W5) * x6) shr 3
  x7 = (x8 - (W3 + W5) * x7) shr 3
  x8 = x0 + x1
  dec(x0, x1)
  x1 = W6 * (x3 + x2) + 4
  x2 = (x1 - (W2 + W6) * x2) shr 3
  x3 = (x1 + (W2 - W6) * x3) shr 3
  x1 = x4 + x6
  dec(x4, x6)
  x6 = x5 + x7
  dec(x5, x7)
  x7 = x8 + x3
  dec(x8, x3)
  x3 = x0 + x2
  dec(x0, x2)
  x2 = (181 * (x4 + x5) + 128) shr 8
  x4 = (181 * (x4 - x5) + 128) shr 8
  data[] = ujClip(((x7 + x1) shr 14) + 128)
  inc(data, stride)
  data[] = ujClip(((x3 + x2) shr 14) + 128)
  inc(data, stride)
  data[] = ujClip(((x0 + x4) shr 14) + 128)
  inc(data, stride)
  data[] = ujClip(((x8 + x6) shr 14) + 128)
  inc(data, stride)
  data[] = ujClip(((x8 - x6) shr 14) + 128)
  inc(data, stride)
  data[] = ujClip(((x0 - x4) shr 14) + 128)
  inc(data, stride)
  data[] = ujClip(((x3 - x2) shr 14) + 128)
  inc(data, stride)
  data[] = ujClip(((x7 - x1) shr 14) + 128)

## /////////////////////////////////////////////////////////////////////////////

proc ujShowBits*(uj: ptr ujContext; bits: int32): int32 =
  var newbyte: uint8
  if bits == 0:
    return 0
  while uj.bufbits < bits:
    if uj.size <= 0:
      uj.buf = (uj.buf shl 8) or 0xFF
      inc(uj.bufbits, 8)
      continue
    newbyte = uj.pos[]
    inc(uj.pos)
    dec(uj.size)
    inc(uj.bufbits, 8)
    uj.buf = (uj.buf shl 8) or cast[int32](newbyte)
    if newbyte == 0xFF:
      if uj.size != 0:
        var marker: uint8 = uj.pos[]
        inc(uj.pos)
        dec(uj.size)
        case marker
        of 0x00, 0xFF:
          discard
        of 0xD9:
          uj.size = 0
        else:
          if (marker and 0xF8) != 0xD0:
            printf("UJ_SYNTAX_ERROR")
            exit(-1)
          else:
            uj.buf = (uj.buf shl 8) or cast[int32](marker)
            inc(uj.bufbits, 8)
      else:
        printf("UJ_SYNTAX_ERROR")
        exit(-1)
  return (uj.buf shr (uj.bufbits - bits)) and (int32)((1 shl bits) - 1)

proc ujSkipBits*(uj: ptr ujContext; bits: int32) =
  if uj.bufbits < bits:
    var `discard`: int32 = ujShowBits(uj, bits)
  dec(uj.bufbits, bits)

proc ujGetBits*(uj: ptr ujContext; bits: int32): int32 =
  var res: int32 = ujShowBits(uj, bits)
  ujSkipBits(uj, bits)
  return res

proc ujByteAlign*(uj: ptr ujContext) =
  uj.bufbits = uj.bufbits and 0xF8

proc ujSkip*(uj: ptr ujContext; count: int32) =
  printf("ujSkip %i\n", count)
  inc(uj.pos, count)
  dec(uj.size, count)
  dec(uj.length, count)
  if uj.size < 0:
    printf("UJ_SYNTAX_ERROR")
    exit(-1)

proc ujDecode16*(pos: ptr uint8): int32 =
  var res: int32 = ((cast[int32](pos[0]) shl 8) or cast[int32](pos[1]))
  printf("ujDecode16 %i\n", res)
  return res

proc ujDecodeLength*(uj: ptr ujContext) =
  printf("ujDecodeLength\n")
  if uj.size < 2:
    printf("UJ_SYNTAX_ERROR\n")
    exit(-1)
  uj.length = ujDecode16(uj.pos)
  if uj.length > uj.size:
    printf("UJ_SYNTAX_ERROR\n")
    exit(-1)
  ujSkip(uj, 2)

proc ujSkipMarker*(uj: ptr ujContext) =
  ujDecodeLength(uj)
  ujSkip(uj, uj.length)

proc ujDecodeSOF*(uj: ptr ujContext) =
  printf("ujDecodeSOF\n")
  var
    i: int32
    ssxmax: int32 = 0
    ssymax: int32 = 0
    size: int32
  var c: ptr ujComponent
  ujDecodeLength(uj)
  if uj.length < 9:
    printf("UJ_SYNTAX_ERROR uj->length < 9\n")
    exit(-1)
  if uj.pos[0] != 8:
    printf("UJ_UNSUPPORTED\n")
    exit(-1)
  uj.height = ujDecode16(uj.pos + 1)
  uj.width = ujDecode16(uj.pos + 3)
  uj.ncomp = cast[int32](uj.pos[5])
  ujSkip(uj, 6)
  case uj.ncomp
  of 1, 3:
    discard
  else:
    printf("UJ_UNSUPPORTED\n")
    exit(-1)
  if uj.length < (uj.ncomp * 3):
    printf("UJ_SYNTAX_ERROR uj->length < (uj->ncomp * 3)\n")
    exit(-1)
  i = 0
  c = addr(uj.comp[0])
  while i < uj.ncomp:
    c.cid = cast[int32](uj.pos[0])
    c.ssx = cast[int32](uj.pos[1]) shr 4
    if c.ssx == 0:
      printf("UJ_SYNTAX_ERROR !(c->ssx) != 0\n")
      exit(-1)
    if (c.ssx and (c.ssx - 1)) != 0:
      printf("UJ_UNSUPPORTED)\n")
      ##  non-power of two
      exit(-1)
    c.ssy = cast[int32](uj.pos[1]) and 15
    if c.ssy == 0:
      printf("UJ_SYNTAX_ERROR !(c->ssy) != 0\n")
      exit(-1)
    if (c.ssy and (c.ssy - 1)) != 0:
      printf("UJ_UNSUPPORTED (c->ssy & (c->ssy - 1)\n")
      ##  non-power of two
      exit(-1)
    c.qtsel = cast[int32](uj.pos[2]) and 0xFC
    if c.qtsel != 0:
      printf("UJ_SYNTAX_ERROR c->qtsel != 0\n")
      exit(-1)
    ujSkip(uj, 3)
    uj.qtused = uj.qtused or (int32)(1 shl c.qtsel)
    if c.ssx > ssxmax:
      ssxmax = c.ssx
    if c.ssy > ssymax:
      ssymax = c.ssy
    inc(i)
    inc(c)
  if uj.ncomp == 1:
    c = addr(uj.comp[0])
    c.ssx = 1
    c.ssy = 1
    ssxmax = 1
    ssymax = 1
  uj.mbsizex = ssxmax shl 3
  uj.mbsizey = ssymax shl 3
  uj.mbwidth = (uj.width + uj.mbsizex - 1) div uj.mbsizex
  uj.mbheight = (uj.height + uj.mbsizey - 1) div uj.mbsizey
  i = 0
  c = addr(uj.comp[0])
  while i < uj.ncomp:
    c.width = (uj.width * c.ssx + ssxmax - 1) div ssxmax
    c.stride = (c.width + 7) and 0x7FFFFFF8
    c.height = (uj.height * c.ssy + ssymax - 1) div ssymax
    c.stride = uj.mbwidth * uj.mbsizex * c.ssx div ssxmax
    if ((c.width < 3) and (c.ssx != ssxmax)) or ((c.height < 3) and (c.ssy != ssymax)):
      printf("UJ_UNSUPPORTED\n")
      exit(-1)
    size = c.stride * (uj.mbheight * uj.mbsizey * c.ssy div ssymax)
    if not uj.no_decode != 0:
      c.pixels = cast[ptr uint8](malloc(size))
      memset(c.pixels, 0x80, size)
    inc(i)
    inc(c)
  ujSkip(uj, uj.length)

proc ujDecodeDHT*(uj: ptr ujContext) =
  printf("ujDecodeDHT\n")
  var
    codelen: int32
    currcnt: int32
    remain: int32
    spread: int32
    i: int32
    j: int32
  var vlc: ptr ujVLCCode
  var counts: array[16, uint8]
  ujDecodeLength(uj)
  while uj.length >= 17:
    i = cast[int32](uj.pos[0])
    if (i and 0xEC) != 0:
      printf("UJ_SYNTAX_ERROR\n")
      exit(-1)
    if (i and 0x02) != 0:
      printf("UJ_UNSUPPORTED\n")
      exit(-1)
    i = (i or (i shr 3)) and 3
    ##  combined DC/AC + tableid value
    codelen = 1
    while codelen <= 16:
      counts[codelen - 1] = uj.pos[codelen]
      inc(codelen)
    ujSkip(uj, 17)
    vlc = addr(uj.vlctab[i][0])
    remain = 65536
    spread = 65536
    codelen = 1
    while codelen <= 16:
      spread = spread shr 1
      currcnt = cast[int32](counts[codelen - 1])
      if currcnt == 0:
        inc(codelen)
        continue
      if uj.length < currcnt:
        printf("UJ_SYNTAX_ERROR\n")
        exit(-1)
      dec(remain, currcnt shl (16 - codelen))
      if remain < 0:
        printf("UJ_SYNTAX_ERROR\n")
        exit(-1)
      i = 0
      while i < currcnt:
        var code: uint8 = uj.pos[i]
        j = spread
        while j != 0:
          vlc.bits = cast[uint8](codelen)
          vlc.code = code
          inc(vlc)
          dec(j)
        inc(i)
      ujSkip(uj, currcnt)
      inc(codelen)
    while remain != 0:
      dec(remain)
      vlc.bits = 0
      inc(vlc)
  if uj.length != 0:
    printf("UJ_SYNTAX_ERROR\n")
    exit(-1)

proc ujDecodeDQT*(uj: ptr ujContext) =
  printf("ujDecodeDQT\n")
  var i: int32
  var t: ptr uint8
  ujDecodeLength(uj)
  while uj.length >= 65:
    i = cast[int32](uj.pos[0])
    if (i and 0xFC) != 0:
      printf("UJ_SYNTAX_ERROR\n")
      exit(-1)
    uj.qtavail = uj.qtavail or (int32)(1 shl i)
    t = addr(uj.qtab[i][0])
    i = 0
    while i < 64:
      t[i] = uj.pos[i + 1]
      inc(i)
    ujSkip(uj, 65)
  if uj.length != 0:
    printf("UJ_SYNTAX_ERROR\n")
    exit(-1)

proc ujDecodeDRI*(uj: ptr ujContext) =
  printf("ujDecodeDRI\n")
  ujDecodeLength(uj)
  if uj.length < 2:
    printf("UJ_SYNTAX_ERROR\n")
    exit(-1)
  uj.rstinterval = ujDecode16(uj.pos)
  ujSkip(uj, uj.length)

proc ujGetVLC*(uj: ptr ujContext; vlc: ptr ujVLCCode; code: ptr uint8): int32 =
  ##  printf("ujGetVLC\n");
  var value: int32 = ujShowBits(uj, 16)
  var bits: int32 = cast[int32](vlc[value].bits)
  if bits == 0:
    printf("UJ_SYNTAX_ERROR")
    exit(-1)
  ujSkipBits(uj, bits)
  value = cast[int32](vlc[value].code)
  if cast[uint64](code) != 0:
    code[] = cast[uint8](value)
  bits = value and 15
  if bits == 0:
    return 0
  value = ujGetBits(uj, bits)
  if value < (1 shl (bits - 1)):
    inc(value, ((-1) shl bits) + 1)
  return value

proc ujDecodeBlock*(uj: ptr ujContext; c: ptr ujComponent; data: ptr uint8) =
  printf("ujDecodeBlock\n")
  var code: uint8 = 0
  var
    value: int32
    coef: int32 = 0
  memset(addr(uj.block64[0]), 0, sizeof((uj.block64)))
  inc(c.dcpred, ujGetVLC(uj, addr(uj.vlctab[c.dctabsel][0]), nil))
  uj.block64[0] = (c.dcpred) * (int32)(uj.qtab[c.qtsel][0])
  while true:
    value = ujGetVLC(uj, addr(uj.vlctab[c.actabsel][0]), addr(code))
    if code == 0:
      break
      ##  EOB
    if ((code and 0x0F) == 0) and (code != 0xF0):
      printf("UJ_SYNTAX_ERROR\n")
      exit(-1)
    inc(coef, (int32)((code shr 4) + 1))
    if coef > 63:
      printf("UJ_SYNTAX_ERROR\n")
      exit(-1)
    uj.block64[cast[int32](ujZZ[coef])] = value *
        cast[int32](uj.qtab[c.qtsel][coef])
    if not (coef < 63):
      break
  coef = 0
  while coef < 64:
    ujRowIDCT(addr(uj.block64[coef]))
    inc(coef, 8)
  coef = 0
  while coef < 8:
    ujColIDCT(addr(uj.block64[coef]), addr(data[coef]), c.stride)
    inc(coef)

proc ujDecodeScan*(uj: ptr ujContext) =
  printf("ujDecodeScan\n")
  var
    i: int32
    mbx: int32
    mby: int32
    sbx: int32
    sby: int32
  var
    rstcount: int32 = uj.rstinterval
    nextrst: int32 = 0
  var c: ptr ujComponent
  ujDecodeLength(uj)
  if uj.length < (4 + 2 * uj.ncomp):
    printf("UJ_SYNTAX_ERROR\n")
    exit(-1)
  if cast[int32](uj.pos[0]) != uj.ncomp:
    printf("UJ_UNSUPPORTED\n")
    exit(-1)
  ujSkip(uj, 1)
  i = 0
  c = addr(uj.comp[0])
  while i < uj.ncomp:
    if cast[int32](uj.pos[0]) != c.cid:
      printf("UJ_SYNTAX_ERROR\n")
      exit(-1)
    if (uj.pos[1] and 0xEE) != 0:
      printf("UJ_SYNTAX_ERROR\n")
      exit(-1)
    c.dctabsel = cast[int32](uj.pos[1]) shr 4
    c.actabsel = (int32)(uj.pos[1] and 1) or 2
    ujSkip(uj, 2)
    inc(i)
    inc(c)
  if ((uj.pos[0] != 0) or (uj.pos[1] != 63) or (uj.pos[2] != 0)):
    printf("UJ_UNSUPPORTED\n")
    exit(-1)
  ujSkip(uj, uj.length)
  uj.valid = 1
  if uj.no_decode != 0:
    return
  uj.decoded = 1
  ##  mark the image as decoded now -- every subsequent error
  ##  just means that the image hasn't been decoded
  ##  completely
  mbx = 0
  mby = 0
  while true:
    i = 0
    c = addr(uj.comp[0])
    while i < uj.ncomp:
      sby = 0
      while sby < c.ssy:
        sbx = 0
        while sbx < c.ssx:
          ujDecodeBlock(uj, c, addr(c.pixels[
              ((mby * c.ssy + sby) * c.stride + mbx * c.ssx + sbx) shl 3]))
          inc(sbx)
        inc(sby)
      inc(i)
      inc(c)
    inc(mbx)
    if mbx >= uj.mbwidth:
      mbx = 0
      inc(mby)
      if mby >= uj.mbheight:
        break
    dec(rstcount)
    if (uj.rstinterval) != 0 and not (rstcount != 0):
      ujByteAlign(uj)
      i = ujGetBits(uj, 16)
      if ((i and 0xFFF8) != 0xFFD0) or ((i and 7) != nextrst):
        printf("UJ_SYNTAX_ERROR\n")
        exit(-1)
      nextrst = (nextrst + 1) and 7
      rstcount = uj.rstinterval
      i = 0
      while i < 3:
        uj.comp[i].dcpred = 0
        inc(i)

## /////////////////////////////////////////////////////////////////////////////

var CF4A*: int32 = (-9)

var CF4B*: int32 = (111)

var CF4C*: int32 = (29)

var CF4D*: int32 = (-3)

var CF3A*: int32 = (28)

var CF3B*: int32 = (109)

var CF3C*: int32 = (-9)

var CF3X*: int32 = (104)

var CF3Y*: int32 = (27)

var CF3Z*: int32 = (-3)

var CF2A*: int32 = (139)

var CF2B*: int32 = (-11)

proc CF*(x: int32): int32 =
  return cast[int32](ujClip(((x) + 64) shr 7))

proc ujUpsampleHCentered*(c: ptr ujComponent) =
  printf("ujUpsampleHCentered\n")
  var xmax: int32 = c.width - 3
  var
    data: ptr uint8
    lin: ptr uint8
    lout: ptr uint8
  var
    x: int32
    y: int32
  data = cast[ptr uint8](malloc((c.width * c.height) shl 1))
  lin = c.pixels
  lout = data
  y = c.height
  while y != 0:
    lout[0] = cast[uint8](CF(CF2A * cast[int32](lin[0]) + CF2B * cast[int32](lin[1])))
    lout[1] = cast[uint8](CF(CF3X * cast[int32](lin[0]) + CF3Y * cast[int32](lin[1]) +
        CF3Z * cast[int32](lin[2])))
    lout[2] = cast[uint8](CF(CF3A * cast[int32](lin[0]) + CF3B * cast[int32](lin[1]) +
        CF3C * cast[int32](lin[2])))
    x = 0
    while x < xmax:
      lout[(x shl 1) + 3] = cast[uint8](CF(CF4A * cast[int32](lin[x]) +
          CF4B * cast[int32](lin[x + 1]) + CF4C * cast[int32](lin[x + 2]) +
          CF4D * cast[int32](lin[x + 3])))
      lout[(x shl 1) + 4] = cast[uint8](CF(CF4D * cast[int32](lin[x]) +
          CF4C * cast[int32](lin[x + 1]) + CF4B * cast[int32](lin[x + 2]) +
          CF4A * cast[int32](lin[x + 3])))
      inc(x)
    inc(lin, c.stride)
    inc(lout, c.width shl 1)
    lout[-3] = cast[uint8](CF(CF3A * cast[int32](lin[-1]) +
        CF3B * cast[int32](lin[-2]) + CF3C * cast[int32](lin[-3])))
    lout[-2] = cast[uint8](CF(CF3X * cast[int32](lin[-1]) +
        CF3Y * cast[int32](lin[-2]) + CF3Z * cast[int32](lin[-3])))
    lout[-1] = cast[uint8](CF(CF2A * cast[int32](lin[-1]) +
        CF2B * cast[int32](lin[-2])))
    dec(y)
  c.width = c.width shl 1
  c.stride = c.width
  free(c.pixels)
  c.pixels = data

proc ujUpsampleVCentered*(c: ptr ujComponent) =
  printf("ujUpsampleVCentered\n")
  var
    w: int32 = c.width
    s1: int32 = c.stride
    s2: int32 = s1 + s1
  var
    data: ptr uint8
    cin: ptr uint8
    cout: ptr uint8
  var
    x: int32
    y: int32
  data = cast[ptr uint8](malloc((c.width * c.height) shl 1))
  x = 0
  while x < w:
    cin = addr(c.pixels[x])
    cout = addr(data[x])
    cout[] = cast[uint8](CF(CF2A * cast[int32](cin[0]) + CF2B * cast[int32](cin[s1])))
    inc(cout, w)
    cout[] = cast[uint8](CF(CF3X * cast[int32](cin[0]) + CF3Y * cast[int32](cin[s1]) +
        CF3Z * cast[int32](cin[s2])))
    inc(cout, w)
    cout[] = cast[uint8](CF(CF3A * cast[int32](cin[0]) + CF3B * cast[int32](cin[s1]) +
        CF3C * cast[int32](cin[s2])))
    inc(cout, w)
    inc(cin, s1)
    y = c.height - 3
    while y != 0:
      cout[] = cast[uint8](CF(CF4A * cast[int32](cin[-s1]) +
          CF4B * cast[int32](cin[0]) + CF4C * cast[int32](cin[s1]) +
          CF4D * cast[int32](cin[s2])))
      inc(cout, w)
      cout[] = cast[uint8](CF(CF4D * cast[int32](cin[-s1]) +
          CF4C * cast[int32](cin[0]) + CF4B * cast[int32](cin[s1]) +
          CF4A * cast[int32](cin[s2])))
      inc(cout, w)
      inc(cin, s1)
      dec(y)
    inc(cin, s1)
    cout[] = cast[uint8](CF(CF3A * cast[int32](cin[0]) +
        CF3B * cast[int32](cin[-s1]) + CF3C * cast[int32](cin[-s2])))
    inc(cout, w)
    cout[] = cast[uint8](CF(CF3X * cast[int32](cin[0]) +
        CF3Y * cast[int32](cin[-s1]) + CF3Z * cast[int32](cin[-s2])))
    inc(cout, w)
    cout[] = cast[uint8](CF(CF2A * cast[int32](cin[0]) +
        CF2B * cast[int32](cin[-s1])))
    inc(x)
  c.height = c.height shl 1
  c.stride = c.width
  free(c.pixels)
  c.pixels = data

proc SF*(x: uint8): uint8 =
  return ujClip(((int32)(x) + 8) shr 4)

proc ujUpsampleHCoSited*(c: ptr ujComponent) =
  printf("ujUpsampleHCoSited\n")
  var xmax: int32 = c.width - 1
  var
    data: ptr uint8
    lin: ptr uint8
    lout: ptr uint8
  var
    x: int32
    y: int32
  data = cast[ptr uint8](malloc((c.width * c.height) shl 1))
  lin = c.pixels
  lout = data
  y = c.height
  while y != 0:
    lout[0] = lin[0]
    lout[1] = SF((lin[0] shl 3) + 9 * lin[1] - lin[2])
    lout[2] = lin[1]
    x = 2
    while x < xmax:
      lout[(x shl 1) - 1] = SF(9 * (lin[x - 1] + lin[x]) - (lin[x - 2] + lin[x + 1]))
      lout[x shl 1] = lin[x]
      inc(x)
    inc(lin, c.stride)
    inc(lout, c.width shl 1)
    lout[-3] = SF((lin[-1] shl 3) + 9 * lin[-2] - lin[-3])
    lout[-2] = lin[-1]
    lout[-1] = SF(17 * lin[-1] - lin[-2])
    dec(y)
  c.width = c.width shl 1
  c.stride = c.width
  free(c.pixels)
  c.pixels = data

proc ujUpsampleVCoSited*(c: ptr ujComponent) =
  printf("ujUpsampleVCoSited\n")
  var
    w: int32 = c.width
    s1: int32 = c.stride
    s2: int32 = s1 + s1
  var
    data: ptr uint8
    cin: ptr uint8
    cout: ptr uint8
  var
    x: int32
    y: int32
  data = cast[ptr uint8](malloc((c.width * c.height) shl 1))
  x = 0
  while x < w:
    cin = addr(c.pixels[x])
    cout = addr(data[x])
    cout[] = cin[0]
    inc(cout, w)
    cout[] = SF((cin[0] shl 3) + 9 * cin[s1] - cin[s2])
    inc(cout, w)
    cout[] = cin[s1]
    inc(cout, w)
    inc(cin, s1)
    y = c.height - 3
    while y != 0:
      cout[] = SF(9 * (cin[0] + cin[s1]) - (cin[-s1] + cin[s2]))
      inc(cout, w)
      cout[] = cin[s1]
      inc(cout, w)
      inc(cin, s1)
      dec(y)
    cout[] = SF((cin[s1] shl 3) + 9 * cin[0] - cin[-s1])
    inc(cout, w)
    cout[] = cin[-s1]
    inc(cout, w)
    cout[] = SF(17 * cin[s1] - cin[0])
    inc(x)
  c.height = c.height shl 1
  c.stride = c.width
  free(c.pixels)
  c.pixels = data

proc ujUpsampleFast*(uj: ptr ujContext; c: ptr ujComponent) =
  printf("ujUpsampleFast\n")
  var
    x: int32
    y: int32
    xshift: int32 = 0
    yshift: int32 = 0
  var
    data: ptr uint8
    lin: ptr uint8
    lout: ptr uint8
  while c.width < uj.width:
    c.width = c.width shl 1
    inc(xshift)
  while c.height < uj.height:
    c.height = c.height shl 1
    inc(yshift)
  if xshift == 0 and yshift == 0:
    return
  data = cast[ptr uint8](malloc(c.width * c.height))
  lin = c.pixels
  lout = data
  y = 0
  while y < c.height:
    lin = addr(c.pixels[(y shr yshift) * c.stride])
    x = 0
    while x < c.width:
      lout[x] = lin[x shr xshift]
      inc(x)
    inc(lout, c.width)
    inc(y)
  c.stride = c.width
  free(c.pixels)
  c.pixels = data

proc ujConvert*(uj: ptr ujContext; pout2: ptr uint8) =
  var pout: ptr uint8 = pout2
  printf("ujConvert\n")
  var i: int32
  var c: ptr ujComponent
  i = 0
  c = addr(uj.comp[0])
  while i < uj.ncomp:
    if uj.fast_chroma != 0:
      ujUpsampleFast(uj, c)
    else:
      while (c.width < uj.width) or (c.height < uj.height):
        if c.width < uj.width:
          if uj.co_sited_chroma != 0:
            ujUpsampleHCoSited(c)
          else:
            ujUpsampleHCentered(c)
        if c.height < uj.height:
          if uj.co_sited_chroma != 0:
            ujUpsampleVCoSited(c)
          else:
            ujUpsampleVCentered(c)
    if (c.width < uj.width) or (c.height < uj.height):
      printf("UJ_INTERNAL_ERR\n")
      exit(-1)
    inc(i)
    inc(c)
  if uj.ncomp == 3:
    ##  convert to RGB
    var
      x: int32
      yy: int32
    var py: ptr uint8 = uj.comp[0].pixels
    var pcb: ptr uint8 = uj.comp[1].pixels
    var pcr: ptr uint8 = uj.comp[2].pixels
    yy = uj.height
    while yy != 0:
      x = 0
      while x < uj.width:
        var y: int32 = cast[int32](py[x]) shl 8
        var cb: int32 = cast[int32](pcb[x]) - 128
        var cr: int32 = cast[int32](pcr[x]) - 128
        pout[] = ujClip((y + 359 * cr + 128) shr 8)
        inc(pout)
        pout[] = ujClip((y - 88 * cb - 183 * cr + 128) shr 8)
        inc(pout)
        pout[] = ujClip((y + 454 * cb + 128) shr 8)
        inc(pout)
        inc(x)
      inc(py, uj.comp[0].stride)
      inc(pcb, uj.comp[1].stride)
      inc(pcr, uj.comp[2].stride)
      dec(yy)
  else:
    ##  grayscale -> only remove stride
    var pin: ptr uint8 = addr(uj.comp[0].pixels[uj.comp[0].stride])
    var y: int32
    y = uj.height - 1
    while y != 0:
      memcpy(pout, pin, uj.width)
      inc(pin, uj.comp[0].stride)
      inc(pout, uj.width)
      dec(y)

proc ujDone*(uj: ptr ujContext) =
  printf("ujDone\n")
  var i: int32
  i = 0
  while i < 3:
    if uj.comp[i].pixels != nil:
      free(cast[pointer](uj.comp[i].pixels))
    inc(i)
  if uj.rgb != nil:
    free(cast[pointer](uj.rgb))

proc ujInit*(uj: ptr ujContext) =
  printf("ujInit\n")
  var save_no_decode: int32 = uj.no_decode
  var save_fast_chroma: int32 = uj.fast_chroma
  ujDone(uj)
  memset(uj, 0, sizeof((constructujContext)))
  uj.no_decode = save_no_decode
  uj.fast_chroma = save_fast_chroma

## /////////////////////////////////////////////////////////////////////////////

proc ujGetExif16*(uj: ptr ujContext; p: ptr uint8): uint16 =
  if uj.exif_le != 0:
    return cast[uint16](p[0]) + (cast[uint16](p[1]) shl 8)
  else:
    return (cast[uint16](p[0]) shl 8) + cast[uint16](p[1])

proc ujGetExif32*(uj: ptr ujContext; p: ptr uint8): int32 =
  if uj.exif_le != 0:
    return cast[int32](p[0]) + (cast[int32](p[1]) shl 8) + (cast[int32](p[2]) shl 16) +
        (cast[int32](p[3]) shl 24)
  else:
    return (cast[int32](p[0]) shl 24) + (cast[int32](p[1]) shl 16) +
        (cast[int32](p[2]) shl 8) + cast[int32](p[3])

proc ujDecodeExif*(uj: ptr ujContext) =
  var `ptr`: ptr uint8
  var
    size: int32
    count: int32
    i: int32
  if uj.no_decode != 0 or uj.fast_chroma != 0:
    ujSkipMarker(uj)
    return
  ujDecodeLength(uj)
  `ptr` = uj.pos
  size = uj.length
  ujSkip(uj, uj.length)
  if size < 18:
    return
  if memcmp(`ptr`, "Exif\x00\x00II*\x00", 10) == 0:
    printf("exif_le = 1\n")
    uj.exif_le = 1
  elif memcmp(`ptr`, "Exif\x00\x00MM\x00*", 10) == 0:
    printf("exif_le = 0\n")
    uj.exif_le = 0
  else:
    return
    ##  invalid Exif header
  i = ujGetExif32(uj, `ptr` + 10) + 6
  if (i < 14) or (i > (size - 2)):
    return
  inc(`ptr`, i)
  dec(size, i)
  count = cast[int32](ujGetExif16(uj, `ptr`))
  i = (size - 2) div 12
  if count > i:
    return
  inc(`ptr`, 2)
  dec(count)
  while count != 0:
    if (ujGetExif16(uj, `ptr`) == 0x0213) and
        (ujGetExif16(uj, `ptr` + 2) == 3) and
        (ujGetExif32(uj, `ptr` + 4) == 1): ##  tag = YCbCrPositioning
    ##  type = SHORT
    ##  length = 1
      uj.co_sited_chroma = (int32)(ujGetExif16(uj, `ptr` + 8) == 2)
      return
    inc(`ptr`, 12)

## /////////////////////////////////////////////////////////////////////////////

proc ujCreate*(): ujImage =
  printf("ujCreate\n")
  var uj: ptr ujContext = cast[ptr ujContext](malloc(sizeof((constructujContext))))
  memset(uj, 0, sizeof((constructujContext)))
  ##  check for null
  return cast[ujImage](uj)

proc ujDecode*(img: ujImage; jpeg: pointer; size: int32): int32 =
  printf("ujDecode\n")
  var uj: ptr ujContext = cast[ptr ujContext]((img))
  uj.pos = cast[ptr uint8](jpeg)
  uj.size = size and 0x7FFFFFFF
  if uj.size < 2:
    printf("UJ_NO_JPEG")
    exit(-1)
  if (uj.pos[0] xor 0xFF) != 0 or (uj.pos[1] xor 0xD8) != 0:
    printf("UJ_NO_JPEG")
    exit(-1)
  ujSkip(uj, 2)
  while 1 != 0:
    if (uj.size < 2) or (uj.pos[0] != 0xFF):
      ##  {printf("UJ_SYNTAX_ERROR"); exit(-1);}
      printf("break???\n")
      break
    ujSkip(uj, 2)
    case uj.pos[-1]
    of 0xC0:
      ujDecodeSOF(uj)
    of 0xC4:
      ujDecodeDHT(uj)
    of 0xDB:
      ujDecodeDQT(uj)
    of 0xDD:
      ujDecodeDRI(uj)
    of 0xDA:
      ujDecodeScan(uj)
    of 0xFE:
      ujSkipMarker(uj)
    of 0xE1:
      ujDecodeExif(uj)
    else:
      if (uj.pos[-1] and 0xF0) == 0xE0:
        ujSkipMarker(uj)
      else:
        printf("UJ_UNSUPPORTED")
        exit(-1)
  return 1

proc ujGetWidth*(img: ujImage): int32 =
  var uj: ptr ujContext = cast[ptr ujContext](img)
  return uj.width

proc ujGetHeight*(img: ujImage): int32 =
  var uj: ptr ujContext = cast[ptr ujContext](img)
  return uj.height

proc ujGetImageSize*(img: ujImage): int32 =
  var uj: ptr ujContext = cast[ptr ujContext](img)
  return uj.width * uj.height * uj.ncomp

proc ujGetPlane*(img: ujImage; num: int32): ptr ujPlane =
  var uj: ptr ujContext = cast[ptr ujContext](img)
  return cast[ptr ujPlane](addr(uj.comp[num]))

proc ujGetImage*(img: ujImage; dest: ptr uint8) =
  printf("ujGetImage\n")
  var uj: ptr ujContext = cast[ptr ujContext](img)
  if dest != nil:
    if uj.rgb != nil:
      printf("memcpy???\n")
      memcpy(dest, uj.rgb, uj.width * uj.height * uj.ncomp)
    else:
      ujConvert(uj, dest)

proc ujDestroy*(img: ujImage) =
  ujDone(cast[ptr ujContext](img))
  free(img)
