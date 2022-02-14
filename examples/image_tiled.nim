import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let path = newPath()
path.polygon(
  vec2(100, 100),
  70,
  sides = 8
)

let paint = newPaint(TiledImagePaint)
paint.image = readImage("examples/data/mandrill.png")
paint.imageMat = scale(vec2(0.08, 0.08))

image.fillPath(path, paint)
image.writeFile("examples/image_tiled.png")
