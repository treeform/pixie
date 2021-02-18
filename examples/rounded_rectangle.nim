import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let
  pos = vec2(50, 50)
  wh = vec2(100, 100)
  r = 25.0

image.drawRoundedRect(rect(pos, wh), r, rgba(0, 255, 0, 255))

image.writeFile("examples/rounded_rectangle.png")
