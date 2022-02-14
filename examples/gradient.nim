import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let paint = newPaint(RadialGradientPaint)
paint.gradientHandlePositions = @[
  vec2(100, 100),
  vec2(200, 100),
  vec2(100, 200)
]
paint.gradientStops = @[
  ColorStop(color: color(1, 0, 0, 1), position: 0),
  ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
]

image.fillPath(
  """
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """,
  paint
)

image.writeFile("examples/gradient.png")
