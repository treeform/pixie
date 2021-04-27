import common, pixie

# Clone https://github.com/google/fonts
# Check out commit ebaa6a7aab9b700da4e30a4682687acdf427eae7

let fontPaths = findAllFonts("../fonts")

for fontPath in fontPaths:
  echo fontPath
  let font = readFont(fontPath)
