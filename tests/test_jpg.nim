import pixie/images, pixie/fileformats/jpg, pixie/fileformats/stb_image/stb_image

proc stbDecode*(data: string): Image =
  ## Decodes the JPEG into an Image.
  var
    width: int
    height: int
  let pixels = loadFromMemory(cast[seq[uint8]](data), width, height)

  result = newImage(width, height)
  copyMem(result.data[0].addr, pixels[0].unsafeAddr, pixels.len)

let
  original = readFile("tests/images/jpg/jpeg420exif.jpg")
  stbDecoded = stbDecode(original)
  pixieDecoded = decodeJpg(original)

doAssert pixieDecoded.width == stbDecoded.width
doAssert pixieDecoded.height == stbDecoded.height
doAssert pixieDecoded.data.len == stbDecoded.data.len
# doAssert pixieDecoded.data == stbDecoded.data

for i in 0 ..< pixieDecoded.data.len:
  if pixieDecoded.data[i] != stbDecoded.data[i]:
    echo pixieDecoded.data[i], " != ", stbDecoded.data[i], " @ ", i
    break
