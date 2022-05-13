import pixie/common, pixie/images

const
  jpgStartOfImage* = [0xFF.uint8, 0xD8]

when defined(pixieUseStb):
  import pixie/fileformats/stb_image/stb_image
else:
  import pixie/fileformats/jpeg

proc decodeJpg*(data: string): Image {.inline, raises: [PixieError].} =
  ## Decodes the JPEG into an Image.
  when not defined(pixieUseStb):
    decodeJpeg(data)
  else:
    var
      width: int
      height: int
    let pixels = loadFromMemory(data, width, height)

    result = newImage(width, height)
    copyMem(result.data[0].addr, pixels[0].unsafeAddr, pixels.len)
