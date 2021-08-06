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
    rgba(255, 0, 0, 255)
  )
  image.writeFile("tests/images/paths/paintSolid.png")

block:
  let paint = newPaint(pkImage)
  paint.image = decodePng(readFile("tests/images/png/baboon.png"))
  paint.imageMat = scale(vec2(0.2, 0.2))

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/paintImage.png")

block:
  let paint = newPaint(pkImage)
  paint.image = decodePng(readFile("tests/images/png/baboon.png"))
  paint.imageMat = scale(vec2(0.2, 0.2))
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/paintImageOpacity.png")

block:
  let paint = newPaint(pkImageTiled)
  paint.image = decodePng(readFile("tests/images/png/baboon.png"))
  paint.imageMat = scale(vec2(0.02, 0.02))

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/paintImageTiled.png")

block:
  let paint = newPaint(pkImageTiled)
  paint.image = decodePng(readFile("tests/images/png/baboon.png"))
  paint.imageMat = scale(vec2(0.02, 0.02))
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/paintImageTiledOpacity.png")

block:
  let paint = newPaint(pkGradientLinear)
  paint.gradientHandlePositions = @[
    vec2(0, 50),
    vec2(100, 50),
  ]
  paint.gradientStops = @[
    ColorStop(color: rgba(255, 0, 0, 255), position: 0),
    ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/gradientLinear.png")

block:
  let paint = newPaint(pkGradientRadial)
  paint.gradientHandlePositions = @[
    vec2(50, 50),
    vec2(100, 50),
    vec2(50, 100)
  ]
  paint.gradientStops = @[
    ColorStop(color: rgba(255, 0, 0, 255), position: 0),
    ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/gradientRadial.png")

block:
  let paint = newPaint(pkGradientAngular)
  paint.gradientHandlePositions = @[
    vec2(50, 50),
    vec2(100, 50),
    vec2(50, 100)
  ]
  paint.gradientStops = @[
    ColorStop(color: rgba(255, 0, 0, 255), position: 0),
    ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/gradientAngular.png")

block:
  let paint = newPaint(pkGradientAngular)
  paint.gradientHandlePositions = @[
    vec2(50, 50),
    vec2(100, 50),
    vec2(50, 100)
  ]
  paint.gradientStops = @[
    ColorStop(color: rgba(255, 0, 0, 255), position: 0),
    ColorStop(color: rgba(255, 0, 0, 40), position: 1.0),
  ]
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/images/paths/gradientAngularOpacity.png")
