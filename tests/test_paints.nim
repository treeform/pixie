import chroma, pixie, pixie/fileformats/png, vmath

const heartShape = """
    M 10,30
    A 20,20 0,0,1 50,30
    A 20,20 0,0,1 90,30
    Q 90,60 50,90
    Q 10,60 10,30 z
  """

block:
  let image = newImage(100, 100)
  image.fillPath(
    heartShape,
    Paint(
      kind: pkSolid,
      color: rgba(255, 0, 0, 255)
    )
  )
  image.writeFile("tests/images/paths/paintSolid.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    heartShape,
    Paint(
      kind: pkImage,
      image: decodePng(readFile("tests/images/png/baboon.png")),
      imageMat: scale(vec2(0.2, 0.2))
    )
  )
  image.writeFile("tests/images/paths/paintImage.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    heartShape,
    Paint(
      kind: pkImageTiled,
      image: decodePng(readFile("tests/images/png/baboon.png")),
      imageMat: scale(vec2(0.02, 0.02))
    )
  )
  image.writeFile("tests/images/paths/paintImageTiled.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    heartShape,
    Paint(
      kind: pkGradientLinear,
      gradientHandlePositions: @[
        vec2(0, 50),
        vec2(100, 50),
    ],
    gradientStops: @[
      ColorStop(color: rgba(255, 0, 0, 255), position: 0),
      ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
    ]
  )
  )
  image.writeFile("tests/images/paths/gradientLinear.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    heartShape,
    Paint(
      kind: pkGradientRadial,
      gradientHandlePositions: @[
        vec2(50, 50),
        vec2(100, 50),
        vec2(50, 100)
    ],
    gradientStops: @[
      ColorStop(color: rgba(255, 0, 0, 255), position: 0),
      ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
    ]
  )
  )

  image.writeFile("tests/images/paths/gradientRadial.png")

block:
  let image = newImage(100, 100)
  image.fillPath(
    heartShape,
    Paint(
      kind: pkGradientAngular,
      gradientHandlePositions: @[
        vec2(50, 50),
        vec2(100, 50),
        vec2(50, 100)
    ],
    gradientStops: @[
      ColorStop(color: rgba(255, 0, 0, 255), position: 0),
      ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
    ]
  )
  )

  image.writeFile("tests/images/paths/gradientAngular.png")
