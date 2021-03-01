import benchy, pixie/fileformats/gif

let data = readFile("tests/images/gif/audrey.gif")

timeIt "pixie decode":
  keep decodeGif(data)
