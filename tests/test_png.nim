import pixie, pixie/fileformats/png, pngsuite, strformat

for file in pngSuiteFiles:
  let
    original = readFile(&"tests/fileformats/png/pngsuite/{file}.png")
    decoded = decodePng(original)
    encoded = encodePng(decoded)

block:
  for channels in 1 .. 4:
    var data: seq[uint8]
    for x in 0 ..< 16:
      for y in 0 ..< 16:
        var components = newSeq[uint8](channels)
        for i in 0 ..< channels:
          components[i] = (x * 16).uint8
        data.add(components)
    let encoded = encodePng(16, 16, channels, data[0].addr, data.len)

  for file in pngSuiteCorruptedFiles:
    try:
      discard decodePng(readFile(&"tests/fileformats/png/pngsuite/{file}.png"))
      doAssert false
    except PixieError:
      discard

block:
  discard readImage("tests/fileformats/png/trailing_data.png")

block:
  let dimensions =
    decodeImageDimensions(readFile("tests/fileformats/png/mandrill.png"))
  doAssert dimensions.width == 512
  doAssert dimensions.height == 512
