import algorithm, os

proc findAllFonts*(rootPath: string): seq[string] =
  for fontPath in walkDirRec(rootPath):
    if splitFile(fontPath).ext in [".ttf", ".otf"]:
      result.add(fontPath)
  result.sort()
