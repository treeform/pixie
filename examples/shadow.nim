import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let path = newPath()
path.polygon(vec2(100, 100), 70, sides = 8)

let polygonImage = newImage(200, 200)
polygonImage.fillPath(path, rgba(255, 255, 255, 255))

let shadow = polygonImage.shadow(
  offset = vec2(2, 2),
  spread = 2,
  blur = 10,
  color = rgba(0, 0, 0, 200)
)

image.draw(shadow)
image.draw(polygonImage)

image.writeFile("examples/shadow.png")
