import benchy, pixie/fileformats/jpeg, jpegsuite, os, stb_image/read as stbi

for file in jpegSuiteFiles:
  let data = readFile(file)

  timeIt "pixie " & file.splitPath.tail & " decode", 10:
    discard decodeJpeg(data)

block:
  for file in jpegSuiteFiles:
    let data = readFile(file)
    var name = file.splitPath.tail

    timeIt "stb " & file.splitPath.tail & " decode", 10:
      var width, height, channels: int
      discard loadFromMemory(
        cast[seq[byte]](data),
        width,
        height,
        channels,
        stbi.RGBA
      )
