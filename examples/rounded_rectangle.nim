import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let
  x = 50.0
  y = 50.0
  w = 100.0
  h = 100.0
  r = 25.0

var path: Path
path.roundedRect(vec2(x, y), vec2(w, h), r, r, r, r)

image.fillPath(path, rgba(0, 255, 0, 255))

image.writeFile("examples/rounded_rectangle.png")
