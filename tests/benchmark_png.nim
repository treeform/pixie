import benchy, cairo, nimPNG, pixie/fileformats/png, stb_image/read as stbi,
    stb_image/write as stbr

let
  filePath = "tests/images/png/lenna.png"
  data = readFile(filePath)

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

timeIt "cairo decode":
  keep imageSurfaceCreateFromPng(filePath)

timeIt "cairo encode":
  let decoded = imageSurfaceCreateFromPng(filePath)

  var write: WriteFunc =
    proc(closure: pointer, data: cstring, len: int32): Status {.cdecl.} =
      StatusSuccess

  discard decoded.writeToPng(write, nil)
