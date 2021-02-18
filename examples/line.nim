import pixie

let
  image = newImage(200, 200)

image.fill(rgba(255, 255, 255, 255))

var p: Path
p.moveTo(25, 25)
p.lineTo(175, 175)

image.strokePath(
  p,
  parseHtmlColor("#FF5C00").rgba,
  strokeWidth = 10,
)

image.writeFile("examples/line.png")
