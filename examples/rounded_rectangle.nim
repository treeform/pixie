import pixie, chroma

var image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var path = newPath()
let
  x = 50.0
  y = 50.0
  w = 100.0
  h = 100.0
  r = 25.0
path.moveTo(x+r, y)
path.arcTo(x+w, y,   x+w, y+h, r)
path.arcTo(x+w, y+h, x,   y+h, r)
path.arcTo(x,   y+h, x,   y,   r)
path.arcTo(x,   y,   x+w, y,   r)
path.closePath()
image.fillPath(path, rgba(255, 0, 0, 255))

image.writeFile("examples/rounded_rectangle.png")
