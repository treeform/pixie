import pixie, strutils

import pixie/fileformats/jpg

echo "start"

var files = @[
  "tests/fileformats/jpg/master/red.jpg",
  "tests/fileformats/jpg/master/green.jpg",
  "tests/fileformats/jpg/master/blue.jpg",
  "tests/fileformats/jpg/master/white.jpg",
  "tests/fileformats/jpg/master/black.jpg",

  "tests/fileformats/jpg/master/8x8.jpg",
  "tests/fileformats/jpg/master/8x8_progressive.jpg",

  "tests/fileformats/jpg/master/16x16.jpg",
  "tests/fileformats/jpg/master/16x16_progressive.jpg",

  "tests/fileformats/jpg/master/quality_01.jpg",
  "tests/fileformats/jpg/master/quality_10.jpg",
  "tests/fileformats/jpg/master/quality_25.jpg",
  "tests/fileformats/jpg/master/quality_50.jpg",
  "tests/fileformats/jpg/master/quality_100.jpg",

  "tests/fileformats/jpg/master/cat_4_2_0_int.jpg",
  "tests/fileformats/jpg/master/cat_4_2_2_int.jpg",
  "tests/fileformats/jpg/master/cat_4_4_4_int.jpg",
  "tests/fileformats/jpg/master/cat_4_4_4_fast_int.jpg",
  "tests/fileformats/jpg/master/cat_4_2_0_fast_int.jpg",
  "tests/fileformats/jpg/master/cat_4_1_1.jpg",
  "tests/fileformats/jpg/master/cat_4_4_4_progressive.jpg",

  "tests/fileformats/jpg/master/mandrill.jpg",

  "tests/fileformats/jpg/master/exif_overrun.jpg",
  "tests/fileformats/jpg/master/grayscale_test.jpg",
  "tests/fileformats/jpg/master/progressive.jpg",

  "tests/fileformats/jpg/master/testimg.jpg",
  "tests/fileformats/jpg/master/testimgp.jpg",
  "tests/fileformats/jpg/master/testorig.jpg",
  "tests/fileformats/jpg/master/testprog.jpg",

  # TODO: Get better exif tests
  # "tests/fileformats/jpg/master/jpeg420exif.jpg",
  # "tests/fileformats/jpg/master/exif-Tulips.jpg",
  # "tests/fileformats/jpg/master/exif-rocks.jpg",
  # "tests/fileformats/jpg/master/autorotate-landscape-2.jpg",
]

for file in files:
  echo file
  var img = decodeJpg(readFile(file))
  img.writeFile(file.replace("master", "generated").replace(".jpg", ".jpeg.png"))

echo "done"
