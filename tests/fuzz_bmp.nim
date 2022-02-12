import pixie/common, pixie/fileformats/bmp, random, strformat, flatty/binny, os

randomize()

var originals = @[readFile("tests/fileformats/bmp/knight.32.bmp")]
for file in walkFiles("tests/fileformats/bmp/bmpsuite/*"):
  originals.add(readFile(file))

for i in 0 ..< 100_000:
  var data = originals[rand(originals.len-1)]
  let
    pos = rand(data.len-1)
    value = rand(255).char
    # pos = 27355
    # value = '&'
  data[pos] = value

  let
    width = data.readInt32(18).int
    height = data.readInt32(22).int
    numColors = data.readInt32(46).int
  if abs(width) > 1000 or abs(height) > 1000 or numColors > 1000:
    echo "too big"
    continue

  echo &"{i} {pos} {repr(value)}"
  try:
    let img = decodeBmp(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard

  data = data[0 ..< pos]
  try:
    let img = decodeBmp(data)
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard
