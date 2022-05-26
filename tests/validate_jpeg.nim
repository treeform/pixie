import jpegsuite, os, pixie, strformat, strutils

createDir("tests/fileformats/jpeg/generated")
createDir("tests/fileformats/jpeg/diffs")

for file in jpegSuiteFiles:
  let img = readImage(file)

  let genFile = file.replace("masters", "generated").replace(".jpg", ".png")
  img.writeFile(genFile)

  if execShellCmd(&"magick {file} -auto-orient {genFile}") != 0:
    echo "fail"

  var img2 = readImage(genFile)
  let (score, diff) = img2.diff(img)

  let diffFile = file.replace("master", "diff").replace(".jpg", ".png")
  diff.writeFile(diffFile)

  if score > 1:
    echo "!!!!!!!!!!!!!! FAIL !!!!!!!!!!!!!"
  echo &"{score:2.3f}% ... {file}"
