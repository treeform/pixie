import benchy, pixie/fileformats/jpg

let data = readFile("tests/fileformats/jpeg/jpeg420exif.jpg")

timeIt "pixie decode":
  discard decodeJpg(data)
