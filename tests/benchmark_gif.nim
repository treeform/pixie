import benchy, pixie/fileformats/gif

let data = readFile("tests/fileformats/gif/audrey.gif")

timeIt "pixie decode":
  keep decodeGif(data)
