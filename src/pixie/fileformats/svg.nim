## Load SVG files.

import chroma, pixie/common, pixie/images, pixie/paints, pixie/paths, strutils,
    vmath, xmlparser, xmltree

const
  xmlSignature* = "<?xml"
  svgSignature* = "<svg"

type Ctx = object
  display: bool
  fillRule: WindingRule
  fill, stroke: ColorRGBX
  strokeWidth: float32
  strokeLineCap: LineCap
  strokeLineJoin: LineJoin
  strokeMiterLimit: float32
  strokeDashArray: seq[float32]
  transform: Mat3
  shouldStroke: bool

template failInvalid() =
  raise newException(PixieError, "Invalid SVG data")

proc attrOrDefault(node: XmlNode, name, default: string): string =
  result = node.attr(name)
  if result.len == 0:
    result = default

proc initCtx(): Ctx =
  result.display = true
  result.fill = parseHtmlColor("black").rgbx
  result.stroke = parseHtmlColor("black").rgbx
  result.strokeWidth = 1
  result.transform = mat3()
  result.strokeMiterLimit = defaultMiterLimit

proc decodeCtx(inherited: Ctx, node: XmlNode): Ctx =
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

  when defined(pixieDebugSvg):
    proc maybeLogPair(k, v: string) =
      if k notin [
          "fill-rule", "fill", "stroke", "stroke-width", "stroke-linecap",
          "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
          "transform", "style", "version", "viewBox", "width", "height",
          "xmlns", "x", "y", "x1", "x2", "y1", "y2", "id", "d", "cx", "cy",
          "r", "points", "rx", "ry", "enable-background", "xml:space",
          "xmlns:xlink", "data-name", "role", "class"
        ]:
          echo k, ": ", v

    if node.attrs() != nil:
      for k, v in node.attrs():
        maybeLogPair(k, v)

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
      else:
        when defined(pixieDebugSvg):
          maybeLogPair(parts[0], parts[1])
    elif pair.len > 0:
      when defined(pixieDebugSvg):
        echo "Invalid style pair: ", pair

  if display.len > 0:
    result.display = display.strip() != "none"

  if fillRule == "":
    discard # Inherit
  elif fillRule == "nonzero":
    result.fillRule = wrNonZero
  elif fillRule == "evenodd":
    result.fillRule = wrEvenOdd
  else:
    raise newException(
      PixieError, "Invalid fill-rule value " & fillRule
    )

  if fill == "" or fill == "currentColor":
    discard # Inherit
  elif fill == "none":
    result.fill = ColorRGBX()
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
      result.strokeLineCap = lcButt
    of "round":
      result.strokeLineCap = lcRound
    of "square":
      result.strokeLineCap = lcSquare
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
      result.strokeLineJoin = ljMiter
    of "round":
      result.strokeLineJoin = ljRound
    of "bevel":
      result.strokeLineJoin = ljBevel
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
          PixieError, "Unsupported SVG transform: " & transform & "."
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

proc fill(img: Image, ctx: Ctx, path: Path) {.inline.} =
  if ctx.display:
    img.fillPath(path, ctx.fill, ctx.transform, ctx.fillRule)

proc stroke(img: Image, ctx: Ctx, path: Path) {.inline.} =
  if ctx.display:
    img.strokePath(
      path,
      ctx.stroke,
      ctx.transform,
      ctx.strokeWidth,
      ctx.strokeLineCap,
      ctx.strokeLineJoin,
      miterLimit = ctx.strokeMiterLimit,
      dashes = ctx.strokeDashArray
    )

proc draw(img: Image, node: XmlNode, ctxStack: var seq[Ctx]) =
  if node.kind != xnElement:
    # Skip <!-- comments -->
    return

  case node.tag:
  of "title", "desc":
    discard

  of "defs":
    when defined(pixieDebugSvg):
      echo node

  of "g":
    let ctx = decodeCtx(ctxStack[^1], node)
    ctxStack.add(ctx)
    for child in node:
      img.draw(child, ctxStack)
    discard ctxStack.pop()

  of "path":
    let
      d = node.attr("d")
      ctx = decodeCtx(ctxStack[^1], node)
      path = parsePath(d)
    if ctx.fill != ColorRGBX():
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

    var path: Path
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
      for i in countup(0, points.len - 2, 2):
        vecs.add(vec2(parseFloat(points[i]), parseFloat(points[i + 1])))

    if vecs.len == 0:
      failInvalid()

    var path: Path
    path.moveTo(vecs[0])
    for i in 1 ..< vecs.len:
      path.lineTo(vecs[i])

    # The difference between polyline and polygon is whether we close the path
    # and fill or not
    if node.tag == "polygon":
      path.closePath()

      if ctx.fill != ColorRGBX():
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

    var path: Path
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

    if ctx.fill != ColorRGBX():
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

    var path: Path
    path.ellipse(cx, cy, rx, ry)

    if ctx.fill != ColorRGBX():
      img.fill(ctx, path)
    if ctx.shouldStroke:
      img.stroke(ctx, path)

  else:
    raise newException(PixieError, "Unsupported SVG tag: " & node.tag & ".")

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

    if width == 0 and height == 0: # Default to the view box size
      result = newImage(viewBoxWidth, viewBoxHeight)
    else:
      result = newImage(width, height)

      let
        scaleX = width.float32 / viewBoxWidth.float32
        scaleY = height.float32 / viewBoxHeight.float32
      rootCtx.transform = rootCtx.transform * scale(vec2(scaleX, scaleY))

    var ctxStack = @[rootCtx]
    for node in root:
      result.draw(node, ctxStack)
  except PixieError as e:
    raise e
  except:
    raise newException(PixieError, "Unable to load SVG")
