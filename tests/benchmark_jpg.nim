import pixie/fileformats/jpg, pixie/fileformats/stb_image/stb_image, fidget/opengl/perf

let data = readFile("tests/images/jpg/jpeg420exif.jpg")

timeIt "pixie decode":
  for i in 0 ..< 20:
    discard decodeJpg(cast[seq[uint8]](data))

timeIt "stb_image decode":
  for i in 0 ..< 20:
    var
      width: int
      height: int
    discard loadFromMemory(cast[seq[uint8]](data), width, height)
