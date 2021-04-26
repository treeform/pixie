import pixie

let image = newImage(100, 100)
image.fill(rgba(255, 255, 255, 255))

let flower = readImage("examples/data/scale.svg")

image.draw(
  flower
)

image.writeFile("examples/scale.png")
