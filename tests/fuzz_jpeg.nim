import jpegsuite, pixie/common, pixie/fileformats/jpeg, random, strformat

randomize()

for i in 0 ..< 10_000:
  let file = sample(jpegSuiteFiles)
  var data = readFile(file)
  let
    pos = rand(0 ..< data.len)
    value = rand(255).uint8
  data[pos] = value.char
  echo &"{i} {file} {pos} {value}"

  try:
    let img = decodeJpeg(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard
  data = data[0 ..< pos]
  try:
    let img = decodeJpeg(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard
