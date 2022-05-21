import pixie, pixie/fileformats/qoi

const tests = ["testcard", "testcard_rgba"]

for name in tests:
  let
    input = readImage("tests/fileformats/qoi/" & name & ".qoi")
    control = readImage("tests/fileformats/qoi/" & name & ".png")
  doAssert input.data == control.data, "input mismatch of " & name
  discard encodeQoi(control)

for name in tests:
  let
    input = decodeQoi(readFile("tests/fileformats/qoi/" & name & ".qoi"))
    output = decodeQoi(encodeQoi(input))
  doAssert output.data.len == input.data.len
  doAssert output.data == input.data
