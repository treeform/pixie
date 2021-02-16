import pixie/common, pixie/fileformats/jpg, random, strformat

randomize()

let original = cast[seq[uint8]](readFile("tests/images/jpg/jpeg420exif.jpg"))

for i in 0 ..< 10_000:
  var data = original
  let
    pos = rand(data.len)
    value = rand(255).uint8
  data[pos] = value
  echo &"{i} {pos} {value}"
  try:
    let img = decodeJpg(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard

  data = data[0 ..< pos]
  try:
    let img = decodeJpg(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard
