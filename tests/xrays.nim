import os, pixie, strformat, strutils

var htmlEntries: seq[string]

proc xray*(image: Image, masterPath: string) =
  let
    generatedPath = "tmp/generated/" & masterPath
    xrayPath = "tmp/xray/" & masterPath
  createDir(generatedPath.splitPath.head)
  createDir(xrayPath.splitPath.head)
  image.writeFile(generatedPath)
  if not fileExists(masterPath):
    echo &"xray {masterPath} -> new master"
    createDir(masterPath.splitPath.head)
    image.writeFile(masterPath)
    return
  let
    master = readImage(masterPath)
    (score, xRay) = diff(image, master)
  xRay.writeFile(xrayPath)
  echo &"xray {masterPath} -> {score:0.6f}"

  let bg = if score > 1: "#fee" else: "#fff"
  htmlEntries.add(&"""<div style="background:{bg};border:1px solid #ccc;padding:8px;break-inside:avoid">
<b>{masterPath}</b> score: {score:0.6f}
<div style="display:flex;gap:8px;flex-wrap:wrap">
<div><div>Master</div><img src="../{masterPath}"></div>
<div><div>Generated</div><img src="../{generatedPath}"></div>
<div><div>Xray</div><img src="../{xrayPath}"></div>
</div></div>""")

proc writeReport*() =
  let html = """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Xray Report</title>
<style>body{font-family:monospace;margin:16px}img{display:block;background:repeating-conic-gradient(#eee 0% 25%,#fff 0% 50%) 0 0/16px 16px}</style>
</head><body>
<h1>Xray Report</h1>
""" & htmlEntries.join("\n") & "\n</body></html>"
  createDir("tmp")
  writeFile("tmp/xray_report.html", html)
  echo "Wrote tmp/xray_report.html"
