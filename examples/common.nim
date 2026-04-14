import os

proc outputPath*(fileName: string): string =
  if paramCount() >= 1:
    result =
      if paramStr(1) == "--" and paramCount() >= 2:
        paramStr(2)
      else:
        paramStr(1)
    createDir(parentDir(result))
  else:
    result = "examples" / fileName
