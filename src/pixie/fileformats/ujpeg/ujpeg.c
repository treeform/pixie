// uJPEG (MicroJPEG) -- KeyJ's Small Baseline JPEG Decoder
// based on NanoJPEG -- KeyJ's Tiny Baseline JPEG Decoder
// version 1.3 (2012-03-05)
// by Martin J. Fiedler <martin.fiedler@gmx.net>
//
// This software is published under the terms of KeyJ's Research License,
// version 0.2. Usage of this software is subject to the following conditions:
// 0. There's no warranty whatsoever. The author(s) of this software can not
//    be held liable for any damages that occur when using this software.
// 1. This software may be used freely for both non-commercial and commercial
//    purposes.
// 2. This software may be redistributed freely as long as no fees are charged
//    for the distribution and this license information is included.
// 3. This software may be modified freely except for this license information,
//    which must not be changed in any way.
// 4. If anything other than configuration, indentation or comments have been
//    altered in the code, the original author(s) must receive a copy of the
//    modified code.

// * https://github.com/daviddrysdale/libjpeg
// * https://www.youtube.com/watch?v=Kv1Hiv3ox8I
// * https://dev.exiv2.org/projects/exiv2/wiki/The_Metadata_in_JPEG_files
// * https://www.media.mit.edu/pia/Research/deepview/exif.html
// * https://questtel.com/wiki/chroma-sub-mapping-types

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifndef C2NIM
typedef uint64_t uint64;
typedef int32_t int32;
typedef uint32_t uint32;
typedef uint16_t uint16;
typedef uint8_t uint8;
#endif

#ifdef C2NIM
#@

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

@#
#endif

// plane (color component) structure
typedef struct _uj_plane
{
    int32 width;   // visible width
    int32 height;  // visible height
    int32 stride;  // line size in bytes
    uint8 *pixels; // pixel data
} ujPlane;

// data type for uJPEG image handles
typedef void *ujImage;

typedef struct _uj_code
{
    uint8 bits, code;
} ujVLCCode;

typedef struct _uj_cmp
{
    int32 width, height;
    int32 stride;
    uint8 *pixels;
    int32 cid;
    int32 ssx, ssy;
    int32 qtsel;
    int32 actabsel, dctabsel;
    int32 dcpred;
} ujComponent;

typedef struct _uj_ctx
{
    uint8 *pos;
    int32 valid, decoded;
    int32 no_decode;
    int32 fast_chroma;
    int32 size;
    int32 length;
    int32 width, height;
    int32 mbwidth, mbheight;
    int32 mbsizex, mbsizey;
    int32 ncomp;
    ujComponent comp[3];
    int32 qtused, qtavail;
    uint8 qtab[4][64];
    ujVLCCode vlctab[4][65536];
    int32 buf, bufbits;
    int32 block64[64];
    int32 rstinterval;
    uint8 *rgb;
    int32 exif_le;
    int32 co_sited_chroma;
} ujContext;

#ifdef C2NIM
#@

type constructujContext = ujContext

@#
#endif

static char ujZZ[64] = {
    (char)0, (char)1, (char)8, (char)16, (char)9, (char)2, (char)3, (char)10, (char)17, (char)24, (char)32, (char)25, (char)18,
    (char)11, (char)4, (char)5, (char)12, (char)19, (char)26, (char)33, (char)40, (char)48, (char)41, (char)34, (char)27, (char)20, (char)13, (char)6, (char)7, (char)14, (char)21, (char)28, (char)35,
    (char)42, (char)49, (char)56, (char)57, (char)50, (char)43, (char)36, (char)29, (char)22, (char)15, (char)23, (char)30, (char)37, (char)44, (char)51, (char)58, (char)59, (char)52, (char)45,
    (char)38, (char)31, (char)39, (char)46, (char)53, (char)60, (char)61, (char)54, (char)47, (char)55, (char)62, (char)63};

uint8 ujClip(int32 x)
{
    // return (x < 0) ? 0 : ((x > 0xFF) ? 0xFF : (uint8)x);
    if (x < 0)
    {
        return 0;
    }
    else if (x > 0xFF)
    {
        return 0XFF;
    }
    else
    {
        return (uint8)x;
    }
}

///////////////////////////////////////////////////////////////////////////////

int32 W1 = 2841;
int32 W2 = 2676;
int32 W3 = 2408;
int32 W5 = 1609;
int32 W6 = 1108;
int32 W7 = 565;

void ujRowIDCT(int32* blk)
{
    int32 x0, x1, x2, x3, x4, x5, x6, x7, x8;

    //if (!((x1 = blk[4] << 11) | (x2 = blk[6]) | (x3 = blk[2]) | (x4 = blk[1]) | (x5 = blk[7]) | (x6 = blk[5]) | (x7 = blk[3])))

    x1 = blk[4] << 11;
    x2 = blk[6];
    x3 = blk[2];
    x4 = blk[1];
    x5 = blk[7];
    x6 = blk[5];
    x7 = blk[3];
    if (!((x1 != 0) | (x2 != 0) | (x3 != 0) | (x4 != 0) | (x5 != 0) | (x6 != 0) | (x7 != 0)))
    {
        int32 value = blk[0] << 3;
        blk[0] = value;
        blk[1] = value;
        blk[2] = value;
        blk[3] = value;
        blk[4] = value;
        blk[5] = value;
        blk[6] = value;
        blk[7] = value;
        return;
    }
    x0 = (blk[0] << 11) + 128;
    x8 = W7 * (x4 + x5);
    x4 = x8 + (W1 - W7) * x4;
    x5 = x8 - (W1 + W7) * x5;
    x8 = W3 * (x6 + x7);
    x6 = x8 - (W3 - W5) * x6;
    x7 = x8 - (W3 + W5) * x7;
    x8 = x0 + x1;
    x0 -= x1;
    x1 = W6 * (x3 + x2);
    x2 = x1 - (W2 + W6) * x2;
    x3 = x1 + (W2 - W6) * x3;
    x1 = x4 + x6;
    x4 -= x6;
    x6 = x5 + x7;
    x5 -= x7;
    x7 = x8 + x3;
    x8 -= x3;
    x3 = x0 + x2;
    x0 -= x2;
    x2 = (181 * (x4 + x5) + 128) >> 8;
    x4 = (181 * (x4 - x5) + 128) >> 8;
    blk[0] = (x7 + x1) >> 8;
    blk[1] = (x3 + x2) >> 8;
    blk[2] = (x0 + x4) >> 8;
    blk[3] = (x8 + x6) >> 8;
    blk[4] = (x8 - x6) >> 8;
    blk[5] = (x0 - x4) >> 8;
    blk[6] = (x3 - x2) >> 8;
    blk[7] = (x7 - x1) >> 8;
}



void ujColIDCT(int32 *blk, uint8 *orgData, int32 stride)
{
    uint8 *data = orgData;
    int32 x0, x1, x2, x3, x4, x5, x6, x7, x8;
    //if (!((x1 = blk[8 * 4] << 8) | (x2 = blk[8 * 6]) | (x3 = blk[8 * 2]) | (x4 = blk[8 * 1]) | (x5 = blk[8 * 7]) | (x6 = blk[8 * 5]) | (x7 = blk[8 * 3])))
    x1 = blk[8 * 4] << 8;
    x2 = blk[8 * 6];
    x3 = blk[8 * 2];
    x4 = blk[8 * 1];
    x5 = blk[8 * 7];
    x6 = blk[8 * 5];
    x7 = blk[8 * 3];
    if (!((x1 != 0) | (x2 != 0) | (x3 != 0) | (x4 != 0) | (x5 != 0) | (x6 != 0) | (x7 != 0)))
    {
        x1 = (int32)ujClip(((blk[0] + 32) >> 6) + 128);
        for (x0 = 8; x0 != 0; --x0)
        {
            *data = (uint8)x1;
            data += stride;
        }
        return;
    }
    x0 = (blk[0] << 8) + 8192;
    x8 = W7 * (x4 + x5) + 4;
    x4 = (x8 + (W1 - W7) * x4) >> 3;
    x5 = (x8 - (W1 + W7) * x5) >> 3;
    x8 = W3 * (x6 + x7) + 4;
    x6 = (x8 - (W3 - W5) * x6) >> 3;
    x7 = (x8 - (W3 + W5) * x7) >> 3;
    x8 = x0 + x1;
    x0 -= x1;
    x1 = W6 * (x3 + x2) + 4;
    x2 = (x1 - (W2 + W6) * x2) >> 3;
    x3 = (x1 + (W2 - W6) * x3) >> 3;
    x1 = x4 + x6;
    x4 -= x6;
    x6 = x5 + x7;
    x5 -= x7;
    x7 = x8 + x3;
    x8 -= x3;
    x3 = x0 + x2;
    x0 -= x2;
    x2 = (181 * (x4 + x5) + 128) >> 8;
    x4 = (181 * (x4 - x5) + 128) >> 8;
    *data = ujClip(((x7 + x1) >> 14) + 128);
    data += stride;
    *data = ujClip(((x3 + x2) >> 14) + 128);
    data += stride;
    *data = ujClip(((x0 + x4) >> 14) + 128);
    data += stride;
    *data = ujClip(((x8 + x6) >> 14) + 128);
    data += stride;
    *data = ujClip(((x8 - x6) >> 14) + 128);
    data += stride;
    *data = ujClip(((x0 - x4) >> 14) + 128);
    data += stride;
    *data = ujClip(((x3 - x2) >> 14) + 128);
    data += stride;
    *data = ujClip(((x7 - x1) >> 14) + 128);
}

///////////////////////////////////////////////////////////////////////////////

static int32 ujShowBits(ujContext *uj, int32 bits)
{
    uint8 newbyte;
    if (bits == 0)
        return 0;
    while (uj->bufbits < bits)
    {
        if (uj->size <= 0)
        {
            uj->buf = (uj->buf << 8) | 0xFF;
            uj->bufbits += 8;
            continue;
        }
        newbyte = *uj->pos;
        uj->pos++;
        uj->size--;
        uj->bufbits += 8;
        uj->buf = (uj->buf << 8) | (int32)newbyte;
        if (newbyte == 0xFF)
        {
            if (uj->size != 0)
            {
                uint8 marker = *uj->pos;
                uj->pos++;
                uj->size--;
                switch (marker)
                {
                case 0x00:
                case 0xFF:
                    break;
                case 0xD9:
                    uj->size = 0;
                    break;
                default:
                    if ((marker & 0xF8) != 0xD0)
                    {
                        printf("UJ_SYNTAX_ERROR");
                        exit(-1);
                    }
                    else
                    {
                        uj->buf = (uj->buf << 8) | (int32)marker;
                        uj->bufbits += 8;
                    }
                }
            }
            else
            {
                printf("UJ_SYNTAX_ERROR");
                exit(-1);
            }
        }
    }
    return (uj->buf >> (uj->bufbits - bits)) & (int32)((1 << bits) - 1);
}

void ujSkipBits(ujContext *uj, int32 bits)
{
    if (uj->bufbits < bits){
        int32 discard = ujShowBits(uj, bits);
    }
    uj->bufbits -= bits;
}

int32 ujGetBits(ujContext *uj, int32 bits)
{
    int32 res = ujShowBits(uj, bits);
    ujSkipBits(uj, bits);
    return res;
}

void ujByteAlign(ujContext *uj)
{
    uj->bufbits &= 0xF8;
}

static void ujSkip(ujContext *uj, int32 count)
{
    //printf("ujSkip %i\n", count);
    uj->pos += count;
    uj->size -= count;
    uj->length -= count;
    if (uj->size < 0)
    {
        printf("UJ_SYNTAX_ERROR");
        exit(-1);
    }
}

int32 ujDecode16(uint8 *pos)
{
    int32 res = (((int32)pos[0] << 8) | (int32)pos[1]);
    //printf("ujDecode16 %i\n", res);
    return res;
}

static void ujDecodeLength(ujContext *uj)
{
    //printf("ujDecodeLength\n");
    if (uj->size < 2)
    {
        printf("UJ_SYNTAX_ERROR\n");
        exit(-1);
    }
    uj->length = ujDecode16(uj->pos);
    if (uj->length > uj->size)
    {
        printf("UJ_SYNTAX_ERROR\n");
        exit(-1);
    }
    ujSkip(uj, 2);
}

void ujSkipMarker(ujContext *uj)
{
    ujDecodeLength(uj);
    ujSkip(uj, uj->length);
}

void ujDecodeSOF(ujContext *uj)
{
    printf("decodeSOF0\n");
    int32 i, ssxmax = 0, ssymax = 0, size;
    ujComponent *c;
    ujDecodeLength(uj);
    if (uj->length < 9)
    {
        printf("UJ_SYNTAX_ERROR uj->length < 9\n");
        exit(-1);
    }
    if (uj->pos[0] != 8)
    {
        printf("UJ_UNSUPPORTED\n");
        exit(-1);
    }
    uj->height = ujDecode16(uj->pos + 1);
    uj->width = ujDecode16(uj->pos + 3);
    printf("%ix%i\n", uj->width, uj->height);
    uj->ncomp = (int32)uj->pos[5];
    ujSkip(uj, 6);
    switch (uj->ncomp)
    {
    case 1:
    case 3:
        break;
    default:
    {
        printf("UJ_UNSUPPORTED\n");
        exit(-1);
    }
    }
    if (uj->length < (uj->ncomp * 3))
    {
        printf("UJ_SYNTAX_ERROR uj->length < (uj->ncomp * 3)\n");
        exit(-1);
    }
    for (i = 0, c = &uj->comp[0]; i < uj->ncomp; ++i, ++c)
    {
        c->cid = (int32)uj->pos[0];
        c->ssx = (int32)uj->pos[1] >> 4;
        if (c->ssx == 0)
        {
            printf("UJ_SYNTAX_ERROR !(c->ssx) != 0\n");
            exit(-1);
        }
        if ((c->ssx & (c->ssx - 1)) != 0)
        {
            printf("UJ_UNSUPPORTED)\n"); // non-power of two
            exit(-1);
        }
        c->ssy = (int32)uj->pos[1] & 15;
        if (c->ssy == 0)
        {
            printf("UJ_SYNTAX_ERROR !(c->ssy) != 0\n");
            exit(-1);
        }
        if ((c->ssy & (c->ssy - 1)) != 0)
        {
            printf("UJ_UNSUPPORTED (c->ssy & (c->ssy - 1)\n"); // non-power of two
            exit(-1);
        }
        c->qtsel = (int32)uj->pos[2] & 0xFC;
        if (c->qtsel != 0)
        {
            printf("UJ_SYNTAX_ERROR c->qtsel != 0\n");
            exit(-1);
        }
        ujSkip(uj, 3);
        uj->qtused |= (int32)(1 << c->qtsel);
        if (c->ssx > ssxmax)
            ssxmax = c->ssx;
        if (c->ssy > ssymax)
            ssymax = c->ssy;
    }
    if (uj->ncomp == 1)
    {
        c = &uj->comp[0];
        c->ssx = 1;
        c->ssy = 1;
        ssxmax = 1;
        ssymax = 1;
    }
    uj->mbsizex = ssxmax << 3;
    uj->mbsizey = ssymax << 3;
    uj->mbwidth = (uj->width + uj->mbsizex - 1) / uj->mbsizex;
    uj->mbheight = (uj->height + uj->mbsizey - 1) / uj->mbsizey;
    for (i = 0, c = &uj->comp[0]; i < uj->ncomp; ++i, ++c)
    {
        c->width = (uj->width * c->ssx + ssxmax - 1) / ssxmax;
        c->stride = (c->width + 7) & 0x7FFFFFF8;
        c->height = (uj->height * c->ssy + ssymax - 1) / ssymax;
        c->stride = uj->mbwidth * uj->mbsizex * c->ssx / ssxmax;
        if (((c->width < 3) && (c->ssx != ssxmax)) || ((c->height < 3) && (c->ssy != ssymax)))
        {
            printf("UJ_UNSUPPORTED\n");
            exit(-1);
        }
        size = c->stride * (uj->mbheight * uj->mbsizey * c->ssy / ssymax);
        if (!uj->no_decode != 0)
        {
            c->pixels = (uint8*)malloc(size);
            memset(c->pixels, 0x80, size);
        }
    }
    ujSkip(uj, uj->length);
}

void ujDecodeDHT(ujContext *uj)
{
    printf("decodeDHT\n");
    int32 codelen, currcnt, remain, spread, i, j;
    ujVLCCode *vlc;
    static uint8 counts[16];
    ujDecodeLength(uj);
    while (uj->length >= 17)
    {
        i = (int32)uj->pos[0];
        if ((i & 0xEC) != 0)
        {
            printf("UJ_SYNTAX_ERROR\n");
            exit(-1);
        }
        if ((i & 0x02) != 0)
        {
            printf("UJ_UNSUPPORTED\n");
            exit(-1);
        }
        i = (i | (i >> 3)) & 3; // combined DC/AC + tableid value
        for (codelen = 1; codelen <= 16; ++codelen) {
            counts[codelen - 1] = uj->pos[codelen];
            printf("count %i\n", uj->pos[codelen]);
        }

        ujSkip(uj, 17);
        vlc = &uj->vlctab[i][0];
        remain = 65536;
        spread = 65536;
        for (codelen = 1; codelen <= 16; ++codelen)
        {

            spread >>= 1;
            currcnt = (int32)counts[codelen - 1];
            printf("-- %i\n", currcnt);

            if (currcnt == 0)
                continue;
            if (uj->length < currcnt)
            {
                printf("UJ_SYNTAX_ERROR\n");
                exit(-1);
            }
            remain -= currcnt << (16 - codelen);
            if (remain < 0)
            {
                printf("UJ_SYNTAX_ERROR\n");
                exit(-1);
            }
            for (i = 0; i < currcnt; ++i)
            {
                uint8 code = uj->pos[i];
                printf(" -> %i\n", code);
                for (j = spread; j != 0; --j)
                {
                    vlc->bits = (uint8)codelen;
                    vlc->code = code;
                    ++vlc;
                }

            }

            ujSkip(uj, currcnt);
        }
        while (remain != 0)
        {
            remain--;
            vlc->bits = 0;
            ++vlc;
        }
    }
    if (uj->length != 0)
    {
        printf("UJ_SYNTAX_ERROR\n");
        exit(-1);
    }
}

void ujDecodeDQT(ujContext *uj)
{
    printf("decodeDQT\n");
    int32 i;
    uint8 *t;
    ujDecodeLength(uj);
    while (uj->length >= 65)
    {
        i = (int32)uj->pos[0];
        if ((i & 0xFC) != 0)
        {
            printf("UJ_SYNTAX_ERROR\n");
            exit(-1);
        }
        uj->qtavail |= (int32)(1 << i);
        t = &uj->qtab[i][0];
        for (i = 0; i < 64; ++i) {
            t[i] = uj->pos[i + 1];
            printf("%i\n", t[i]);
        }
        ujSkip(uj, 65);
    }
    if (uj->length != 0)
    {
        printf("UJ_SYNTAX_ERROR\n");
        exit(-1);
    }
}

void ujDecodeDRI(ujContext *uj)
{
    printf("ujDecodeDRI\n");
    ujDecodeLength(uj);
    if (uj->length < 2)
    {
        printf("UJ_SYNTAX_ERROR\n");
        exit(-1);
    }
    uj->rstinterval = ujDecode16(uj->pos);
    ujSkip(uj, uj->length);
}

static int32 ujGetVLC(ujContext *uj, ujVLCCode *vlc, uint8 *code)
{
    // printf("ujGetVLC\n");
    int32 value = ujShowBits(uj, 16);
    int32 bits = (int32)vlc[value].bits;
    if (bits == 0)
    {
        printf("UJ_SYNTAX_ERROR");
        exit(-1);

    }
    ujSkipBits(uj, bits);
    value = (int32)vlc[value].code;
    if ((uint64)code != 0) {
        *code = (uint8)value;
    }
    bits = value & 15;
    if (bits == 0) {
        return 0;
    }
    value = ujGetBits(uj, bits);
    if (value < (1 << (bits - 1))) {
        value += ((-1) << bits) + 1;
    }
    return value;
}

void ujDecodeBlock(ujContext *uj, ujComponent *c, uint8 *data)
{
    printf("decodeBlock\n");
    uint8 code = 0;
    int32 value, coef = 0;
    memset(&uj->block64[0], 0, sizeof(uj->block64));
    c->dcpred += ujGetVLC(uj, &uj->vlctab[c->dctabsel][0], NULL);
    uj->block64[0] = (c->dcpred) * (int32)(uj->qtab[c->qtsel][0]);
    do
    {
        value = ujGetVLC(uj, &uj->vlctab[c->actabsel][0], &code);
        if (code == 0)
        {
            break; // EOB
        }
        if (((code & 0x0F) == 0) && (code != 0xF0))
        {
            printf("UJ_SYNTAX_ERROR\n");
            exit(-1);
        }
        coef += (int32)((code >> 4) + 1);
        if (coef > 63)
        {
            printf("UJ_SYNTAX_ERROR\n");
            exit(-1);
        }
        uj->block64[(int32)ujZZ[coef]] = value * (int32)uj->qtab[c->qtsel][coef];
    } while (coef < 63);
    for (coef = 0; coef < 64; coef += 8)
    {
        ujRowIDCT(&uj->block64[coef]);
    }
    for (coef = 0; coef < 8; ++coef)
    {
        ujColIDCT(&uj->block64[coef], &data[coef], c->stride);
    }
}

void ujDecodeScan(ujContext *uj)
{
    printf("decodeSOS\n");
    int32 i, mbx, mby, sbx, sby;
    int32 rstcount = uj->rstinterval, nextrst = 0;
    ujComponent *c;
    ujDecodeLength(uj);

    if (uj->length < (4 + 2 * uj->ncomp))
    {
        printf("UJ_SYNTAX_ERROR\n");
        exit(-1);
    }
    if ((int32)uj->pos[0] != uj->ncomp)
    {
        printf("UJ_UNSUPPORTED\n");
        exit(-1);
    }
    ujSkip(uj, 1);
    for (i = 0, c = &uj->comp[0]; i < uj->ncomp; ++i, ++c)
    {
        printf("component %i\n", c->cid);
        if ((int32)uj->pos[0] != c->cid)
        {
            printf("UJ_SYNTAX_ERROR\n");
            exit(-1);
        }
        if ((uj->pos[1] & 0xEE) != 0)
        {
            printf("UJ_SYNTAX_ERROR\n");
            exit(-1);
        }
        c->dctabsel = (int32)uj->pos[1] >> 4;
        c->actabsel = (int32)(uj->pos[1] & 1) | 2;
        printf("dctabsel %i actabsel %i\n", c->dctabsel, c->actabsel);
        ujSkip(uj, 2);
    }
    if (((uj->pos[0] != 0) || (uj->pos[1] != 63) || (uj->pos[2] != 0)))
    {
        printf("UJ_UNSUPPORTED\n");
        exit(-1);
    }
    ujSkip(uj, uj->length);
    uj->valid = 1;
    if (uj->no_decode != 0)
    {
        return;
    }
    uj->decoded = 1; // mark the image as decoded now -- every subsequent error
                     // just means that the image hasn't been decoded
                     // completely
    mbx = 0;
    mby = 0;
    for (;;)
    {
        printf("blockgroup %i,%i\n", mbx, mby);
        for (i = 0, c = &uj->comp[0]; i < uj->ncomp; ++i, ++c)
            for (sby = 0; sby < c->ssy; ++sby)
                for (sbx = 0; sbx < c->ssx; ++sbx)
                {
                    printf("block %i:%i,%i\n", i, sbx, sby);
                    ujDecodeBlock(uj, c, &c->pixels[((mby * c->ssy + sby) * c->stride + mbx * c->ssx + sbx) << 3]);
                }
        mbx ++;
        if (mbx >= uj->mbwidth)
        {
            mbx = 0;
            mby++;
            if (mby >= uj->mbheight)
                break;
        }
        --rstcount;
        if ((uj->rstinterval) != 0 && !(rstcount != 0))
        {
            ujByteAlign(uj);
            i = ujGetBits(uj, 16);
            if (((i & 0xFFF8) != 0xFFD0) || ((i & 7) != nextrst))
            {
                printf("UJ_SYNTAX_ERROR\n");
                exit(-1);
            }
            nextrst = (nextrst + 1) & 7;
            rstcount = uj->rstinterval;
            for (i = 0; i < 3; ++i)
                uj->comp[i].dcpred = 0;
        }
    }
}

///////////////////////////////////////////////////////////////////////////////

int32 CF4A = (-9);
int32 CF4B = (111);
int32 CF4C = (29);
int32 CF4D = (-3);
int32 CF3A = (28);
int32 CF3B = (109);
int32 CF3C = (-9);
int32 CF3X = (104);
int32 CF3Y = (27);
int32 CF3Z = (-3);
int32 CF2A = (139);
int32 CF2B = (-11);

int32 CF(int32 x)
{
    return (int32)ujClip(((x) + 64) >> 7);
}

void ujUpsampleHCentered(ujComponent *c)
{
    printf("ujUpsampleHCentered\n");
    int32 xmax = c->width - 3;
    uint8 *data, *lin, *lout;
    int32 x, y;
    data = (uint8*)malloc((c->width * c->height) << 1);

    lin = c->pixels;
    lout = data;
    for (y = c->height; y != 0; --y)
    {
        lout[0] = (uint8)CF(CF2A * (int32)lin[0] + CF2B * (int32)lin[1]);
        lout[1] = (uint8)CF(CF3X * (int32)lin[0] + CF3Y * (int32)lin[1] + CF3Z * (int32)lin[2]);
        lout[2] = (uint8)CF(CF3A * (int32)lin[0] + CF3B * (int32)lin[1] + CF3C * (int32)lin[2]);
        for (x = 0; x < xmax; ++x)
        {
            lout[(x << 1) + 3] = (uint8)CF(CF4A * (int32)lin[x] + CF4B * (int32)lin[x + 1] + CF4C * (int32)lin[x + 2] + CF4D * (int32)lin[x + 3]);
            lout[(x << 1) + 4] = (uint8)CF(CF4D * (int32)lin[x] + CF4C * (int32)lin[x + 1] + CF4B * (int32)lin[x + 2] + CF4A * (int32)lin[x + 3]);
        }
        lin += c->stride;
        lout += c->width << 1;
        lout[-3] = (uint8)CF(CF3A * (int32)lin[-1] + CF3B * (int32)lin[-2] + CF3C * (int32)lin[-3]);
        lout[-2] = (uint8)CF(CF3X * (int32)lin[-1] + CF3Y * (int32)lin[-2] + CF3Z * (int32)lin[-3]);
        lout[-1] = (uint8)CF(CF2A * (int32)lin[-1] + CF2B * (int32)lin[-2]);
    }
    c->width <<= 1;
    c->stride = c->width;
    free(c->pixels);
    c->pixels = data;
}

void ujUpsampleVCentered(ujComponent *c)
{
    printf("ujUpsampleVCentered\n");
    int32 w = c->width, s1 = c->stride, s2 = s1 + s1;
    uint8 *data, *cin, *cout;
    int32 x, y;
    data = (uint8*)malloc((c->width * c->height) << 1);

    for (x = 0; x < w; ++x)
    {
        cin = &c->pixels[x];
        cout = &data[x];
        *cout = (uint8)CF(CF2A * (int32)cin[0] + CF2B * (int32)cin[s1]);
        cout += w;
        *cout = (uint8)CF(CF3X * (int32)cin[0] + CF3Y * (int32)cin[s1] + CF3Z * (int32)cin[s2]);
        cout += w;
        *cout = (uint8)CF(CF3A * (int32)cin[0] + CF3B * (int32)cin[s1] + CF3C * (int32)cin[s2]);
        cout += w;
        cin += s1;
        for (y = c->height - 3; y != 0; --y)
        {
            *cout = (uint8)CF(CF4A * (int32)cin[-s1] + CF4B * (int32)cin[0] + CF4C * (int32)cin[s1] + CF4D * (int32)cin[s2]);
            cout += w;
            *cout = (uint8)CF(CF4D * (int32)cin[-s1] + CF4C * (int32)cin[0] + CF4B * (int32)cin[s1] + CF4A * (int32)cin[s2]);
            cout += w;
            cin += s1;
        }
        cin += s1;
        *cout = (uint8)CF(CF3A * (int32)cin[0] + CF3B * (int32)cin[-s1] + CF3C * (int32)cin[-s2]);
        cout += w;
        *cout = (uint8)CF(CF3X * (int32)cin[0] + CF3Y * (int32)cin[-s1] + CF3Z * (int32)cin[-s2]);
        cout += w;
        *cout = (uint8)CF(CF2A * (int32)cin[0] + CF2B * (int32)cin[-s1]);
    }
    c->height <<= 1;
    c->stride = c->width;
    free(c->pixels);
    c->pixels = data;
}

uint8 SF(uint8 x)
{
    return ujClip(((int32)(x) + 8) >> 4);
}

void ujUpsampleHCoSited(ujComponent *c)
{
    printf("ujUpsampleHCoSited\n");
    printf("Co-Sited not supported\n");
    exit(-1);
    // int32 xmax = c->width - 1;
    // uint8 *data, *lin, *lout;
    // int32 x, y;
    // data = (uint8*)malloc((c->width * c->height) << 1);

    // lin = c->pixels;
    // lout = data;
    // for (y = c->height; y != 0; --y)
    // {
    //     lout[0] = lin[0];
    //     lout[1] = SF((lin[0] << 3) + 9 * lin[1] - lin[2]);
    //     lout[2] = lin[1];
    //     for (x = 2; x < xmax; ++x)
    //     {
    //         lout[(x << 1) - 1] = SF(9 * (lin[x - 1] + lin[x]) - (lin[x - 2] + lin[x + 1]));
    //         lout[x << 1] = lin[x];
    //     }
    //     lin += c->stride;
    //     lout += c->width << 1;
    //     lout[-3] = SF((lin[-1] << 3) + 9 * lin[-2] - lin[-3]);
    //     lout[-2] = lin[-1];
    //     lout[-1] = SF(17 * lin[-1] - lin[-2]);
    // }
    // c->width <<= 1;
    // c->stride = c->width;
    // free(c->pixels);
    // c->pixels = data;
}

void ujUpsampleVCoSited(ujComponent *c)
{
    printf("ujUpsampleVCoSited\n");
    printf("Co-Sited not supported\n");
    exit(-1);

    // int32 w = c->width, s1 = c->stride, s2 = s1 + s1;
    // uint8 *data, *cin, *cout;
    // int32 x, y;
    // data = (uint8*)malloc((c->width * c->height) << 1);

    // for (x = 0; x < w; ++x)
    // {
    //     cin = &c->pixels[x];
    //     cout = &data[x];
    //     *cout = cin[0];
    //     cout += w;
    //     *cout = SF((cin[0] << 3) + 9 * cin[s1] - cin[s2]);
    //     cout += w;
    //     *cout = cin[s1];
    //     cout += w;
    //     cin += s1;
    //     for (y = c->height - 3; y != 0; --y)
    //     {
    //         *cout = SF(9 * (cin[0] + cin[s1]) - (cin[-s1] + cin[s2]));
    //         cout += w;
    //         *cout = cin[s1];
    //         cout += w;
    //         cin += s1;
    //     }
    //     *cout = SF((cin[s1] << 3) + 9 * cin[0] - cin[-s1]);
    //     cout += w;
    //     *cout = cin[-s1];
    //     cout += w;
    //     *cout = SF(17 * cin[s1] - cin[0]);
    // }
    // c->height <<= 1;
    // c->stride = c->width;
    // free(c->pixels);
    // c->pixels = data;
}

void ujUpsampleFast(ujContext *uj, ujComponent *c)
{
    printf("ujUpsampleFast\n");
    printf("Upsample Fast not supported\n");
    exit(-1);
    // int32 x, y, xshift = 0, yshift = 0;
    // uint8 *data, *lin, *lout;
    // while (c->width < uj->width)
    // {
    //     c->width <<= 1;
    //     ++xshift;
    // }
    // while (c->height < uj->height)
    // {
    //     c->height <<= 1;
    //     ++yshift;
    // }
    // if (xshift == 0 && yshift == 0)
    //     return;
    // data = (uint8*)malloc(c->width * c->height);

    // lin = c->pixels;
    // lout = data;
    // for (y = 0; y < c->height; ++y)
    // {
    //     lin = &c->pixels[(y >> yshift) * c->stride];
    //     for (x = 0; x < c->width; ++x)
    //         lout[x] = lin[x >> xshift];
    //     lout += c->width;
    // }
    // c->stride = c->width;
    // free(c->pixels);
    // c->pixels = data;
}

void ujConvert(ujContext *uj, uint8 *pout2)
{
    uint8* pout = pout2;
    printf("ujConvert\n");
    int32 i;
    ujComponent *c;
    for (i = 0, c = &uj->comp[0]; i < uj->ncomp; ++i, ++c)
    {
        if (uj->fast_chroma != 0)
        {
            ujUpsampleFast(uj, c);
        }
        else
        {
            while ((c->width < uj->width) || (c->height < uj->height))
            {
                if (c->width < uj->width)
                {
                    if (uj->co_sited_chroma != 0)
                        ujUpsampleHCoSited(c);
                    else
                        ujUpsampleHCentered(c);
                }
                if (c->height < uj->height)
                {
                    if (uj->co_sited_chroma != 0)
                        ujUpsampleVCoSited(c);
                    else
                        ujUpsampleVCentered(c);
                }
            }
        }
        if ((c->width < uj->width) || (c->height < uj->height))
        {
            printf("UJ_INTERNAL_ERR\n");
            exit(-1);
        }
    }
    if (uj->ncomp == 3)
    {
        printf("RGB!!!!\n");
        // convert to RGB
        int32 x, yy;
        uint8 *py = uj->comp[0].pixels;
        uint8 *pcb = uj->comp[1].pixels;
        uint8 *pcr = uj->comp[2].pixels;
        for (yy = uj->height; yy != 0; --yy)
        {
            for (x = 0; x < uj->width; ++x)
            {
                int32 y = (int32)py[x] << 8;
                int32 cb = (int32)pcb[x] - 128;
                int32 cr = (int32)pcr[x] - 128;
                *pout = ujClip((y + 359 * cr + 128) >> 8);
                pout++;
                *pout = ujClip((y - 88 * cb - 183 * cr + 128) >> 8);
                pout++;
                *pout = ujClip((y + 454 * cb + 128) >> 8);
                pout++;
                *pout = 255;
                pout++;
            }
            py += uj->comp[0].stride;
            pcb += uj->comp[1].stride;
            pcr += uj->comp[2].stride;
        }
    }
    else
    {
        printf("grayscale!!!!\n");
        // grayscale -> only remove stride
        // uint8 *pin = &uj->comp[0].pixels[uj->comp[0].stride];
        // int32 y;
        // for (y = uj->height - 1; y != 0; --y)
        // {
        //     memcpy(pout, pin, uj->width);
        //     pin += uj->comp[0].stride;
        //     pout += uj->width;
        // }

        int32 x, yy;
        uint8 *p = uj->comp[0].pixels;
        for (yy = uj->height; yy != 0; --yy)
        {
            for (x = 0; x < uj->width; ++x)
            {
                uint8 g = (uint8)p[x];
                *pout = g;
                pout++;
                *pout = g;
                pout++;
                *pout = g;
                pout++;
                *pout = 255;
                pout++;
            }
            p += uj->comp[0].stride;
        }
    }
}

void ujDone(ujContext *uj)
{
    printf("ujDone\n");
    int32 i;
    for (i = 0; i < 3; ++i)
        if (uj->comp[i].pixels != NULL)
            free((void *)uj->comp[i].pixels);
    if (uj->rgb != NULL)
        free((void *)uj->rgb);
}

void ujInit(ujContext *uj)
{
    printf("ujInit\n");
    int32 save_no_decode = uj->no_decode;
    int32 save_fast_chroma = uj->fast_chroma;
    ujDone(uj);
    memset(uj, 0, sizeof(ujContext));
    uj->no_decode = save_no_decode;
    uj->fast_chroma = save_fast_chroma;
}

///////////////////////////////////////////////////////////////////////////////

uint16 ujGetExif16(ujContext *uj, uint8 *p)
{
    if (uj->exif_le != 0)
        return (uint16)p[0] + ((uint16)p[1] << 8);
    else
        return ((uint16)p[0] << 8) + (uint16)p[1];
}

int32 ujGetExif32(ujContext *uj, uint8 *p)
{
    if (uj->exif_le != 0)
        return (int32)p[0] + ((int32)p[1] << 8) + ((int32)p[2] << 16) + ((int32)p[3] << 24);
    else
        return ((int32)p[0] << 24) + ((int32)p[1] << 16) + ((int32)p[2] << 8) + (int32)p[3];
}

void ujDecodeExif(ujContext *uj)
{
    printf("ujDecodeExif\n");
    uint8 *pos;
    int32 size, count, i;
    if (uj->no_decode != 0 || uj->fast_chroma != 0)
    {
        ujSkipMarker(uj);
        return;
    }
    ujDecodeLength(uj);
    pos = uj->pos;
    size = uj->length;
    ujSkip(uj, uj->length);
    if (size < 18)
        return;
    if (memcmp(pos, "Exif\0\0II*\0", 10) == 0){
      printf("exif_le = 1\n");
      uj->exif_le = 1;
    }
    else if (memcmp(pos, "Exif\0\0MM\0*", 10) == 0){
      printf("exif_le = 0\n");
        uj->exif_le = 0;
    }
    else {
        return; // invalid Exif header
    }
    i = ujGetExif32(uj, pos + 10) + 6;
    if ((i < 14) || (i > (size - 2)))
        return;
    printf("ujGetExif32\n");
    pos += i;
    size -= i;
    count = (int32)ujGetExif16(uj, pos);
    printf("count = %i\n", count);
    i = (size - 2) / 12;
    if (count > i) {
      printf("count > i, i = %i\n", i);
      return;
    }
    pos += 2;

    while (count != 0)
    {
        count --;
        if ((ujGetExif16(uj, pos) == 0x0213)   // tag = YCbCrPositioning
            && (ujGetExif16(uj, pos + 2) == 3) // type = SHORT
            && (ujGetExif32(uj, pos + 4) == 1) // length = 1
        )
        {
            uj->co_sited_chroma = (int32)(ujGetExif16(uj, pos + 8) == 2);
            printf("co_sited_chroma = %i\n", uj->co_sited_chroma);
            return;
        }
        pos += 12;
    }
    printf("done jklkf\n");
}

///////////////////////////////////////////////////////////////////////////////

ujImage ujCreate(void)
{
    printf("decodeAPP0\n");
    ujContext *uj = (ujContext *)malloc(sizeof(ujContext));
    memset(uj, 0, sizeof(ujContext));
    // check for null
    return (ujImage)uj;
}

int32 ujDecode(ujImage img, void *jpeg, int32 size)
{
    //printf("ujDecode\n");
    ujContext *uj = (ujContext *)(img);

    uj->pos = (uint8 *)jpeg;
    uj->size = size & 0x7FFFFFFF;
    if (uj->size < 2)
    {
        {
            printf("UJ_NO_JPEG");
            exit(-1);
        }
    }
    if ((uj->pos[0] ^ 0xFF) != 0 | (uj->pos[1] ^ 0xD8) != 0)
    {
        {
            printf("UJ_NO_JPEG");
            exit(-1);
        }
    }
    ujSkip(uj, 2);
    while (1 != 0)
    {
        if ((uj->size < 2) || (uj->pos[0] != 0xFF))
        {
            // {printf("UJ_SYNTAX_ERROR"); exit(-1);}
            printf("break???\n");
            break;
        }
        ujSkip(uj, 2);
        switch (uj->pos[-1])
        {
        case 0xC0:
            // Start Of Frame (Baseline DCT)
            ujDecodeSOF(uj);
            break;
        case 0xC4:
            // Define Huffman Table
            ujDecodeDHT(uj);
            break;
        case 0xDB:
            // Define Quantization Table(s)
            ujDecodeDQT(uj);
            break;
        case 0xDD:
            // Define Restart Interval
            ujDecodeDRI(uj);
            break;
        case 0xDA:
            // Start Of Scan
            ujDecodeScan(uj);
            break;
        case 0xFE:
            // Comment
            ujSkipMarker(uj);
            break;
        case 0xE1:
            ujDecodeExif(uj);
            break;
        case 0XC2:
            // SOF2
            printf("Progressive DCT not supported\n");
            exit(-1);
        // case 0xEn: Application-specific
        // case 0xD9: Endd Of Image
        default:
            if ((uj->pos[-1] & 0xF0) == 0xE0)
            {
                ujSkipMarker(uj);
            }
            else
            {

                printf("UJ_UNSUPPORTED %i\n", uj->pos[-1]);
                exit(-1);

            }
        }
    }
    return 1;
}

int32 ujGetWidth(ujImage img)
{
    ujContext *uj = (ujContext *)img;
    return uj->width;
}

int32 ujGetHeight(ujImage img)
{
    ujContext *uj = (ujContext *)img;
    return uj->height;
}

int32 ujGetImageSize(ujImage img)
{
    ujContext *uj = (ujContext *)img;
    return uj->width * uj->height * uj->ncomp;
}

ujPlane *ujGetPlane(ujImage img, int32 num)
{
    ujContext *uj = (ujContext *)img;
    return (ujPlane *)&uj->comp[num];
}

void ujGetImage(ujImage img, uint8 *dest)
{
    printf("ujGetImage\n");
    ujContext *uj = (ujContext *)img;
    if (dest != NULL)
    {
        ujConvert(uj, dest);
    }
}

void ujDestroy(ujImage img)
{
    ujDone((ujContext *)img);
    free(img);
}
