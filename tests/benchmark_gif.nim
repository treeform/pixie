import benchy, pixie/fileformats/gif

let data = readFile("tests/fileformats/gif/audrey.gif")

timeIt "gif decode":
  discard decodeGif(data)
