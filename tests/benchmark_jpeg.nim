import benchy, jpegsuite, pixie/fileformats/jpeg, strformat

for file in jpegSuiteFiles:
  let data = readFile(file)
  timeIt &"jpeg {(data.len div 1024)}k decode":
    discard decodeJpeg(data)
