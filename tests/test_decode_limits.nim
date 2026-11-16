import
  std/[os, osproc, strutils, tempfiles],
  crunchy, pixie, zippy, pixie/fileformats/[gif, png]

proc addBigEndian(data: var string, value: uint32) =
  ## Appends an unsigned PNG length or checksum in network byte order.
  for shift in countdown(24, 0, 8):
    data.add(char((value shr shift) and 255))

proc addChunk(data: var string, kind, content: string) =
  ## Appends one CRC-checked PNG chunk for a controlled decoder fixture.
  data.addBigEndian(content.len.uint32)
  data.add(kind)
  data.add(content)
  data.addBigEndian(crc32(kind & content))

proc pngFixture(inflated: string, split = false, interlaced = false): string =
  ## Encodes a one-pixel header with independently chosen compressed data.
  result = "\x89PNG\r\n\x1a\n"
  var header = "\0\0\0\1\0\0\0\1\x08\x06\0\0\0"
  if interlaced:
    header[^1] = '\1'
  result.addChunk("IHDR", header)
  let compressed = compress(inflated, dataFormat = dfZlib)
  if split:
    let middle = compressed.len div 2
    result.addChunk("IDAT", compressed[0 ..< middle])
    result.addChunk("IDAT", compressed[middle .. ^1])
  else:
    result.addChunk("IDAT", compressed)
  result.addChunk("IEND", "")

proc gifFixture(pixels: int): string =
  ## Emits repeated clear/literal codes for a declared one-pixel GIF frame.
  result = "GIF89a\1\0\1\0\x80\0\0\0\0\0\xFF\xFF\xFF" &
    "\x2C\0\0\0\0\1\0\1\0\0\x02"
  var
    compressed = ""
    pending = 0
    count = 0
  proc addCode(code: int) =
    ## Packs one three-bit LZW code, with clear codes keeping the width fixed.
    pending = pending or (code shl count)
    count += 3
    if count >= 8:
      compressed.add(char(pending and 255))
      pending = pending shr 8
      count -= 8
  for i in 0 ..< pixels:
    addCode(4)
    addCode(0)
  addCode(5)
  if count > 0:
    compressed.add(char(pending and 255))
  var offset = 0
  while offset < compressed.len:
    let size = min(255, compressed.len - offset)
    result.add(char(size))
    result.add(compressed[offset ..< offset + size])
    offset += size
  result.add("\0\x3B")

proc checkBoundedFailure(path: string) =
  ## Requires malformed compressed data to fail before allocating its expansion.
  let data = readFile(path)
  when declared(getMaxMem):
    let before = getMaxMem()
  var failed = false
  try:
    discard decodeImage(data)
  except PixieError:
    failed = true
  doAssert failed
  when declared(getMaxMem):
    doAssert getMaxMem() - before < 4 * 1024 * 1024,
      "Malformed compressed data allocated beyond its declared image size."

if paramCount() == 2 and paramStr(1) == "--decode-limit":
  checkBoundedFailure(paramStr(2))
  quit(0)

block:
  echo "Testing bounded PNG and GIF expansion"
  let directory = createTempDir("pixie-image-limits-", "")
  defer:
    removeDir(directory)
  for split in [false, true]:
    for interlaced in [false, true]:
      let
        valid = pngFixture("\0\xFF\0\0\xFF", split, interlaced)
        image = decodeImage(valid)
        path = directory / ($split & "-" & $interlaced & ".png")
      doAssert image.width == 1 and image.height == 1
      doAssert image[0, 0] == rgbx(255, 0, 0, 255)
      writeFile(
        path,
        pngFixture(repeat('x', 8 * 1024 * 1024), split, interlaced)
      )
      let child = startProcess(
        getAppFilename(), args = ["--decode-limit", path],
        options = {poUsePath, poParentStreams}
      )
      doAssert child.waitForExit() == 0
      child.close()
  let
    gif = gifFixture(1)
    path = directory / "oversized.gif"
  doAssert decodeGif(gif).frames[0].width == 1
  writeFile(path, gifFixture(1024 * 1024))
  let child = startProcess(
    getAppFilename(), args = ["--decode-limit", path],
    options = {poUsePath, poParentStreams}
  )
  doAssert child.waitForExit() == 0
  child.close()

echo "All compressed image limit tests passed."
