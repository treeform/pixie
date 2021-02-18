import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let
  start = vec2(25, 25)
  stop = vec2(175, 175)
  color = parseHtmlColor("#FF5C00").rgba

image.drawSegment(segment(start, stop), color, strokeWidth = 10)

image.writeFile("examples/line.png")
