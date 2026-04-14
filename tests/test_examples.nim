import os, osproc, strformat, pixie

const examples = [
  "text",
  "text_spans",
  "square",
  "line",
  "rounded_rectangle",
  "heart",
  "masking",
  "gradient",
  "image_tiled",
  "shadow",
  "blur",
  "tiger"
]

const updateThreshold = 1.0

let
  generatedDir = "tmp/generated/examples"
  xrayDir = "tmp/xray/examples"

createDir(generatedDir)
createDir(xrayDir)

for example in examples:
  let
    nimFile = &"examples/{example}.nim"
    masterPath = &"examples/{example}.png"
    generatedPath = generatedDir / &"{example}.png"
    xrayPath = xrayDir / &"{example}.png"
    run = execCmdEx(
      &"nim r -d:release {nimFile} -- {generatedPath}",
      workingDir = getCurrentDir()
    )

  if run.exitCode != 0:
    echo run.output
    raise newException(PixieError, &"Example {example} failed with exit code {run.exitCode}")

  let
    generated = readImage(generatedPath)
    master = readImage(masterPath)
    (score, xray) = diff(generated, master)

  xray.writeFile(xrayPath)
  echo &"xray {masterPath} -> {score:0.6f}"

  if score > updateThreshold:
    copyFile(generatedPath, masterPath)
