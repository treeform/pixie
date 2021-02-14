import benchy, nimPNG, pixie/fileformats/png, stb_image/read as stbi,
    stb_image/write as stbr

let data = readFile("tests/images/png/lenna.png")

timeIt "pixie decode":
  keep decodePng(cast[seq[uint8]](data))

timeIt "pixie encode":
  let decoded = decodePng(cast[seq[uint8]](data))
  keep encodePng(decoded).len

timeIt "nimPNG decode":
  keep decodePNG32(data)

timeIt "nimPNG encode":
  let decoded = decodePNG32(data)
  keep encodePNG32(decoded.data, decoded.width, decoded.height).pixels.len

timeIt "stb_image decode":
  var width, height, channels: int
  keep loadFromMemory(
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
  keep writePNG(width, height, channels, decoded).len
