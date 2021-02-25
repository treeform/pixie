import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

image.fillPath(
  """
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """,
  parseHtmlColor("#FC427B").rgba
)

image.writeFile("examples/heart.png")
