import pixie

let
  trees = readImage("examples/data/trees.png")
  image = newImage(200, 200)

image.fill(rgba(255, 255, 255, 255))

var p: Path
p.polygon(100, 100, 70, sides = 8)
p.closePath()

var polyImage = newImage(200, 200)
polyImage.fillPath(p, rgba(255, 255, 255, 255))

image.draw(polyImage.shadow(
  offset = vec2(2, 2),
  spread = 2,
  blur = 10,
  color = rgba(0, 0, 0, 200)
))
image.draw(polyImage)

image.writeFile("examples/shadow.png")
