import chroma, pixie, vmath

let
  trees = readImage("examples/data/trees.png")
  blur = trees.copy()
  image = newImage(200, 200)

image.fill(rgba(255, 255, 255, 255))

var p: Path
p.polygon(100, 100, 70, sides = 6)
p.closePath()

let mask = newMask(200, 200)
mask.fillPath(p)

blur.blur(20)
blur.draw(mask, blendMode = bmMask)

image.draw(trees)
image.draw(blur)

image.writeFile("examples/blur.png")
