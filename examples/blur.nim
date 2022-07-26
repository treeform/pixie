import pixie

let
  trees = readImage("examples/data/trees.png")
  blur = trees.copy()
  image = newImage(200, 200)

image.fill(rgba(255, 255, 255, 255))

let path = newPath()
path.polygon(vec2(100, 100), 70, sides = 6)

let mask = newImage(200, 200)
mask.fillPath(path, color(1, 1, 1, 1))

blur.blur(20)
blur.draw(mask, blendMode = MaskBlend)

image.draw(trees)
image.draw(blur)

image.writeFile("examples/blur.png")
