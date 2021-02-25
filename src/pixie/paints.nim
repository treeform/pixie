import chroma, common, images, vmath, blends

type
  PaintKind* = enum
    pkSolid
    pkImage
    pkImageTiled
    pkGradientLinear
    pkGradientRadial
    pkGradientAngular

  Paint* = ref object
    kind*: PaintKind
    color*: ColorRGBA
    image*: Image
    imageMat*: Mat3
    gradientHandlePositions*: seq[Vec2]
    gradientStops*: seq[ColorStop]
    blendMode*: BlendMode

  ColorStop* = object
    ## Represents color on a gradient curve.
    color*: Color
    position*: float32

proc fillImage*(
  dest: Image,
  src: Image,
  mat: Mat3
) =
  dest.draw(
    src,
    mat
  )

proc fillImageTiled*(
  dest: Image,
  src: Image,
  mat: Mat3
) =
  var
    matInv = mat.inverse()
    src = src

  block: # Shrink by 2 as needed
    const h = 0.5.float32
    var
      p = matInv * vec2(0 + h, 0 + h)
      dx = matInv * vec2(1 + h, 0 + h) - p
      dy = matInv * vec2(0 + h, 1 + h) - p
      minFilterBy2 = max(dx.length, dy.length)

    while minFilterBy2 > 2:
      src = src.minifyBy2()
      dx /= 2
      dy /= 2
      minFilterBy2 /= 2
      matInv = matInv * scale(vec2(0.5, 0.5))

  for y in 0 ..< dest.height:
    for x in 0 ..< dest.width:
      var srcPos = matInv * vec2(x.float32, y.float32)
      let rgba = src.getRgbaSmoothWrapped(srcPos.x, srcPos.y)
      dest.setRgbaUnsafe(x,y, rgba)

proc toLineSpace(at, to, point: Vec2): float32 =
  ## Convert position on to where it would fall on a line between at and to.
  let
    d = to - at
    det = d.x*d.x + d.y*d.y
  return (d.y*(point.y-at.y)+d.x*(point.x-at.x))/det

proc gradientPut(image: Image, x, y: int, a: float32, stops: seq[ColorStop]) =
  ## Put an gradient color based on the "a" - were are we related to a line.
  var
    index = -1
  for i, stop in stops:
    if stop.position < a:
      index = i
    if stop.position > a:
      break
  var color: Color
  if index == -1:
    # first stop solid
    color = stops[0].color
  elif index + 1 >= stops.len:
    # last stop solid
    color = stops[index].color
  else:
    let
      gs1 = stops[index]
      gs2 = stops[index+1]
    color = mix(
      gs1.color,
      gs2.color,
      (a - gs1.position) / (gs2.position - gs1.position)
    )
  image.setRgbaUnsafe(x, y, color.rgba.toPremultipliedAlpha())

proc fillLinearGradient*(
  image: Image,
  at, to: Vec2,
  stops: seq[ColorStop]
) =
  ## Linear gradient.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let xy = vec2(x.float32, y.float32)
      let a = toLineSpace(at, to, xy)
      image.gradientPut(x, y, a, stops)

proc fillRadialGradient*(
  image: Image,
  center, edge, skew: Vec2,
  stops: seq[ColorStop]
) =
  ## Radial gradient.
  ## start, stop, and skew.
  let
    distanceX = dist(center, edge)
    distanceY = dist(center, skew)
    gradientAngle = normalize(center - edge).angle().fixAngle()
    mat = (
      translate(center) *
      rotationMat3(-gradientAngle) *
      scale(vec2(distanceX, distanceY))
    ).inverse()
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let xy = vec2(x.float32, y.float32)
      let b = (mat * xy).length()
      image.gradientPut(x, y, b, stops)

proc fillAngularGradient*(
  image: Image,
  center, edge, skew: Vec2,
  stops: seq[ColorStop]
) =
  # TODO: make edge between start and end anti-aliased.
  let
    gradientAngle = normalize(edge - center).angle().fixAngle()
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        xy = vec2(x.float32, y.float32)
        angle = normalize(xy - center).angle()
        a = (angle + gradientAngle + PI/2).fixAngle() / 2 / PI + 0.5
      image.gradientPut(x, y, a, stops)
