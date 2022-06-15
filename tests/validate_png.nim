import chroma, pixie/fileformats/png, pngsuite, stb_image/read as stbi, strformat

for file in pngSuiteFiles:
  let
    data = readFile(&"tests/fileformats/png/pngsuite/{file}.png")
    pixieLoaded = decodePng(data)

  var
    width, height, channels: int
    stbiLoadedData = loadFromMemory(
      cast[seq[byte]](data),
      width,
      height,
      channels,
      stbi.RGBA
    )
    stbiLoadedRGBA: seq[ColorRGBA]

  var i: int
  while i < stbiLoadedData.len:
    stbiLoadedRGBA.add(ColorRGBA(
      r: stbiLoadedData[i + 0],
      g: stbiLoadedData[i + 1],
      b: stbiLoadedData[i + 2],
      a: stbiLoadedData[i + 3]
    ))
    i += 4

  doAssert pixieLoaded.width == width
  doAssert pixieLoaded.height == height
  doAssert pixieLoaded.data.len == stbiLoadedRGBA.len
  doAssert pixieLoaded.data == stbiLoadedRGBA
