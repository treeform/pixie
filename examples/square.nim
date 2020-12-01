import pixie, chroma

var image = newImageFill(200, 200, rgba(255, 255, 255, 255))

var p = newPath()
p.moveTo(50, 50)
p.lineTo(50, 150)
p.lineTo(150, 150)
p.lineTo(150, 50)
p.closePath()
image.fillPath(p, rgba(255, 0, 0, 255))
#image.strokePath(p, rgba(0, 0, 0, 255), strokeWidth = 5.0)

image.writeFile("examples/square.png")
