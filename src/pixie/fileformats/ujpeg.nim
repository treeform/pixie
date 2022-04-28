import pixie

{.compile: "ujpeg/ujpeg.c".}

type
  ujImage = pointer

proc ujCreate() : ujImage {.cdecl, importc: "ujCreate".}
#proc ujDecode(img: ujImage, data: ptr cuchar, size: int) : ujImage {.cdecl, importc: "ujDecode".}
proc ujDecodeFile(img: ujImage, filename: cstring) : ujImage {.cdecl, importc: "ujDecodeFile".}
proc ujGetWidth(img: ujImage) : int {.cdecl, importc: "ujGetWidth".}
proc ujGetHeight(img: ujImage) : int {.cdecl, importc: "ujGetHeight".}
proc ujGetImageSize(img: ujImage) : int {.cdecl, importc: "ujGetImageSize".}
proc ujGetImage(img: ujImage, dest: cstring) : cstring {.cdecl, importc: "ujGetImage".}
proc ujDestroy(img: ujImage) {.cdecl, importc: "ujDestroy".}


proc loadImageJPG(fileName: string): Image =
  var jpg = ujCreate()
  if jpg == nil:
    echo "nil ujCreate"
    return nil

  if ujDecodeFile(jpg, cstring(fileName)) != nil:
    let
      size = ujGetImageSize(jpg)
      width = ujGetWidth(jpg)
      height = ujGetHeight(jpg)
    echo width, "x", height
    result = newImage(width, height)
    let data = newString(size * 3)
    discard ujGetImage(jpg, cstring(data))
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

# echo "here"
# var image = ujCreate()
# var image2 = ujDecodeFile(image, "tests/jpeg420exif.jpg")
# ujDestroy(image)

# echo "done"

var img = loadImageJPG("tests/fileformats/jpg/jpeg420exif.jpg")
img.writeFile("tests/fileformats/jpg/jpeg420exif.png")
