import pixie

let
  image = newImage(200, 200)
  lines = newImage(200, 200)
  mask = newImage(200, 200)

lines.fill(parseHtmlColor("#FC427B").rgba)
image.fill(rgba(255, 255, 255, 255))

let ctx = newContext(lines)
ctx.strokeStyle = "#F8D1DD"
ctx.lineWidth = 30

ctx.strokeSegment(segment(vec2(25, 25), vec2(175, 175)))
ctx.strokeSegment(segment(vec2(25, 175), vec2(175, 25)))

mask.fillPath(
  """
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """,
  color(1, 1, 1, 1)
)
lines.draw(mask, blendMode = MaskBlend)
image.draw(lines)

image.writeFile("examples/masking.png")
