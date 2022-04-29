import pixie

include ujpeg/ujpeg

proc loadImageJPG(fileName: string): Image =
  echo fileName
  var jpg = ujCreate()
  if jpg == nil:
    echo "nil ujCreate"
    return nil
  let rawData = readFile(fileName)
  if ujDecode(jpg, cast[pointer](rawData[0].unsafeAddr), rawData.len.int32) == 1:
    let
      size = ujGetImageSize(jpg)
      width = ujGetWidth(jpg)
      height = ujGetHeight(jpg)
    echo "size ", size
    echo width, "x", height
    result = newImage(width, height)
    let data = newString(size * 3)
    ujGetImage(jpg, cast[ptr uint8](data[0].unsafeAddr))
    for i in 0 ..< size div 3:
      let
        r = data[i*3+0].uint8
        g = data[i*3+1].uint8
        b = data[i*3+2].uint8
      result.data[i] = rgbx(r, g, b, 255)

    ujDestroy(jpg)
  else:
    echo "nil ujDecodeFile"
    result = nil

echo "start"

var files = @[
  "tests/fileformats/jpg/jpeg420exif.jpg",
  "tests/fileformats/jpg/mandrill.jpg",

  "tests/fileformats/jpg/red.jpg",
  "tests/fileformats/jpg/green.jpg",
  "tests/fileformats/jpg/blue.jpg",
  "tests/fileformats/jpg/white.jpg",
  "tests/fileformats/jpg/black.jpg",

  "tests/fileformats/jpg/quality_01.jpg",
  "tests/fileformats/jpg/quality_10.jpg",
  "tests/fileformats/jpg/quality_25.jpg",
  "tests/fileformats/jpg/quality_50.jpg",
  "tests/fileformats/jpg/quality_100.jpg",
]

for file in files:
  var img = loadImageJPG(file)
  img.writeFile(file & ".crazy.png")

echo "done"
