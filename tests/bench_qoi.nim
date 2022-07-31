import benchy, pixie/fileformats/qoi

let data = readFile("tests/fileformats/qoi/testcard_rgba.qoi")

timeIt "pixie decode":
  discard decodeQoi(data)
