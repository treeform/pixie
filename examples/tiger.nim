import pixie, chroma, vmath

var image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var tiger = readImage("examples/data/tiger.svg")
image.draw(
  tiger,
  translate(vec2(100, 100)) *
  scale(vec2(0.2, 0.2)) *
  translate(vec2(-450, -450))
)

image.writeFile("examples/tiger.png")
