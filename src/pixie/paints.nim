import blends, chroma, common, images, vmath

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

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

converter parseSomePaint*(paint: SomePaint): Paint {.inline.} =
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

proc colorStop*(color: Color, position: float32): ColorStop =
  ColorStop(color: color, position: position)

proc gradientColor(paint: Paint, t: float32): ColorRGBX =
  ## Get the gradient color based on `t` - where are we related to a line.
  var index = -1
  for i, stop in paint.gradientStops:
    if stop.position < t:
      index = i
    if stop.position > t:
      break
  var color: Color
  if index == -1:
    # first stop solid
    color = paint.gradientStops[0].color
  elif index + 1 >= paint.gradientStops.len:
    # last stop solid
    color = paint.gradientStops[index].color
  else:
    let
      gs1 = paint.gradientStops[index]
      gs2 = paint.gradientStops[index + 1]
    color = mix(
      gs1.color,
      gs2.color,
      (t - gs1.position) / (gs2.position - gs1.position)
    )
  color.a *= paint.opacity
  color.rgbx()

proc fillGradientLinear(image: Image, paint: Paint) =
  ## Fills a linear gradient.

  if paint.gradientHandlePositions.len != 2:
    raise newException(PixieError, "Linear gradient requires 2 handles")

  if paint.gradientStops.len == 0:
    raise newException(PixieError, "Gradient must have at least 1 color stop")

  if paint.opacity == 0:
    return

  proc toLineSpace(at, to, point: Vec2): float32 {.inline.} =
    ## Convert position on to where it would fall on a line between at and to.
    let
      d = to - at
      det = d.x * d.x + d.y * d.y
    (d.y * (point.y - at.y) + d.x * (point.x - at.x)) / det

  let
    at = paint.gradientHandlePositions[0]
    to = paint.gradientHandlePositions[1]

  if at.y == to.y: # Horizontal gradient
    var x: int
    while x < image.width:
      when defined(amd64) and not defined(pixieNoSimd):
        if x + 4 <= image.width:
          var colors: array[4, ColorRGBX]
          for i in 0 ..< 4:
            let
              xy = vec2((x + i).float32, 0.float32)
              t = toLineSpace(at, to, xy)
              rgbx = paint.gradientColor(t)
            colors[i] = rgbx

          let colorVec = cast[M128i](colors)
          for y in 0 ..< image.height:
            mm_storeu_si128(image.data[image.dataIndex(x, y)].addr, colorVec)
          x += 4
          continue

      let
        xy = vec2(x.float32, 0.float32)
        t = toLineSpace(at, to, xy)
        rgbx = paint.gradientColor(t)
      for y in 0 ..< image.height:
        image.setRgbaUnsafe(x, y, rgbx)
      inc x

  elif at.x == to.x: # Vertical gradient
    for y in 0 ..< image.height:
      let
        xy = vec2(0.float32, y.float32)
        t = toLineSpace(at, to, xy)
        rgbx = paint.gradientColor(t)
      var x: int
      when defined(amd64) and not defined(pixieNoSimd):
        let colorVec = mm_set1_epi32(cast[int32](rgbx))
        for _ in 0 ..< image.width div 4:
          mm_storeu_si128(image.data[image.dataIndex(x, y)].addr, colorVec)
          x += 4
      for x in x ..< image.width:
        image.setRgbaUnsafe(x, y, rgbx)

  else:
    for y in 0 ..< image.height:
      for x in 0 ..< image.width:
        let
          xy = vec2(x.float32, y.float32)
          t = toLineSpace(at, to, xy)
        image.setRgbaUnsafe(x, y, paint.gradientColor(t))

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
      image.setRgbaUnsafe(x, y, paint.gradientColor(t))

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
    f32PI = PI.float32
  # TODO: make edge between start and end anti-aliased.
  let gradientAngle = normalize(edge - center).angle().fixAngle()
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        xy = vec2(x.float32, y.float32)
        angle = normalize(xy - center).angle()
        t = (angle + gradientAngle + f32PI / 2).fixAngle() / 2 / f32PI + 0.5.float32
      image.setRgbaUnsafe(x, y, paint.gradientColor(t))

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
