import pixie

let
  trees = readImage("examples/data/trees.png")
  blur = trees.copy()
  image = newImage(200, 200)

image.fill(rgba(255, 255, 255, 255))

let path = newPath()
path.polygon(vec2(100, 100), 70, sides = 6)

let mask = newMask(200, 200)
mask.fillPath(path)

blur.blur(20)
blur.draw(mask, blendMode = MaskBlend)

image.draw(trees)
image.draw(blur)

image.writeFile("examples/blur.png")
