import pixie/fileformats/png, strformat, pngsuite

for file in pngSuiteFiles:
  let
    original = cast[seq[uint8]](readFile(&"tests/data/pngsuite/{file}.png"))
    decoded = decodePng(original)
    encoded = encodePng(decoded)
    decoded2 = decodePng(cast[seq[uint8]](encoded))

  doAssert decoded.height == decoded2.height
  doAssert decoded.width == decoded2.width
  doAssert decoded.data == decoded2.data

for channels in 1 .. 4:
  var data: seq[uint8]
  for x in 0 ..< 16:
    for y in 0 ..< 16:
        var components = newSeq[uint8](channels)
        for i in 0 ..< channels:
          components[i] = (x * 16).uint8
        data.add(components)
  let encoded = encodePng(16, 16, channels, data[0].addr, data.len)
