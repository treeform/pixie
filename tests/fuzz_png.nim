import pixie/common, pixie/fileformats/png, pngsuite, random, strformat

randomize()

for i in 0 ..< 10_000:
  let file = pngSuiteFiles[rand(pngSuiteFiles.len - 1)]
  var data = readFile(&"tests/fileformats/png/pngsuite/{file}.png")
  let
    pos = 29 + rand(data.len - 30)
    value = rand(255).uint8
  data[pos] = value.char
  echo &"{i} {file} {pos} {value}"
  try:
    let img = decodePng(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard

  data = data[0 ..< pos]
  try:
    let img = decodePng(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard
