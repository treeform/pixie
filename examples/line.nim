import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let ctx = newContext(image)
ctx.strokeStyle = "#FF5C00"
ctx.lineWidth = 10

let
  start = vec2(25, 25)
  stop = vec2(175, 175)

ctx.strokeSegment(segment(start, stop))

image.writeFile("examples/line.png")
