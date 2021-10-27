import pixie, stb_truetype, unicode

let fontFiles = [
  # "tests/fonts/Roboto-Regular_1.ttf"
    # "tests/fonts/Aclonica-Regular_1.ttf"
    # "tests/fonts/Ubuntu-Regular_1.ttf"
    # "tests/fonts/IBMPlexSans-Regular_2.ttf"
    # "tests/fonts/NotoSans-Regular_4.ttf"
  "tests/fonts/Pacifico-Regular_4.ttf"
]

for fontFile in fontFiles:
  let stbtt = initFont(readFile(fontFile))
  var font = readFont(fontFile)

  var ascent, descent, lineGap: cint
  stbtt.getFontVMetrics(ascent, descent, lineGap)

  doAssert font.typeface.ascent == ascent.float32
  doAssert font.typeface.descent == descent.float32
  doAssert font.typeface.lineGap == lineGap.float32

  for i in 32 .. 126:
    var advanceWidth, leftSideBearing: cint
    stbtt.getCodepointHMetrics(Rune(i), advanceWidth, leftSideBearing)

    doAssert font.typeface.getAdvance(Rune(i)) == advanceWidth.float32

  for i in 32 .. 126:
    for j in 32 .. 126:
      # echo i, ": ", $Rune(i), "  ", j, ": ", $Rune(j)
      let
        a = stbtt.getCodepointKernAdvance(Rune(i), Rune(j)).float32
        b = font.typeface.getKerningAdjustment(Rune(i), Rune(j))
      if a != b:
        # echo fontFile
        echo i, ": ", $Rune(i), "  ", j, ": ", $Rune(j)
        echo "DISAGREE: ", a, " != ", b, " <<<<<<<<<<<<<<<<<<<<<<<<<<<"
        # quit()

      # echo stbtt.getCodepointKernAdvance(Rune('r'), Rune('s')).float32
      # echo font.typeface.getKerningAdjustment(Rune('r'), Rune('s'))
