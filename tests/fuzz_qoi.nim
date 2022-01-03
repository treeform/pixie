import std/[random, strformat]
import pixie/[common, fileformats/qoi]

randomize()

let original = readFile("tests/fileformats/qoi/testcard_rgba.qoi")

for i in 0 ..< 10_000:
  var data = original
  let
    pos = rand(data.len)
    value = rand(255).char
  data[pos] = value
  try:
    let img = decodeQOI(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard

  data = data[0 ..< pos]
  try:
    let img = decodeQOI(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard
