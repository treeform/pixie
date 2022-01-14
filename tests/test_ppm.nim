import pixie/fileformats/ppm

block:
  for format in @["p3", "p6"]:
    let image = decodePpm(readFile(
      "tests/fileformats/ppm/feep." & $format & ".master.ppm"
    ))
    writeFile("tests/fileformats/ppm/feep." & $format & ".ppm", encodePpm(image))

  let image = decodePpm(readFile(
    "tests/fileformats/ppm/feep.p3.hidepth.master.ppm"
  ))
  writeFile("tests/fileformats/ppm/feep.p3.hidepth.ppm", encodePpm(image))

  # produced output should be identical to P6 master
  let p6Master = readFile("tests/fileformats/ppm/feep.p6.master.ppm")
  for image in @["p3", "p6", "p3.hidepth"]:
    doAssert readFile("tests/fileformats/ppm/feep." & $image & ".ppm") == p6Master
