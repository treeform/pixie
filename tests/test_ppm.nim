import pixie/fileformats/ppm

block:
  for format in @["p3", "p6"]:
    let image = decodePpm(readFile(
      "tests/fileformats/ppm/feep." & $format & ".master.ppm"
    ))
    writeFile("tests/fileformats/ppm/feep." & $format & ".ppm", encodePpm(image))
