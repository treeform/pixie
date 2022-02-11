import pixie/common

when defined(windows) and defined(vcc):
  {.pragma: stbcall, stdcall.}
else:
  {.pragma: stbcall, cdecl.}

{.compile: "stb_image.c".}

proc stbi_image_free(retval_from_stbi_load: pointer)
  {.importc: "stbi_image_free", stbcall.}

proc stbi_load_from_memory(
  buffer: pointer,
  len: cint,
  x, y, channels_in_file: var cint,
  desired_channels: cint
): pointer
  {.importc: "stbi_load_from_memory", stbcall.}

proc loadFromMemory*(buffer: string, width, height: var int): string =
  var outWidth, outHeight, outComponents: cint
  let data = stbi_load_from_memory(
    buffer[0].unsafeAddr,
    buffer.len.cint,
    outWidth,
    outHeight,
    outComponents,
    4
  )
  if data == nil:
    raise newException(PixieError, "Decoding JPG failed")

  width = outWidth.int
  height = outHeight.int

  result.setLen(width * height * 4)
  copyMem(result[0].addr, data, result.len)

  stbi_image_free(data)
