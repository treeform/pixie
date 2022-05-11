import pixie, strutils, os, strformat

import pixie/fileformats/jpg

var files = @[
  "tests/fileformats/jpeg/master/red.jpg",
  "tests/fileformats/jpeg/master/green.jpg",
  "tests/fileformats/jpeg/master/blue.jpg",
  "tests/fileformats/jpeg/master/white.jpg",
  "tests/fileformats/jpeg/master/black.jpg",

  "tests/fileformats/jpeg/master/8x8.jpg",
  "tests/fileformats/jpeg/master/8x8_progressive.jpg",

  "tests/fileformats/jpeg/master/16x16.jpg",
  "tests/fileformats/jpeg/master/16x16_progressive.jpg",

  "tests/fileformats/jpeg/master/quality_01.jpg",
  "tests/fileformats/jpeg/master/quality_10.jpg",
  "tests/fileformats/jpeg/master/quality_25.jpg",
  "tests/fileformats/jpeg/master/quality_50.jpg",
  "tests/fileformats/jpeg/master/quality_100.jpg",

  "tests/fileformats/jpeg/master/cat_4_4_4.jpg",
  "tests/fileformats/jpeg/master/cat_4_4_4.jpg",
  "tests/fileformats/jpeg/master/cat_4_2_2.jpg",
  "tests/fileformats/jpeg/master/cat_4_2_0.jpg",
  "tests/fileformats/jpeg/master/cat_4_1_1.jpg",
  "tests/fileformats/jpeg/master/cat_4_2_0_progressive.jpg",
  "tests/fileformats/jpeg/master/cat_4_4_4_progressive.jpg",
  "tests/fileformats/jpeg/master/cat_restart_markers_5.jpg",
  "tests/fileformats/jpeg/master/cat_restart_markers_5_progressive.jpg",

  "tests/fileformats/jpeg/master/mandrill.jpg",
  "tests/fileformats/jpeg/master/exif_overrun.jpg",
  "tests/fileformats/jpeg/master/grayscale_test.jpg",
  "tests/fileformats/jpeg/master/progressive.jpg",

  "tests/fileformats/jpeg/master/testimg.jpg",
  "tests/fileformats/jpeg/master/testimgp.jpg",
  "tests/fileformats/jpeg/master/testorig.jpg",
  "tests/fileformats/jpeg/master/testprog.jpg",
]

for file in files:
  var img = decodeJpg(readFile(file))

  let genFile = file.replace("master", "generated").replace(".jpg", ".png")
  let diffFile = file.replace("master", "diff").replace(".jpg", ".png")

  if execShellCmd(&"convert {file} {genFile}") != 0:
    echo "fail"

  var img2 = readImage(genFile)
  let (score, diff) = img2.diff(img)
  diff.writeFile(diffFile)

  if score > 1:
    echo "!!!!!!!!!!!!!! FAIL !!!!!!!!!!!!!"
  echo &"{score:2.3f}% ... {file}"
