## Load and Save SVG files.

import cairo, chroma, pixie/common, pixie/images, pixie/paints, strutils,
    tables, vmath, xmlparser, xmltree

include pixie/paths

proc processCommands(
  c: ptr Context, path: Path, closeSubpaths: bool, mat: Mat3
) =
  let shapes = path.commandsToShapes(closeSubpaths, mat.pixelScale())
  if shapes.len == 0:
    return

  c.newPath()
  c.moveTo(shapes[0][0].x, shapes[0][0].y)
  for shape in shapes:
    for v in shape:
      c.lineTo(v.x, v.y)

proc prepare(
  c: ptr Context,
  path: Path,
  paint: Paint,
  mat: Mat3,
  closeSubpaths: bool,
  windingRule = NonZero
) =
  let
    color = paint.color
    matrix = Matrix(
      xx: mat[0, 0],
      yx: mat[0, 1],
      xy: mat[1, 0],
      yy: mat[1, 1],
      x0: mat[2, 0],
      y0: mat[2, 1],
    )
  c.setSourceRgba(color.r, color.g, color.b, color.a)
  c.setMatrix(matrix.unsafeAddr)
  case windingRule:
  of NonZero:
    c.setFillRule(FillRuleWinding)
  else:
    c.setFillRule(FillRuleEvenOdd)
  c.processCommands(path, closeSubpaths, mat)

type
  LinearGradient = object
    x1, y1, x2, y2: float32
    stops: seq[ColorStop]

  Ctx = object
    display: bool
    fillRule: WindingRule
    fill: Paint
    stroke: ColorRGBX
    strokeWidth: float32
    strokeLineCap: LineCap
    strokeLineJoin: LineJoin
    strokeMiterLimit: float32
    strokeDashArray: seq[float32]
    transform: Mat3
    shouldStroke: bool
    opacity, strokeOpacity: float32
    linearGradients: TableRef[string, LinearGradient]

template failInvalid() =
  raise newException(PixieError, "Invalid SVG data")

proc attrOrDefault(node: XmlNode, name, default: string): string =
  result = node.attr(name)
  if result.len == 0:
    result = default

proc initCtx(): Ctx =
  result.display = true
  try:
    result.fill = parseHtmlColor("black").rgbx
    result.stroke = parseHtmlColor("black").rgbx
  except:
    raise currentExceptionAsPixieError()
  result.strokeWidth = 1
  result.transform = mat3()
  result.strokeMiterLimit = defaultMiterLimit
  result.opacity = 1
  result.strokeOpacity = 1
  result.linearGradients = newTable[string, LinearGradient]()

proc decodeCtxInternal(inherited: Ctx, node: XmlNode): Ctx =
  result = inherited

  proc splitArgs(s: string): seq[string] =
    # Handles (1,1) or (1 1) or (1, 1) or (1,1 2,2) etc
    let tmp = s.replace(',', ' ').split(' ')
    for entry in tmp:
      if entry.len > 0:
        result.add(entry)

  var
    fillRule = node.attr("fill-rule")
    fill = node.attr("fill")
    stroke = node.attr("stroke")
    strokeWidth = node.attr("stroke-width")
    strokeLineCap = node.attr("stroke-linecap")
    strokeLineJoin = node.attr("stroke-linejoin")
    strokeMiterLimit = node.attr("stroke-miterlimit")
    strokeDashArray = node.attr("stroke-dasharray")
    transform = node.attr("transform")
    style = node.attr("style")
    display = node.attr("display")
    opacity = node.attr("opacity")
    fillOpacity = node.attr("fill-opacity")
    strokeOpacity = node.attr("stroke-opacity")

  let pairs = style.split(';')
  for pair in pairs:
    let parts = pair.split(':')
    if parts.len == 2:
      # Do not override element properties
      case parts[0].strip():
      of "fill-rule":
        if fillRule.len == 0:
          fillRule = parts[1].strip()
      of "fill":
        if fill.len == 0:
          fill = parts[1].strip()
      of "stroke":
        if stroke.len == 0:
          stroke = parts[1].strip()
      of "stroke-linecap":
        if strokeLineCap.len == 0:
          strokeLineCap = parts[1].strip()
      of "stroke-linejoin":
        if strokeLineJoin.len == 0:
          strokeLineJoin = parts[1].strip()
      of "stroke-width":
        if strokeWidth.len == 0:
          strokeWidth = parts[1].strip()
      of "stroke-miterlimit":
        if strokeMiterLimit.len == 0:
          strokeMiterLimit = parts[1].strip()
      of "stroke-dasharray":
        if strokeDashArray.len == 0:
          strokeDashArray = parts[1].strip()
      of "display":
        if display.len == 0:
          display = parts[1].strip()
      of "opacity":
        if opacity.len == 0:
          opacity = parts[1].strip()
      of "fillOpacity":
        if fillOpacity.len == 0:
          fillOpacity = parts[1].strip()
      of "strokeOpacity":
        if strokeOpacity.len == 0:
          strokeOpacity = parts[1].strip()
      else:
        discard
    elif pair.len > 0:
      when defined(pixieDebugSvg):
        echo "Invalid style pair: ", pair

  if display.len > 0:
    result.display = display.strip() != "none"

  if opacity.len > 0:
    result.opacity = clamp(parseFloat(opacity), 0, 1)

  if fillOpacity.len > 0:
    result.fill.opacity = clamp(parseFloat(fillOpacity), 0, 1)

  if strokeOpacity.len > 0:
    result.strokeOpacity = clamp(parseFloat(strokeOpacity), 0, 1)

  if fillRule == "":
    discard # Inherit
  elif fillRule == "nonzero":
    result.fillRule = NonZero
  elif fillRule == "evenodd":
    result.fillRule = EvenOdd
  else:
    raise newException(
      PixieError, "Invalid fill-rule value " & fillRule
    )

  if fill == "" or fill == "currentColor":
    discard # Inherit
  elif fill == "none":
    result.fill = ColorRGBX()
  elif fill.startsWith("url("):
    let id = fill[5 .. ^2]
    if id in result.linearGradients:
      let linearGradient = result.linearGradients[id]
      result.fill = newPaint(LinearGradientPaint)
      result.fill.gradientHandlePositions = @[
        result.transform * vec2(linearGradient.x1, linearGradient.y1),
        result.transform * vec2(linearGradient.x2, linearGradient.y2)
      ]
      result.fill.gradientStops = linearGradient.stops
    else:
      raise newException(PixieError, "Missing SVG resource " & id)
  else:
    result.fill = parseHtmlColor(fill).rgbx

  if stroke == "":
    discard # Inherit
  elif stroke == "currentColor":
    result.shouldStroke = true
  elif stroke == "none":
    result.stroke = ColorRGBX()
  else:
    result.stroke = parseHtmlColor(stroke).rgbx
    result.shouldStroke = true

  if strokeWidth == "":
    discard # Inherit
  else:
    if strokeWidth.endsWith("px"):
      strokeWidth = strokeWidth[0 .. ^3]
    result.strokeWidth = parseFloat(strokeWidth)
    result.shouldStroke = true

  if result.stroke == ColorRGBX() or result.strokeWidth <= 0:
    result.shouldStroke = false

  if strokeLineCap == "":
    discard # Inherit
  else:
    case strokeLineCap:
    of "butt":
      result.strokeLineCap = ButtCap
    of "round":
      result.strokeLineCap = RoundCap
    of "square":
      result.strokeLineCap = SquareCap
    of "inherit":
      discard
    else:
      raise newException(
        PixieError, "Invalid stroke-linecap value " & strokeLineCap
      )

  if strokeLineJoin == "":
    discard # Inherit
  else:
    case strokeLineJoin:
    of "miter":
      result.strokeLineJoin = MiterJoin
    of "round":
      result.strokeLineJoin = RoundJoin
    of "bevel":
      result.strokeLineJoin = BevelJoin
    of "inherit":
      discard
    else:
      raise newException(
        PixieError, "Invalid stroke-linejoin value " & strokeLineJoin
      )

  if strokeMiterLimit == "":
    discard
  else:
    result.strokeMiterLimit = parseFloat(strokeMiterLimit)

  if strokeDashArray == "":
    discard
  else:
    var values = splitArgs(strokeDashArray)
    for value in values:
      result.strokeDashArray.add(parseFloat(value))

  if transform == "":
    discard # Inherit
  else:
    template failInvalidTransform(transform: string) =
      raise newException(
          PixieError, "Unsupported SVG transform: " & transform
        )

    var remaining = transform
    while remaining.len > 0:
      let index = remaining.find(")")
      if index == -1:
        failInvalidTransform(transform)
      let f = remaining[0 .. index].strip()
      remaining = remaining[index + 1 .. ^1]

      if f.startsWith("matrix("):
        let arr = splitArgs(f[7 .. ^2])
        if arr.len != 6:
          failInvalidTransform(transform)
        var m = mat3()
        m[0, 0] = parseFloat(arr[0])
        m[0, 1] = parseFloat(arr[1])
        m[1, 0] = parseFloat(arr[2])
        m[1, 1] = parseFloat(arr[3])
        m[2, 0] = parseFloat(arr[4])
        m[2, 1] = parseFloat(arr[5])
        result.transform = result.transform * m
      elif f.startsWith("translate("):
        let
          components = splitArgs(f[10 .. ^2])
          tx = parseFloat(components[0])
          ty =
            if components.len == 1:
              0.0
            else:
              parseFloat(components[1])
        result.transform = result.transform * translate(vec2(tx, ty))
      elif f.startsWith("rotate("):
        let
          values = splitArgs(f[7 .. ^2])
          angle: float32 = parseFloat(values[0]) * -PI / 180
        var cx, cy: float32
        if values.len > 1:
          cx = parseFloat(values[1])
        if values.len > 2:
          cy = parseFloat(values[2])
        let center = vec2(cx, cy)
        result.transform = result.transform *
          translate(center) * rotate(angle) * translate(-center)
      elif f.startsWith("scale("):
        let
          values = splitArgs(f[6 .. ^2])
          sx: float32 = parseFloat(values[0])
          sy: float32 =
            if values.len > 1:
              parseFloat(values[1])
            else:
              sx
        result.transform = result.transform * scale(vec2(sx, sy))
      else:
        failInvalidTransform(transform)

proc decodeCtx(inherited: Ctx, node: XmlNode): Ctx =
  try:
    decodeCtxInternal(inherited, node)
  except PixieError as e:
    raise e
  except:
    raise currentExceptionAsPixieError()

proc cairoLineCap(lineCap: LineCap): cairo.LineCap =
  case lineCap:
  of ButtCap:
    LineCapButt
  of RoundCap:
    LineCapRound
  of SquareCap:
    LineCapSquare

proc cairoLineJoin(lineJoin: LineJoin): cairo.LineJoin =
  case lineJoin:
  of MiterJoin:
    LineJoinMiter
  of BevelJoin:
    LineJoinBevel
  of RoundJoin:
    LineJoinRound

proc fill(c: ptr Context, ctx: Ctx, path: Path) {.inline.} =
  if ctx.display and ctx.opacity > 0:
    let paint = newPaint(ctx.fill)
    paint.opacity = paint.opacity * ctx.opacity
    prepare(c, path, paint, ctx.transform, true, ctx.fillRule)
    c.fill()

proc stroke(c: ptr Context, ctx: Ctx, path: Path) {.inline.} =
  if ctx.display and ctx.opacity > 0:
    let paint = newPaint(ctx.stroke)
    paint.color.a *= (ctx.opacity * ctx.strokeOpacity)
    prepare(c, path, paint, ctx.transform, false)
    c.setLineWidth(ctx.strokeWidth)
    c.setLineCap(ctx.strokeLineCap.cairoLineCap())
    c.setLineJoin(ctx.strokeLineJoin.cairoLineJoin())
    c.setMiterLimit(ctx.strokeMiterLimit)
    c.stroke()

proc drawInternal(img: ptr Context, node: XmlNode, ctxStack: var seq[Ctx]) =
  if node.kind != xnElement:
    # Skip <!-- comments -->
    return

  case node.tag:
  of "title", "desc", "defs":
    discard

  of "g":
    let ctx = decodeCtx(ctxStack[^1], node)
    ctxStack.add(ctx)
    for child in node:
      img.drawInternal(child, ctxStack)
    discard ctxStack.pop()

  of "path":
    let
      d = node.attr("d")
      ctx = decodeCtx(ctxStack[^1], node)
      path = parsePath(d)

    img.fill(ctx, path)
    if ctx.shouldStroke:
      img.stroke(ctx, path)

  of "line":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      x1 = parseFloat(node.attrOrDefault("x1", "0"))
      y1 = parseFloat(node.attrOrDefault("y1", "0"))
      x2 = parseFloat(node.attrOrDefault("x2", "0"))
      y2 = parseFloat(node.attrOrDefault("y2", "0"))

    let path = newPath()
    path.moveTo(x1, y1)
    path.lineTo(x2, y2)

    if ctx.shouldStroke:
      img.stroke(ctx, path)

  of "polyline", "polygon":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      points = node.attr("points")

    var vecs: seq[Vec2]
    if points.contains(","):
      for pair in points.split(" "):
        let parts = pair.split(",")
        if parts.len != 2:
          failInvalid()
        vecs.add(vec2(parseFloat(parts[0]), parseFloat(parts[1])))
    else:
      let points = points.split(" ")
      if points.len mod 2 != 0:
        failInvalid()
      for i in 0 ..< points.len div 2:
        vecs.add(vec2(parseFloat(points[i * 2]), parseFloat(points[i * 2 + 1])))

    if vecs.len == 0:
      failInvalid()

    let path = newPath()
    path.moveTo(vecs[0])
    for i in 1 ..< vecs.len:
      path.lineTo(vecs[i])

    # The difference between polyline and polygon is whether we close the path
    # and fill or not
    if node.tag == "polygon":
      path.closePath()
      img.fill(ctx, path)

    if ctx.shouldStroke:
      img.stroke(ctx, path)

  of "rect":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      x = parseFloat(node.attrOrDefault("x", "0"))
      y = parseFloat(node.attrOrDefault("y", "0"))
      width = parseFloat(node.attrOrDefault("width", "0"))
      height = parseFloat(node.attrOrDefault("height", "0"))

    if width == 0 or height == 0:
      return

    var
      rx = max(parseFloat(node.attrOrDefault("rx", "0")), 0)
      ry = max(parseFloat(node.attrOrDefault("ry", "0")), 0)

    let path = newPath()
    if rx > 0 or ry > 0:
      if rx == 0:
        rx = ry
      elif ry == 0:
        ry = rx
      rx = min(rx, width / 2)
      ry = min(ry, height / 2)

      path.moveTo(x + rx, y)
      path.lineTo(x + width - rx, y)
      path.ellipticalArcTo(rx, ry, 0, false, true, x + width, y + ry)
      path.lineTo(x + width, y + height - ry)
      path.ellipticalArcTo(rx, ry, 0, false, true, x + width - rx, y + height)
      path.lineTo(x + rx, y + height)
      path.ellipticalArcTo(rx, ry, 0, false, true, x, y + height - ry)
      path.lineTo(x, y + ry)
      path.ellipticalArcTo(rx, ry, 0, false, true, x + rx, y)
    else:
      path.rect(x, y, width, height)

    img.fill(ctx, path)
    if ctx.shouldStroke:
      img.stroke(ctx, path)

  of "circle", "ellipse":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      cx = parseFloat(node.attrOrDefault("cx", "0"))
      cy = parseFloat(node.attrOrDefault("cy", "0"))

    var rx, ry: float32
    if node.tag == "circle":
      rx = parseFloat(node.attr("r"))
      ry = rx
    else:
      rx = parseFloat(node.attrOrDefault("rx", "0"))
      ry = parseFloat(node.attrOrDefault("ry", "0"))

    let path = newPath()
    path.ellipse(cx, cy, rx, ry)

    img.fill(ctx, path)
    if ctx.shouldStroke:
      img.stroke(ctx, path)

  else:
    raise newException(PixieError, "Unsupported SVG tag: " & node.tag & ".")

proc draw(img: ptr Context, node: XmlNode, ctxStack: var seq[Ctx]) =
  try:
    drawInternal(img, node, ctxStack)
  except PixieError as e:
    raise e
  except:
    raise currentExceptionAsPixieError()

proc decodeSvg*(data: string, width = 0, height = 0): Image =
  ## Render SVG file and return the image. Defaults to the SVG's view box size.
  try:
    let root = parseXml(data)
    if root.tag != "svg":
      failInvalid()

    let
      viewBox = root.attr("viewBox")
      box = viewBox.split(" ")
      viewBoxMinX = parseInt(box[0])
      viewBoxMinY = parseInt(box[1])
      viewBoxWidth = parseInt(box[2])
      viewBoxHeight = parseInt(box[3])

    var rootCtx = initCtx()
    rootCtx = decodeCtx(rootCtx, root)

    if viewBoxMinX != 0 or viewBoxMinY != 0:
      rootCtx.transform = rootCtx.transform * translate(
        vec2(-viewBoxMinX.float32, -viewBoxMinY.float32)
      )

    var
      width = width
      height = height
      surface: ptr Surface
    if width == 0 and height == 0: # Default to the view box size
      width = viewBoxWidth.int32
      height = viewBoxHeight.int32
    else:
      let
        scaleX = width.float32 / viewBoxWidth.float32
        scaleY = height.float32 / viewBoxHeight.float32
      rootCtx.transform = rootCtx.transform * scale(vec2(scaleX, scaleY))

    surface = imageSurfaceCreate(FORMAT_ARGB32, width.int32, height.int32)

    let c = surface.create()

    var ctxStack = @[rootCtx]
    for node in root:
      c.draw(node, ctxStack)

    surface.flush()

    result = newImage(width, height)

    let pixels = cast[ptr UncheckedArray[array[4, uint8]]](surface.getData())
    for y in 0 ..< result.height:
      for x in 0 ..< result.width:
        let
          bgra = pixels[result.dataIndex(x, y)]
          rgba = rgba(bgra[2], bgra[1], bgra[0], bgra[3])
        result.unsafe[x, y] = rgba.rgbx()
  except PixieError as e:
    raise e
  except:
    raise newException(PixieError, "Unable to load SVG")
