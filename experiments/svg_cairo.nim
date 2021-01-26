## Load and Save SVG files.

import chroma, pixie/images, pixie/common, pixie/paths, vmath, xmlparser,
  xmltree, strutils, strutils, cairo

type Path = paths.Path

proc processCommands(c: ptr Context, path: paths.Path) =
  c.newPath()
  c.moveTo(0, 0)
  for i, command in path.commands:
    case command.kind
    of Move:
      c.moveTo(command.numbers[0], command.numbers[1])
    of Line:
      c.lineTo(command.numbers[0], command.numbers[1])
    of HLine:
      echo "HLine not yet supported for Cairo"
    of VLine:
      echo "VLine not yet supported for Cairo"
    of Cubic:
      c.curveTo(
        command.numbers[0],
        command.numbers[1],
        command.numbers[2],
        command.numbers[3],
        command.numbers[4],
        command.numbers[5]
      )
    of SCubic:
      echo "SCubic not yet supported for Cairo"
    of Quad:
      echo "Quad not supported by Cairo"
    of TQuad:
      echo "TQuad not supported by Cairo"
    of Arc:
      echo "Arc not yet supported for Cairo"
    of RMove:
      c.relMoveTo(command.numbers[0], command.numbers[1])
    of RLine:
      c.relLineTo(command.numbers[0], command.numbers[1])
    of RHLine:
      c.relLineTo(command.numbers[0], 0)
    of RVLine:
      c.relLineTo(0, command.numbers[0])
    of RCubic:
      c.relCurveTo(
        command.numbers[0],
        command.numbers[1],
        command.numbers[2],
        command.numbers[3],
        command.numbers[4],
        command.numbers[5]
      )
    of RSCubic:
      # This is not correct but good enough for now
      c.relLineTo(
        command.numbers[2],
        command.numbers[3]
      )
    of RQuad:
      echo "RQuad not supported by Cairo"
    of RTQuad:
      echo "RTQuad not supported by Cairo"
    of RArc:
      echo "RArc not yet supported for Cairo"
    of Close:
      c.closePath()

    checkStatus(c.status())

proc prepare(
  c: ptr Context,
  path: Path,
  color: ColorRGBA,
  mat: Mat3
) =
  let
    color = color.color()
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
  c.processCommands(path)

proc fillPath(
  c: ptr Context,
  path: Path,
  color: ColorRGBA,
  mat: Mat3
) =
  prepare(c, path, color, mat)
  c.fill()

proc strokePath(
  c: ptr Context,
  path: Path,
  color: ColorRGBA,
  strokeWidth: float32,
  mat: Mat3
) =
  prepare(c, path, color, mat)
  c.setLineWidth(strokeWidth)
  c.stroke()

const svgSignature* = "<?xml"

type Ctx = object
  fill, stroke: ColorRGBA
  strokeWidth: float32
  transform: Mat3

when defined(pixieTestCairo):
  type RenderTarget = ptr Context
else:
  type RenderTarget = Image

template failInvalid() =
  raise newException(PixieError, "Invalid SVG data")

proc initCtx(): Ctx =
  result.fill = parseHtmlColor("black").rgba.toPremultipliedAlpha()
  result.strokeWidth = 1
  result.transform = mat3()

proc decodeCtx(inherited: Ctx, node: XmlNode): Ctx =
  result = inherited

  let
    fill = node.attr("fill")
    stroke = node.attr("stroke")
    strokeWidth = node.attr("stroke-width")
    transform = node.attr("transform")

  if fill == "":
    discard # Inherit
  elif fill == "none":
    result.fill = ColorRGBA()
  else:
    result.fill = parseHtmlColor(fill).rgba.toPremultipliedAlpha()

  if stroke == "":
    discard # Inherit
  elif stroke == "none":
    result.stroke = ColorRGBA()
  else:
    result.stroke = parseHtmlColor(stroke).rgba.toPremultipliedAlpha()

  if strokeWidth == "":
    discard # Inherit
  else:
    result.strokeWidth = parseFloat(strokeWidth)

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
        let arr = f[7 .. ^2].split(",")
        if arr.len != 6:
          failInvalidTransform(transform)
        var m = mat3()
        m[0] = parseFloat(arr[0])
        m[1] = parseFloat(arr[1])
        m[3] = parseFloat(arr[2])
        m[4] = parseFloat(arr[3])
        m[6] = parseFloat(arr[4])
        m[7] = parseFloat(arr[5])
        result.transform = result.transform * m
      elif f.startsWith("translate("):
        let
          components = f[10 .. ^2].split(" ")
          tx = parseFloat(components[0])
          ty = parseFloat(components[1])
        result.transform = result.transform * translate(vec2(tx, ty))
      elif f.startsWith("rotate("):
        let angle = parseFloat(f[7 .. ^2]) * -PI / 180
        result.transform = result.transform * rotationMat3(angle)
      else:
        failInvalidTransform(transform)

proc draw(
  img: ptr Context, node: XmlNode, ctxStack: var seq[Ctx]
) =
  if node.kind != xnElement:
    # Skip <!-- comments -->
    return

  case node.tag:
  of "title", "desc":
    discard

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
    if ctx.fill != ColorRGBA():
      img.fillPath(path, ctx.fill, ctx.transform)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      img.strokePath(path, ctx.stroke, ctx.strokeWidth, ctx.transform)

  of "line":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      x1 = parseFloat(node.attr("x1"))
      y1 = parseFloat(node.attr("y1"))
      x2 = parseFloat(node.attr("x2"))
      y2 = parseFloat(node.attr("y2"))

    var path: Path
    path.moveTo(x1, y1)
    path.lineTo(x2, y2)
    path.closePath()

    if ctx.fill != ColorRGBA():
      img.fillPath(path, ctx.fill, ctx.transform)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      img.strokePath(path, ctx.stroke, ctx.strokeWidth, ctx.transform)

  of "polyline", "polygon":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      points = node.attr("points")

    var vecs: seq[Vec2]
    for pair in points.split(" "):
      let parts = pair.split(",")
      if parts.len != 2:
        failInvalid()
      vecs.add(vec2(parseFloat(parts[0]), parseFloat(parts[1])))

    if vecs.len == 0:
      failInvalid()

    var path: Path
    path.moveTo(vecs[0])
    for i in 1 ..< vecs.len:
      path.lineTo(vecs[i])

    # The difference between polyline and polygon is whether we close the path
    if node.tag == "polygon":
      path.closePath()

    if ctx.fill != ColorRGBA():
      img.fillPath(path, ctx.fill, ctx.transform)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      img.strokePath(path, ctx.stroke, ctx.strokeWidth, ctx.transform)

  of "rect":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      x = parseFloat(node.attr("x"))
      y = parseFloat(node.attr("y"))
      width = parseFloat(node.attr("width"))
      height = parseFloat(node.attr("height"))

    var path: Path
    path.rect(x, y, width, height)

    if ctx.fill != ColorRGBA():
      img.fillPath(path, ctx.fill, ctx.transform)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      img.strokePath(path, ctx.stroke, ctx.strokeWidth, ctx.transform)

  of "circle", "ellipse":
    # Reference for magic constant:
    # https://dl3.pushbulletusercontent.com/a3fLVC8boTzRoxevD1OgCzRzERB9z2EZ/unknown.png
    let ctx = decodeCtx(ctxStack[^1], node)

    var cx, cy: float32 # Default to 0.0 unless set by cx and cy on node
    if node.attr("cx") != "":
      cx = parseFloat(node.attr("cx"))
    if node.attr("cy") != "":
      cy = parseFloat(node.attr("cy"))

    var rx, ry: float32
    if node.tag == "circle":
      rx = parseFloat(node.attr("r"))
      ry = rx
    else:
      rx = parseFloat(node.attr("rx"))
      ry = parseFloat(node.attr("ry"))

    let
      magicX = (4.0 * (-1.0 + sqrt(2.0)) / 3) * rx
      magicY = (4.0 * (-1.0 + sqrt(2.0)) / 3) * ry

    var path: Path
    path.moveTo(cx + rx, cy)
    path.bezierCurveTo(cx + rx, cy + magicY, cx + magicX, cy + ry, cx, cy + ry)
    path.bezierCurveTo(cx - magicX, cy + ry, cx - rx, cy + magicY, cx - rx, cy)
    path.bezierCurveTo(cx - rx, cy - magicY, cx - magicX, cy - ry, cx, cy - ry)
    path.bezierCurveTo(cx + magicX, cy - ry, cx + rx, cy - magicY, cx + rx, cy)
    path.closePath()

    if ctx.fill != ColorRGBA():
      img.fillPath(path, ctx.fill, ctx.transform)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      img.strokePath(path, ctx.stroke, ctx.strokeWidth, ctx.transform)

  else:
    raise newException(PixieError, "Unsupported SVG tag: " & node.tag & ".")

proc decodeSvg*(data: string): Image =
  ## Render SVG file and return the image.
  try:
    let root = parseXml(data)
    if root.tag != "svg":
      failInvalid()

    let
      viewBox = root.attr("viewBox")
      box = viewBox.split(" ")
    if parseInt(box[0]) != 0 or parseInt(box[1]) != 0:
      failInvalid()

    let
      width = parseInt(box[2])
      height = parseInt(box[3])
    var ctxStack = @[initCtx()]
    result = newImage(width, height)
    let
      surface = imageSurfaceCreate(FORMAT_ARGB32, width.int32, height.int32)
      c = surface.create()
    for node in root:
      c.draw(node, ctxStack)
    surface.flush()
    let pixels = cast[ptr UncheckedArray[array[4, uint8]]](surface.getData())
    for y in 0 ..< result.height:
      for x in 0 ..< result.width:
        let
          bgra = pixels[result.dataIndex(x, y)]
          rgba = rgba(bgra[2], bgra[1], bgra[0], bgra[3])
        result.setRgbaUnsafe(x, y, rgba)
    result.toStraightAlpha()
  except PixieError as e:
    raise e
  except:
    raise newException(PixieError, "Unable to load SVG")
