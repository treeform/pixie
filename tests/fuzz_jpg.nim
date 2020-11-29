import random, strformat, pixie/fileformats/jpg, pixie/common

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
    discard decodeJpg(data)
  except PixieError:
    discard
