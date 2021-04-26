import common, pixie, random, strformat, unicode

randomize()

let fontPaths = findAllFonts("tests/fonts")

doAssert fontPaths.len > 0

for i in 0 ..< 10000:
  var
    file = fontPaths[rand(fontPaths.len - 1)]
    data = readFile(file)
    pos = rand(data.len)
    value = rand(255).char
  data[pos] = value
  echo &"{i} {file} {pos} {value.uint8}"
  try:
    let font = parseOtf(data)
    doAssert font != nil
    for i in 0.uint16 ..< uint16.high:
      discard font.getGlyphPath(Rune(i.int))
  except PixieError:
    discard

  data = data[0 ..< pos]
  try:
    let font = parseOtf(data)
    doAssert font != nil
    for i in 0.uint16 ..< uint16.high:
      discard font.getGlyphPath(Rune(i.int))
  except PixieError:
    discard
