import pixie/common, pixie/fileformats/webp, random, strformat, webpsuite

const Iterations =
  when defined(fuzzShort): 100
  else: 10_000

randomize()

proc checkDimensions(data: string) =
  try:
    let dimensions = decodeWebpDimensions(data)
    doAssert dimensions.width > 0 and dimensions.height > 0

    let info = decodeWebpInfo(data)
    doAssert info.width > 0 and info.height > 0
  except PixieError:
    discard

proc checkDecode(data: string) =
  try:
    let img = decodeWebp(data)
    doAssert img.width > 0 and img.height > 0
  except PixieError:
    discard

for i in 0 ..< Iterations:
  let file = WebpSuiteFiles[rand(WebpSuiteFiles.len - 1)]
  var data = readFile(file)
  let
    pos = rand(0 ..< data.len)
    bit = uint8(1 shl rand(7))
    value = data[pos].uint8 xor bit
  data[pos] = value.char
  echo &"{i} {file} {pos} {value}"
  checkDimensions(data)
  checkDecode(data)

  data = data[0 ..< pos]
  checkDimensions(data)
  checkDecode(data)
