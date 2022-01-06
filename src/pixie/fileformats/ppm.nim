import chroma, flatty/binny, pixie/common, pixie/images

# See: http://netpbm.sourceforge.net/doc/ppm.html

const ppmSignatures* = @["P3", "P6"]

proc decodePpm*(data: string): Image {.raises: [PixieError].} =
  ## Decodes Portable Pixel Map data into an Image.
  result = newImage(0, 0)

proc decodePpm*(data: seq[uint8]): Image {.inline, raises: [PixieError].} =
  ## Decodes Portable Pixel Map data into an Image.
  decodePpm(cast[string](data))

proc encodePpm*(image: Image): string {.raises: [].} =
  ## Encodes an image into the PPM file format (version P6).

  # PPM header
  result.add("P6") # The header field used to identify the PPM
  result.add("\n") # Newline
  result.add($image.width)
  result.add(" ") # Space
  result.add($image.height)
  result.add("\n") # Newline
  result.add("255") # Max color value
  result.add("\n") # Newline

  # PPM image data
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let rgb = image[x, y].rgba()
      # alpha channel is ignored
      result.addUint8(rgb.r)
      result.addUint8(rgb.g)
      result.addUint8(rgb.b)
