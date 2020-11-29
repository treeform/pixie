import pixie/fileformats/png, stb_image/read as stbi, stb_image/write as stbr,
  fidget/opengl/perf, nimPNG

let data = readFile("tests/images/png/lenna.png")

timeIt "pixie decode":
  for i in 0 ..< 100:
    discard decodePng(cast[seq[uint8]](data))

timeIt "pixie encode":
  let decoded = decodePng(cast[seq[uint8]](data))
  for i in 0 ..< 1:
    discard encodePng(decoded).len

timeIt "nimPNG decode":
  for i in 0 ..< 100:
    discard decodePNG32(data)

timeIt "nimPNG encode":
  let decoded = decodePNG32(data)
  for i in 0 ..< 100:
    discard encodePNG32(decoded.data, decoded.width, decoded.height).pixels.len

timeIt "stb_image decode":
  for i in 0 ..< 100:
    var width, height, channels: int
    discard loadFromMemory(
      cast[seq[byte]](data),
      width,
      height,
      channels,
      stbi.RGBA
    )

timeIt "stb_image encode":
  var width, height, channels: int
  let decoded = loadFromMemory(
    cast[seq[byte]](data),
    width,
    height,
    channels,
    stbi.RGBA
  )
  for i in 0 ..< 100:
    discard writePNG(width, height, channels, decoded).len
