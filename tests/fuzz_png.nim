import random, strformat, pixie/fileformats/png, pixie/common, pngsuite

randomize()

for i in 0 ..< 10_000:
  let file = pngSuiteFiles[rand(pngSuiteFiles.len - 1)]
  var data = cast[seq[uint8]](readFile(&"tests/images/pngsuite/{file}.png"))
  let
    pos = 29 + rand(data.len - 30)
    value = rand(255).uint8
  data[pos] = value
  echo &"{i} {file} {pos} {value}"
  try:
    discard decodePng(data)
  except PixieError:
    discard
