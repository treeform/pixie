import benchy, os, pixie/fileformats/jpeg

const
  jpegFiles* = [
    "tests/fileformats/jpeg/masters/mandrill.jpg",
    "tests/fileformats/jpeg/masters/exif_overrun.jpg",
    "tests/fileformats/jpeg/masters/grayscale_test.jpg",
    "tests/fileformats/jpeg/masters/progressive.jpg"
  ]

for file in jpegFiles:
  let data = readFile(file)
  timeIt "pixie " & file.splitPath.tail & " decode":
    discard decodeJpeg(data)

# import stb_image/read as stbi
# block:
#   for file in jpegFiles:
#     let data = readFile(file)
#     var name = file.splitPath.tail

#     timeIt "stb " & file.splitPath.tail & " decode":
#       var width, height, channels: int
#       discard loadFromMemory(
#         cast[seq[byte]](data),
#         width,
#         height,
#         channels,
#         stbi.RGBA
#       )
