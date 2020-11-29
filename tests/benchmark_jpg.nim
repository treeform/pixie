import pixie/fileformats/jpgstb, fidget/opengl/perf

let data = readFile("tests/images/jpg/jpeg420exif.jpg")

timeIt "pixie decode":
  for i in 0 ..< 20:
    discard decodeJpg(cast[seq[uint8]](data))
