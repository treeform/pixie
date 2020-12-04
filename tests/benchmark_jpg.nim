import pixie/fileformats/jpg, benchy

let data = readFile("tests/images/jpg/jpeg420exif.jpg")

timeIt "pixie decode":
  discard decodeJpg(cast[seq[uint8]](data))
