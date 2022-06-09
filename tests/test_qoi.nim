import pixie, pixie/fileformats/qoi

const tests = ["testcard", "testcard_rgba"]

for name in tests:
  let
    path = "tests/fileformats/qoi/" & name & ".qoi"
    input = readImage(path)
    control = readImage("tests/fileformats/qoi/" & name & ".png")
    dimensions = decodeQoiDimensions(readFile(path))
  doAssert input.data == control.data, "input mismatch of " & name
  doAssert input.width == dimensions.width
  doAssert input.height == dimensions.height
  discard encodeQoi(control)

for name in tests:
  let
    path = "tests/fileformats/qoi/" & name & ".qoi"
    input = decodeQoi(readFile(path))
    output = decodeQoi(encodeQoi(input))
  doAssert output.data.len == input.data.len
  doAssert output.data == input.data
