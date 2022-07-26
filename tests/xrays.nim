import os, pixie, strformat, strutils

proc xray*(image: Image, masterPath: string) =
  let
    generatedPath = "tmp/generated/" & masterPath
    xrayPath = "tmp/xray/" & masterPath
  createDir(generatedPath.splitPath.head)
  createDir(xrayPath.splitPath.head)
  image.writeFile(generatedPath)
  let
    master = readImage(masterPath)
    (score, xRay) = diff(image, master)
  xRay.writeFile(xrayPath)
  echo &"xray {masterPath} -> {score:0.6f}"
