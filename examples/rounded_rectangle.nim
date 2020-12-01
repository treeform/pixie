import pixie, chroma

var image = newImageFill(200, 200, rgba(255, 255, 255, 255))

var path = newPath()
let
  x = 50.0
  y = 50.0
  w = 100.0
  h = 100.0
  nw = 25.0
  ne = 25.0
  se = 25.0
  sw = 25.0
path.moveTo(x+nw, y)
path.arcTo(x+w, y,   x+w, y+h, ne)
path.arcTo(x+w, y+h, x,   y+h, se)
path.arcTo(x,   y+h, x,   y,   sw)
path.arcTo(x,   y,   x+w, y,   nw)
path.closePath()
path.closePath()
image.fillPath(path, rgba(255, 0, 0, 255))
#image.strokePath(path, rgba(0, 0, 0, 255), strokeWidth = 5.0)

image.writeFile("examples/rounded_rectangle.png")
