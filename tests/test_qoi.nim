import pixie, pixie/fileformats/png, pixie/fileformats/qoi

const tests = ["testcard", "testcard_rgba"]

for name in tests:
  let
    input = decodeQoi(readFile("tests/fileformats/qoi/" & name & ".qoi"))
    control = decodePng(readFile("tests/fileformats/qoi/" & name & ".png"))
  doAssert input.data == control.data, "input mismatch of " & name

  decodeQoi(control.encodeQoi()).writeFile("tmp.png")

for name in tests:
  let
    input = decodeQoiRaw(readFile("tests/fileformats/qoi/" & name & ".qoi"))
    output = decodeQoiRaw(encodeQoi(input))
  doAssert output.data.len == input.data.len
  doAssert output.data == input.data
