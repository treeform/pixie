import chroma, pixie, vmath

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
  image.writeFile("tests/paths/paintSolid.png")

block:
  let paint = newPaint(ImagePaint)
  paint.image = readImage("tests/fileformats/png/mandrill.png")
  paint.imageMat = scale(vec2(0.2, 0.2))

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/paintImage.png")

block:
  let paint = newPaint(ImagePaint)
  paint.image = readImage("tests/fileformats/png/mandrill.png")
  paint.imageMat = scale(vec2(0.2, 0.2))
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/paintImageOpacity.png")

block:
  let paint = newPaint(TiledImagePaint)
  paint.image = readImage("tests/fileformats/png/mandrill.png")
  paint.imageMat = scale(vec2(0.02, 0.02))

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/paintImageTiled.png")

block:
  let paint = newPaint(TiledImagePaint)
  paint.image = readImage("tests/fileformats/png/mandrill.png")
  paint.imageMat = scale(vec2(0.02, 0.02))
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/paintImageTiledOpacity.png")

block:
  let paint = newPaint(LinearGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(0, 50),
    vec2(100, 50),
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/gradientLinear.png")

block:
  let paint = newPaint(LinearGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(50, 0),
    vec2(50, 100),
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/gradientLinear2.png")

block:
  let paint = newPaint(RadialGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(50, 50),
    vec2(100, 50),
    vec2(50, 100)
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/gradientRadial.png")

block:
  let paint = newPaint(AngularGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(50, 50),
    vec2(100, 50),
    vec2(50, 100)
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/gradientAngular.png")

block:
  let paint = newPaint(AngularGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(50, 50),
    vec2(100, 50),
    vec2(50, 100)
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]
  paint.opacity = 0.5

  let image = newImage(100, 100)
  image.fillPath(heartShape, paint)
  image.writeFile("tests/paths/gradientAngularOpacity.png")
