import benchy, jpegsuite, pixie/fileformats/jpeg, stb_image/read as stbi, strformat

for file in jpegSuiteFiles:
  let data = readFile(file)
  timeIt &"pixie jpeg {(data.len div 1024)}k decode":
    discard decodeJpeg(data)

block:
  for file in jpegSuiteFiles:
    let data = readFile(file)
    timeIt &"stb_image jpeg {(data.len div 1024)}k decode":
      var width, height, channels: int
      discard loadFromMemory(
        cast[seq[byte]](data),
        width,
        height,
        channels,
        stbi.RGBA
      )
