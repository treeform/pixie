import pixie, pixie/fileformats/webp, webpsuite

proc checkDimensions(path: string, width, height: int) =
  let
    data = readFile(path)
    info = decodeWebpInfo(data)
    dimensions = decodeWebpDimensions(data)
    pointerDimensions = decodeWebpDimensions(data.cstring, data.len)
    readDimensions = readImageDimensions(path)

  doAssert info.width == width
  doAssert info.height == height
  doAssert dimensions.width == width
  doAssert dimensions.height == height
  doAssert pointerDimensions.width == width
  doAssert pointerDimensions.height == height
  doAssert readDimensions.width == width
  doAssert readDimensions.height == height

block:
  doAssert WebpSuiteFiles.len == 129

  var
    lossyCount, losslessCount, alphaCount, vp8XCount: int

  for path in WebpSuiteFiles:
    let
      data = readFile(path)
      info = decodeWebpInfo(data)
      dimensions = decodeWebpDimensions(data)

    doAssert info.width == dimensions.width
    doAssert info.height == dimensions.height
    doAssert info.fileSize <= data.len
    doAssert info.chunks.len > 0

    case info.compression
    of LossyWebp:
      inc lossyCount
      doAssert info.vp8Offset > 0
      doAssert info.vp8Size > 0
      let image = readImage(path)
      doAssert image.width == info.width
      doAssert image.height == info.height
    of LosslessWebp:
      inc losslessCount
      doAssert info.vp8LOffset > 0
      doAssert info.vp8LSize > 0
      let image = readImage(path)
      doAssert image.width == info.width
      doAssert image.height == info.height
    of UnknownWebpCompression:
      doAssert info.hasAnimation

    if info.hasAlpha:
      inc alphaCount
    if info.hasVp8X:
      inc vp8XCount

  doAssert lossyCount > 0
  doAssert losslessCount > 0
  doAssert alphaCount > 0
  doAssert vp8XCount > 0

checkDimensions("tests/fileformats/webp/small_1x1.webp", 1, 1)
checkDimensions("tests/fileformats/webp/small_1x13.webp", 1, 13)
checkDimensions("tests/fileformats/webp/small_13x1.webp", 13, 1)
checkDimensions("tests/fileformats/webp/small_31x13.webp", 31, 13)
checkDimensions("tests/fileformats/webp/test.webp", 128, 128)
checkDimensions("tests/fileformats/webp/lossy_q0_f100.webp", 128, 128)
checkDimensions("tests/fileformats/webp/lossless1.webp", 1000, 307)
checkDimensions("tests/fileformats/webp/lossy_alpha1.webp", 1000, 307)
checkDimensions("tests/fileformats/webp/alpha_no_compression.webp", 16, 16)
checkDimensions("tests/fileformats/webp/one_color_no_palette.webp", 100, 100)
checkDimensions("tests/fileformats/webp/near_lossless_75.webp", 256, 256)
checkDimensions("tests/fileformats/webp/vp80-00-comprehensive-016.webp", 176, 144)

block:
  let lossless = decodeWebpInfo(readFile("tests/fileformats/webp/lossless1.webp"))
  doAssert lossless.compression == LosslessWebp
  doAssert lossless.losslessAlpha

block:
  let lossyAlpha = decodeWebpInfo(readFile("tests/fileformats/webp/lossy_alpha1.webp"))
  doAssert lossyAlpha.compression == LossyWebp
  doAssert lossyAlpha.hasVp8X
  doAssert lossyAlpha.hasAlpha
  doAssert lossyAlpha.alphaOffset > 0
  doAssert lossyAlpha.alphaInfo.compressionMethod in [0, 1]
  doAssert lossyAlpha.alphaInfo.filterMethod in 0 .. 3

block:
  let rawAlpha = decodeWebpInfo(
    readFile("tests/fileformats/webp/alpha_no_compression.webp")
  )
  doAssert rawAlpha.hasAlpha
  doAssert rawAlpha.alphaInfo.compressionMethod == 0
