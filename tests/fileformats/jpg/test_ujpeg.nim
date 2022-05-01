import pixie, strutils

{.compile: "ujpeg/ujpeg.c".}

type
  ujImage = pointer

proc ujCreate() : ujImage {.cdecl, importc: "ujCreate".}
proc ujDecode(img: ujImage, data: ptr cuchar, size: cint) : ujImage {.cdecl, importc: "ujDecode".}
proc ujGetWidth(img: ujImage) : int {.cdecl, importc: "ujGetWidth".}
proc ujGetHeight(img: ujImage) : int {.cdecl, importc: "ujGetHeight".}
proc ujGetImageSize(img: ujImage) : int {.cdecl, importc: "ujGetImageSize".}
proc ujGetImage(img: ujImage, dest: ptr uint8) {.cdecl, importc: "ujGetImage".}
proc ujDestroy(img: ujImage) {.cdecl, importc: "ujDestroy".}

proc loadImageJPG(fileName: string): Image =
  echo fileName
  var jpg = ujCreate()
  if jpg == nil:
    echo "nil ujCreate"
    return nil
  let rawData = readFile(fileName)
  if ujDecode(jpg, cast[ptr cuchar](rawData[0].unsafeAddr), rawData.len.cint) != nil:
    let
      size = ujGetImageSize(jpg)
      width = ujGetWidth(jpg)
      height = ujGetHeight(jpg)
    echo "size ", size
    echo width, "x", height
    result = newImage(width, height)
    ujGetImage(jpg, cast[ptr uint8](result.data[0].addr))
    ujDestroy(jpg)
  else:
    echo "nil ujDecodeFile"
    result = nil

echo "start"

var files = @[
  # "tests/fileformats/jpg/master/jpeg420exif.jpg",
  # "tests/fileformats/jpg/master/mandrill.jpg",

  # "tests/fileformats/jpg/master/red.jpg",
  # "tests/fileformats/jpg/master/green.jpg",
  # "tests/fileformats/jpg/master/blue.jpg",
  # "tests/fileformats/jpg/master/white.jpg",
  "tests/fileformats/jpg/master/black.jpg",

  # "tests/fileformats/jpg/master/quality_01.jpg",
  # "tests/fileformats/jpg/master/quality_10.jpg",
  # "tests/fileformats/jpg/master/quality_25.jpg",
  # "tests/fileformats/jpg/master/quality_50.jpg",
  # "tests/fileformats/jpg/master/quality_100.jpg",

  # "tests/fileformats/jpg/master/exif_overrun.jpg",
  # "tests/fileformats/jpg/master/grayscale_test.jpg",
  # # "tests/fileformats/jpg/master/progressive.jpg",

  # "tests/fileformats/jpg/master/exif-Tulips.jpg",
  # "tests/fileformats/jpg/master/exif-rocks.jpg",
  # "tests/fileformats/jpg/master/autorotate-landscape-2.jpg",

  # "tests/fileformats/jpg/master/testimg.jpg",
  # # "tests/fileformats/jpg/master/testimgp.jpg",
  # "tests/fileformats/jpg/master/testorig.jpg",
  # # "tests/fileformats/jpg/master/testprog.jpg",

  # "tests/fileformats/jpg/master/cat_4_2_0_int.jpg",
  # "tests/fileformats/jpg/master/cat_4_2_2_int.jpg",
  # "tests/fileformats/jpg/master/cat_4_4_4_int.jpg",
  # "tests/fileformats/jpg/master/cat_4_4_4_fast_int.jpg",
  # "tests/fileformats/jpg/master/cat_4_2_0_fast_int.jpg",

  # "tests/fileformats/jpg/master/cat_4_1_1.jpg",

]

for file in files:
  var img = loadImageJPG(file)
  img.writeFile(file.replace("master", "generated").replace(".jpg", ".png"))

echo "done"
