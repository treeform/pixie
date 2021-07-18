import blends, chroma, common, images, internal, options, vmath

type
  PaintKind* = enum
    pkSolid
    pkImage
    pkImageTiled
    pkGradientLinear
    pkGradientRadial
    pkGradientAngular

  Paint* = object
    ## Paint used to fill paths.
    case kind*: PaintKind
    of pkSolid:
      color*: ColorRGBX                   ## Color to fill with.
    of pkImage, pkImageTiled:
      image*: Image                       ## Image to fill with.
      imageMat*: Mat3                     ## Matrix of the filled image.
    of pkGradientLinear, pkGradientRadial, pkGradientAngular:
      gradientHandlePositions*: seq[Vec2] ## Gradient positions (image space).
      gradientStops*: seq[ColorStop]      ## Color stops (gradient space).
    blendMode*: BlendMode                 ## Blend mode.
    opacityOption: Option[float32]

  ColorStop* = object
    ## Color stop on a gradient curve.
    color*: ColorRGBX  ## Color of the stop
    position*: float32 ## Gradient Stop position 0..1.

  SomePaint* = string | Paint | SomeColor

converter parseSomePaint*(paint: SomePaint): Paint {.inline.} =
  ## Given SomePaint, parse it in different ways.
  when type(paint) is string:
    Paint(kind: pkSolid, color: parseHtmlColor(paint).rgbx())
  elif type(paint) is SomeColor:
    when type(paint) is ColorRGBX:
      Paint(kind: pkSolid, color: paint)
    else:
      Paint(kind: pkSolid, color: paint.rgbx())
  elif type(paint) is Paint:
    paint

proc opacity*(paint: Paint): float32 =
  ## Paint opacity (applies with color or image opacity).
  if paint.opacityOption.isSome:
    paint.opacityOption.get()
  else:
    1

proc `opacity=`*(paint: var Paint, opacity: float32) =
  ## Set the paint opacity (applies with color or image opacity).
  if opacity >= 0 and opacity <= 1:
    paint.opacityOption = some(opacity)
  else:
    raise newException(PixieError, "Invalid opacity: " & $opacity)

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
  var color: ColorRGBX
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
  if paint.opacity != 1:
    color = color.applyOpacity(paint.opacity)
  image.setRgbaUnsafe(x, y, color.rgba.rgbx())

proc fillGradientLinear*(image: Image, paint: Paint) =
  ## Fills a linear gradient.

  if paint.kind != pkGradientLinear:
    raise newException(PixieError, "Paint kind must be " & $pkGradientLinear)

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

proc fillGradientRadial*(image: Image, paint: Paint) =
  ## Fills a radial gradient.

  if paint.kind != pkGradientRadial:
    raise newException(PixieError, "Paint kind must be " & $pkGradientRadial)

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

proc fillGradientAngular*(image: Image, paint: Paint) =
  ## Fills an angular gradient.

  if paint.kind != pkGradientAngular:
    raise newException(PixieError, "Paint kind must be " & $pkGradientAngular)

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
