import pixie/common

when defined(windows) and defined(vcc):
  {.pragma: stbcall, stdcall.}
else:
  {.pragma: stbcall, cdecl.}

{.compile: "stb_image.c".}

proc stbi_image_free(retval_from_stbi_load: pointer)
  {.importc: "stbi_image_free", stbcall.}

proc stbi_load_from_memory(
  buffer: ptr cuchar,
  len: cint,
  x, y, channels_in_file: var cint,
  desired_channels: cint
): ptr cuchar
  {.importc: "stbi_load_from_memory", stbcall.}


proc loadFromMemory*(buffer: seq[uint8], width, height: var int): seq[uint8] =
  var outWidth, outHeight, outComponents: cint
  let data = stbi_load_from_memory(
    cast[ptr cuchar](buffer[0].unsafeAddr),
    buffer.len.cint,
    outWidth,
    outHeight,
    outComponents,
    4
  )
  if data == nil:
    raise newException(PixieError, "Loading JPG failed")

  width = outWidth.int
  height = outHeight.int

  result.setLen(width * height * 4)
  copyMem(result[0].addr, data, result.len)

  stbi_image_free(data)
