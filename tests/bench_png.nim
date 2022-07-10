import benchy, pixie/fileformats/png

let
  filePath = "tests/fileformats/png/lenna.png"
  data = readFile(filePath)

block:
  let
    decodedPng = decodePng(data)
    decodedImage = newImage(decodedPng)

  timeIt "pixie decode":
    discard decodePng(data)

  timeIt "pixie decode + alpha":
    discard decodePng(data).convertToImage()

  timeIt "pixie encode":
    discard encodePng(decodedPng)

  timeIt "pixie encode + alpha":
    discard encodePng(decodedImage)

# import nimPNG
# block:
#   timeIt "nimPNG decode":
#     discard decodePNG32(data)

#   let decoded = decodePNG32(data)
#   timeIt "nimPNG encode":
#     discard encodePNG32(decoded.data, decoded.width, decoded.height)

# import stb_image/read as stbi, stb_image/write as stbr
# block:
#   timeIt "stb_image decode":
#     var width, height, channels: int
#     discard loadFromMemory(
#       cast[seq[byte]](data),
#       width,
#       height,
#       channels,
#       stbi.RGBA
#     )

#   var width, height, channels: int
#   let decoded = loadFromMemory(
#     cast[seq[byte]](data),
#     width,
#     height,
#     channels,
#     stbi.RGBA
#   )

#   timeIt "stb_image encode":
#     discard writePNG(width, height, channels, decoded).len

# import cairo
# block:
#   timeIt "cairo decode":
#     discard imageSurfaceCreateFromPng(filePath.cstring)

#   let decoded = imageSurfaceCreateFromPng(filePath.cstring)
#   timeIt "cairo encode":
#     var write: WriteFunc =
#       proc(closure: pointer, data: cstring, len: int32): Status {.cdecl.} =
#         StatusSuccess
#     discard decoded.writeToPng(write, nil)
