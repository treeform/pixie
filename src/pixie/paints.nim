import blends, chroma, common, images, vmath

type
  PaintKind* = enum
    pkSolid
    pkImage
    pkImageTiled
    pkGradientLinear
    pkGradientRadial
    pkGradientAngular

  Paint* = ref object
    ## Paint used to fill paths.
    kind*: PaintKind
    blendMode*: BlendMode               ## Blend mode.
    opacity*: float32
    # pkSolid
    color*: Color                       ## Color to fill with.
    # pkImage, pkImageTiled:
    image*: Image                       ## Image to fill with.
    imageMat*: Mat3                     ## Matrix of the filled image.
    # pkGradientLinear, pkGradientRadial, pkGradientAngular:
    gradientHandlePositions*: seq[Vec2] ## Gradient positions (image space).
    gradientStops*: seq[ColorStop]      ## Color stops (gradient space).

  ColorStop* = object
    ## Color stop on a gradient curve.
    color*: Color      ## Color of the stop.
    position*: float32 ## Gradient stop position 0..1.

  SomePaint* = string | Paint | SomeColor

proc newPaint*(kind: PaintKind): Paint {.raises: [].} =
  ## Create a new Paint.
  result = Paint(kind: kind, opacity: 1, imageMat: mat3())

proc newPaint*(paint: Paint): Paint {.raises: [].} =
  ## Create a new Paint with the same properties.
  result = newPaint(paint.kind)
  result.blendMode = paint.blendMode
  result.opacity = paint.opacity
  result.color = paint.color
  result.image = paint.image
  result.imageMat = paint.imageMat
  result.gradientHandlePositions = paint.gradientHandlePositions
  result.gradientStops = paint.gradientStops

converter parseSomePaint*(
  paint: SomePaint
): Paint {.inline, raises: [PixieError].} =
  ## Given SomePaint, parse it in different ways.
  when type(paint) is string:
    result = newPaint(pkSolid)
    try:
      result.color = parseHtmlColor(paint)
    except:
      raise newException(PixieError, "Unable to parse color " & paint)
  elif type(paint) is SomeColor:
    result = newPaint(pkSolid)
    when type(paint) is Color:
      result.color = paint
    else:
      result.color = paint.color()
  elif type(paint) is Paint:
    paint

proc toLineSpace(at, to, point: Vec2): float32 {.inline.} =
  ## Convert position on to where it would fall on a line between at and to.
  let
    d = to - at
    det = d.x * d.x + d.y * d.y
  (d.y * (point.y - at.y) + d.x * (point.x - at.x)) / det

proc gradientPut(
  image: Image, paint: Paint, x, y: int, t: float32, stops: seq[ColorStop]
) =
  ## Put an gradient color based on `t` - where are we related to a line.
  var index = -1
  for i, stop in stops:
    if stop.position < t:
      index = i
    if stop.position > t:
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
      gs2 = stops[index + 1]
    color = lerp(
      gs1.color,
      gs2.color,
      (t - gs1.position) / (gs2.position - gs1.position)
    )
  color.a *= paint.opacity
  image.setRgbaUnsafe(x, y, color.rgbx())

proc fillGradientLinear(image: Image, paint: Paint) =
  ## Fills a linear gradient.

  if paint.gradientHandlePositions.len != 2:
    raise newException(PixieError, "Linear gradient requires 2 handles")

  if paint.gradientStops.len == 0:
    raise newException(PixieError, "Gradient must have at least 1 color stop")

  if paint.opacity == 0:
    return

  let
    at = paint.gradientHandlePositions[0]
    to = paint.gradientHandlePositions[1]
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        xy = vec2(x.float32, y.float32)
        t = toLineSpace(at, to, xy)
      image.gradientPut(paint, x, y, t, paint.gradientStops)

proc fillGradientRadial(image: Image, paint: Paint) =
  ## Fills a radial gradient.

  if paint.gradientHandlePositions.len != 3:
    raise newException(PixieError, "Radial gradient requires 3 handles")

  if paint.gradientStops.len == 0:
    raise newException(PixieError, "Gradient must have at least 1 color stop")

  if paint.opacity == 0:
    return

  let
    center = paint.gradientHandlePositions[0]
    edge = paint.gradientHandlePositions[1]
    skew = paint.gradientHandlePositions[2]
    distanceX = dist(center, edge)
    distanceY = dist(center, skew)
    gradientAngle = normalize(center - edge).angle().fixAngle()
    mat = (
      translate(center) *
      rotate(-gradientAngle) *
      scale(vec2(distanceX, distanceY))
    ).inverse()
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        xy = vec2(x.float32, y.float32)
        t = (mat * xy).length()
      image.gradientPut(paint, x, y, t, paint.gradientStops)

proc fillGradientAngular(image: Image, paint: Paint) =
  ## Fills an angular gradient.

  if paint.gradientHandlePositions.len != 3:
    raise newException(PixieError, "Angular gradient requires 2 handles")

  if paint.gradientStops.len == 0:
    raise newException(PixieError, "Gradient must have at least 1 color stop")

  if paint.opacity == 0:
    return

  let
    center = paint.gradientHandlePositions[0]
    edge = paint.gradientHandlePositions[1]
  # TODO: make edge between start and end anti-aliased.
  let gradientAngle = normalize(edge - center).angle().fixAngle()
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        xy = vec2(x.float32, y.float32)
        angle = normalize(xy - center).angle()
        t = (angle + gradientAngle + PI / 2).fixAngle() / 2 / PI + 0.5
      image.gradientPut(paint, x, y, t, paint.gradientStops)

proc fillGradient*(image: Image, paint: Paint) {.raises: [PixieError].} =
  ## Fills with the Paint gradient.

  case paint.kind:
  of pkGradientLinear:
    image.fillGradientLinear(paint)
  of pkGradientRadial:
    image.fillGradientRadial(paint)
  of pkGradientAngular:
    image.fillGradientAngular(paint)
  else:
    raise newException(PixieError, "Paint must be a gradient")
