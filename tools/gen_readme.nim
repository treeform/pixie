import os, strutils, osproc

proc cutBetween(str, a, b: string): string =
  let
    cutA = str.find(a)
    cutB = str.find(b)
  if cutA == -1 or cutB == -1:
    return ""
  return str[cutA + a.len..<cutB]

var md: seq[string]

for k, path in walkDir("examples"):
  if path.endsWith(".nim"):
    discard execCmd("nim c -r -d:danger " & path)
    let code = readFile(path)
    let innerCode = code.cutBetween("image.fill(rgba(255, 255, 255, 255))", "image.writeFile")
    if innerCode != "":
      let path = path.replace("\\", "/")
      md.add "### " & path.splitFile().name.replace("_", " ").capitalizeAscii()
      md.add "[" & path & "](" & path & ")"
      md.add "```nim"
      md.add innerCode.strip()
      md.add "```"
      md.add "![example output](" & path.replace(".nim", ".png").replace("\\", "/") & ")"
      md.add ""

var readme = readFile("README.md")

let at = readme.find("## Examples")
if at != -1:
  readme = readme[0 .. at]
readme.add("# Examples\n\n")
readme.add(md.join("\n"))

writeFile("README.md", readme)
