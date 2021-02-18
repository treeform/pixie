import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let tiger = readImage("examples/data/tiger.svg")

image.draw(
  tiger,
  translate(vec2(100, 100)) *
  scale(vec2(0.2, 0.2)) *
  translate(vec2(-450, -450))
)

image.writeFile("examples/tiger.png")
