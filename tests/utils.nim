import pixie, strformat, os, strutils

proc makeDirs*(dirs: string) =
  var path = ""
  for dir in dirs.split("/"):
    path.add dir
    if not dirExists(path):
      echo "mkdir ", path
      createDir(path)
    path.add "/"

proc diffVs*(image: Image, masterPath: string) =
  let
    master = readImage(masterPath)
    (score, xRay) = diff(image, master)
    imagePath = "tmp/generated/" & masterPath
    xRayPath = "tmp/xray/" & masterPath
  makeDirs(imagePath.splitPath.head)
  makeDirs(xRayPath.splitPath.head)
  image.writeFile(imagePath)
  xRay.writeFile(xRayPath)
  echo &"diff {masterPath} -> {score:0.6f}"

proc diffVs*(mask: Mask, masterPath: string) =
  let
    master = readImage(masterPath)
    image = mask.newImage
    (score, xRay) = diff(image, master)
    imagePath = "tmp/generated/" & masterPath
    xRayPath = "tmp/xray/" & masterPath
  makeDirs(imagePath.splitPath.head)
  makeDirs(xRayPath.splitPath.head)
  image.writeFile(imagePath)
  xRay.writeFile(xRayPath)
  echo &"diff {masterPath} -> {score:0.6f}"
