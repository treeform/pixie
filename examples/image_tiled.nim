import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var path: Path
path.polygon(
  vec2(100, 100),
  70,
  sides = 8
)
image.fillPath(
  path,
  Paint(
    kind: pkImageTiled,
    image: readImage("tests/images/png/baboon.png"),
    imageMat: scale(vec2(0.08, 0.08))
  )
)

image.writeFile("examples/image_tiled.png")
