import benchy, jpegsuite, pixie/fileformats/jpeg, stb_image/read as stbi,
    strformat, os

for file in jpegSuiteFiles:
  let data = readFile(file)
  var name = file.splitPath.tail
  name.setLen(min(name.len, 22))
  timeIt &"pixie {name} decode":
    discard decodeJpeg(data)

block:
  for file in jpegSuiteFiles:
    let data = readFile(file)
    var name = file.splitPath.tail
    name.setLen(min(name.len, 22))
    timeIt &"stb {name} decode":
      var width, height, channels: int
      discard loadFromMemory(
        cast[seq[byte]](data),
        width,
        height,
        channels,
        stbi.RGBA
      )
