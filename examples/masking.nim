import pixie

let
  image = newImage(200, 200)
  lines = newImage(200, 200)
  mask = newMask(200, 200)
  color = parseHtmlColor("#F8D1DD").rgba

lines.fill(parseHtmlColor("#FC427B").rgba)
image.fill(rgba(255, 255, 255, 255))

lines.strokeSegment(
  segment(vec2(25, 25), vec2(175, 175)), color, strokeWidth = 30)
lines.strokeSegment(
  segment(vec2(25, 175), vec2(175, 25)), color, strokeWidth = 30)

mask.fillPath(
  """
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """
)
lines.draw(mask)
image.draw(lines)

image.writeFile("examples/masking.png")
