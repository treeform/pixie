import pixie/common, pixie/fileformats/gif, random, strformat

randomize()

let original = readFile("tests/fileformats/gif/sunflower.gif")

for i in 0 ..< 10_000:
  var data = original
  let
    pos = rand(data.len)
    value = rand(255).char
    # pos = 27355
    # value = '&'
  data[pos] = value
  echo &"{i} {pos} {value}"
  try:
    let img = newImage(decodeGif(data))
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard

  data = data[0 ..< pos]
  try:
    let img = newImage(decodeGif(data))
    doAssert img.height > 0 and img.width > 0
  except PixieError:
    discard
