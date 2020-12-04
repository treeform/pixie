import pixie, chroma, vmath

var trees = readImage("examples/data/trees.png")
var blur = trees.copy()
var image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var p = newPath()
p.polygon(100, 100, 70, sides=6)
p.closePath()
var mask = newImage(200, 200)
mask.fillPath(p, rgba(255, 255, 255, 255))
blur.blur(20)
blur.draw(mask, blendMode = bmMask)
image.draw(trees)
image.draw(blur)

image.writeFile("examples/blur.png")
