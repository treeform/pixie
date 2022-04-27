import flatty/binny, os, pixie/common, pixie/fileformats/bmp, random, strformat

randomize()

var originals = @["tests/fileformats/bmp/knight.32.bmp"]
for file in walkFiles("tests/fileformats/bmp/bmpsuite/*"):
  originals.add(file)

for i in 0 ..< 1000:
  let file = originals[rand(originals.len-1)]
  var data = readFile(file)
  let
    pos = rand(data.len-1)
    value = rand(255).char
    # pos = 27355
    # value = '&'
  data[pos] = value

  let
    width = data.readInt32(18).int
    height = data.readInt32(22).int
  if abs(width) > 1000 or abs(height) > 1000:
    echo "too big"
    continue

  echo &"{i} {file} {pos} {repr(value)}"
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
