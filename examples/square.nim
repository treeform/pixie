import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let ctx = newContext(image)
ctx.fillStyle = rgba(255, 0, 0, 255)

let
  pos = vec2(50, 50)
  wh = vec2(100, 100)

ctx.fillRect(rect(pos, wh))

image.writeFile("examples/square.png")
