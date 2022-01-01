import pixie, pixie/fileformats/qoi, pixie/fileformats/png

const tests = ["testcard", "testcard_rgba"]

for name in tests:
  var input = decodeQoi(readFile("tests/fileformats/qoi/" & name & ".qoi"))
  var control = decodePng(readFile("tests/fileformats/qoi/" & name & ".png"))
  doAssert(input.data == control.data, "input mismatch of " & name)

for name in tests:
  var
    input: Qoi = decompressQoi(readFile("tests/fileformats/qoi/" & name & ".qoi"))
    output: Qoi = decompressQoi(compressQoi(input))
  doAssert(output.data.len == input.data.len)
  doAssert(output.data == input.data)
