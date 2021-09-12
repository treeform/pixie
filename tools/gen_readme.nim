import os, osproc, strutils

proc cutBetween(str, a, b: string): string =
  let
    cutA = str.find(a)
    cutB = str.find(b)
  if cutA == -1 or cutB == -1:
    return ""
  return str[cutA + a.len..<cutB]

var md: seq[string]

var exampleFiles = [
  "examples/text.nim",
  "examples/text_spans.nim",
  "examples/square.nim",
  "examples/line.nim",
  "examples/rounded_rectangle.nim",
  "examples/heart.nim",
  "examples/masking.nim",
  "examples/gradient.nim",
  "examples/image_tiled.nim",
  "examples/shadow.nim",
  "examples/blur.nim",
  "examples/tiger.nim"
]

for path in exampleFiles:
  discard execCmd("nim c -r " & path)
  let code = readFile(path)
  let innerCode = code.cutBetween("image.fill(rgba(255, 255, 255, 255))", "image.writeFile")
  if innerCode != "":
    let path = path.replace("\\", "/")
    md.add "### " & path.splitFile().name.replace("_", " ").capitalizeAscii()
    md.add "nim c -r [" & path & "](" & path & ")"
    md.add "```nim"
    md.add innerCode.strip()
    md.add "```"
    md.add "![example output](" & path.replace(".nim", ".png").replace("\\",
        "/") & ")"
    md.add ""

var readme = readFile("README.md")

let at = readme.find("## Examples")
if at != -1:
  readme = readme[0 .. at]
readme.add("# Examples\n\n")
readme.add("`git clone https://github.com/treeform/pixie` to run examples.\n\n")
readme.add(md.join("\n"))

writeFile("README.md", readme)
