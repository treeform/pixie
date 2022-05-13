import benchy, jpegsuite, pixie/fileformats/jpg, strformat

for file in jpegSuiteFiles:
  let data = readFile(file)
  timeIt &"jpeg {(data.len div 1024)}k decode":
    discard decodeJpg(data)
