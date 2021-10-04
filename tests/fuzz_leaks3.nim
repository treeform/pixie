import pixie, pixie/fileformats/svg, random

when not defined(pixieLeakCheck):
  quit("Requires -d:pixieLeakCheck")

randomize()

let data = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")

for i in 0 ..< 100_000:
  var image = decodeSvg(data, rand(300 .. 1800), rand(30 .. 1800))

  # image.writeFile("tests/fuzz_leaks3.png")
  # break
