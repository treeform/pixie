import chroma, pixie

var image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var p: Path
p.rect(50, 50, 100, 100)

image.fillPath(p, rgba(255, 0, 0, 255))

image.writeFile("examples/square.png")
