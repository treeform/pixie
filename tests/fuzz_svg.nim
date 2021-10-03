import pixie/common, pixie/fileformats/svg, random, strformat

randomize()

let original = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")

for i in 0 ..< 10_000:
  var data = original
  let
    pos = rand(data.len)
    value = rand(255).char
  data[pos] = value
  echo &"{i} {pos} {value}"
  try:
    discard decodeSvg(data)
  except PixieError:
    discard
