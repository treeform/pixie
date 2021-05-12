import common, pixie

# Clone https://github.com/treeform/fidgetfonts

let fontPaths = findAllFonts("../fidgetfonts")

for fontPath in fontPaths:
  echo fontPath
  try:
    var font = readFont(fontPath)
  except PixieError:
    echo "ERROR: ", getCurrentExceptionMsg()
