import pixie/fileformats/png, stb_image/read as stbi, fidget/opengl/perf, nimPNG

let data = readFile("tests/data/lenna.png")

timeIt "pixie":
  for i in 0 ..< 100:
    discard decodePng(cast[seq[uint8]](data))

timeIt "nimPNG":
  for i in 0 ..< 100:
    discard decodePNG32(data)

timeIt "stb_image":
  for i in 0 ..< 100:
    var width, height, channels: int
    discard loadFromMemory(
      cast[seq[byte]](data),
      width,
      height,
      channels,
      stbi.RGBA
    )
