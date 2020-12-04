import pixie, chroma, vmath

var image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var trees = readImage("examples/data/trees.png")
var blur = trees.copy()
blur.blur(10)

var p = newPath()
let
  size = 80.0
  x = 100.0
  y = 100.0
p.moveTo(x + size * cos(0.0), y + size * sin(0.0))
for side in 0 ..< 7:
  p.lineTo(
    x + size * cos(side.float32 * 2.0 * PI / 6.0),
    y + size * sin(side.float32 * 2.0 * PI / 6.0)
  )
p.closePath()

var mask = newImage(200, 200)
mask.fillPath(p, rgba(255, 0, 0, 255))
mask.sharpOpacity()
blur.draw(mask, blendMode = bmMask)
image.draw(trees)
image.draw(blur)

image.writeFile("examples/blur.png")
