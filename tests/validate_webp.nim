import os, osproc, pixie, pixie/fileformats/webp, strformat, strutils, webpsuite

const
  GeneratedDir = "tests/fileformats/webp/generated"
  DiffDir = "tests/fileformats/webp/diffs"

createDir(GeneratedDir)
createDir(DiffDir)

var
  checked, skipped, failed: int

for file in WebpSuiteFiles:
  let info = decodeWebpInfo(readFile(file))
  if info.compression == UnknownWebpCompression:
    inc skipped
    continue

  inc checked
  let
    name = file.splitFile.name
    genFile = GeneratedDir / (name & ".png")
    magickFile = GeneratedDir / (name & ".magick.png")
    diffFile = DiffDir / (name & ".diff.png")

  try:
    let img = readImage(file)
    img.writeFile(genFile)

    if execShellCmd(
      "magick " & quoteShell(file) & " PNG32:" & quoteShell(magickFile)
    ) != 0:
      echo "ImageMagick failed: " & file
      inc failed
      continue

    let magickImg = readImage(magickFile)
    let (score, diff) = magickImg.diff(img)
    diff.writeFile(diffFile)

    if score > 0:
      echo &"FAIL {score:2.6f}% ... {file}"
      inc failed
    else:
      echo &"{score:2.6f}% ... {file}"
  except PixieError as e:
    echo "PixieError: " & file & ": " & e.msg
    inc failed

echo &"WebP validate: {checked - failed}/{checked} still images passed, " &
  &"{skipped} animations skipped"

if failed > 0:
  quit(1)
