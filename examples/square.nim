import pixie, chroma

var image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var p: Path
p.moveTo(50, 50)
p.lineTo(50, 150)
p.lineTo(150, 150)
p.lineTo(150, 50)
p.closePath()

image.fillPath(p, rgba(255, 0, 0, 255))

image.writeFile("examples/square.png")
