import pixie, strformat, os, strutils

proc makeDirs*(dirs: string) =
  var path = ""
  for dir in dirs.split("/"):
    path.add dir
    if not dirExists(path):
      echo "mkdir ", path
      createDir(path)
    path.add "/"

proc xray*(image: Image, masterPath: string) =
  let
    imagePath = "tmp/generated/" & masterPath
    xRayPath = "tmp/xray/" & masterPath
  makeDirs(imagePath.splitPath.head)
  makeDirs(xRayPath.splitPath.head)
  image.writeFile(imagePath)
  let
    master = readImage(masterPath)
    (score, xRay) = diff(image, master)
  xRay.writeFile(xRayPath)
  echo &"diff {masterPath} -> {score:0.6f}"

proc xray*(mask: Mask, masterPath: string) =
  mask.newImage.xray(masterPath)
