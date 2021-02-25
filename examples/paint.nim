import pixie

let
  image = newImage(200, 200)

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
  Paint(
    kind:pkGradientRadial,
    gradientHandlePositions: @[
      vec2(100, 100),
      vec2(200, 100),
      vec2(100, 200)
    ],
    gradientStops: @[
      ColorStop(color:rgba(255, 0, 0, 255).color, position: 0),
      ColorStop(color:rgba(255, 0, 0, 40).color, position: 1.0),
    ]
  )
)

image.writeFile("examples/paint.png")
