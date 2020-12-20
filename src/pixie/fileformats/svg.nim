## Load and Save SVG files.

import chroma, pixie/images, pixie/common, pixie/paths, vmath, xmlparser,
  xmltree, strutils, strutils, bumpy

const svgSignature* = "<?xml"

type Ctx = object
  fill, stroke: ColorRGBA
  strokeWidth: float32
  transform: Mat3

template failInvalid() =
  raise newException(PixieError, "Invalid SVG data")

proc initCtx(): Ctx =
  result.fill = parseHtmlColor("black").rgba
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
    result.fill = parseHtmlColor(fill).rgba

  if stroke == "":
    discard # Inherit
  elif stroke == "none":
    result.stroke = ColorRGBA()
  else:
    result.stroke = parseHtmlColor(stroke).rgba

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
  img: Image, node: XmlNode, ctxStack: var seq[Ctx]
) =
  if node.kind != xnElement:
    # Skip <!-- comments -->
    return

  case node.tag:
  of "title":
    discard
  of "desc":
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
    if ctx.fill != ColorRGBA():
      let (bounds, fillImg) = fillPathBounds(d, ctx.fill, ctx.transform)
      img.draw(fillImg, bounds.xy)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      let (bounds, strokeImg) = strokePathBounds(
        d, ctx.stroke, ctx.strokeWidth, ctx.transform
      )
      img.draw(strokeImg, bounds.xy)

  of "line":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      x1 = parseFloat(node.attr("x1"))
      y1 = parseFloat(node.attr("y1"))
      x2 = parseFloat(node.attr("x2"))
      y2 = parseFloat(node.attr("y2"))

    let path = newPath()
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

    let path = newPath()
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

    let path = newPath()
    path.moveTo(x, y)
    path.lineTo(x + width, y)
    path.lineTo(x + width, y + height)
    path.lineTo(x, y + height)
    path.closePath()

    if ctx.fill != ColorRGBA():
      img.fillPath(path, ctx.fill, ctx.transform)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      img.strokePath(path, ctx.stroke, ctx.strokeWidth, ctx.transform)

  of "circle":
    # Reference for magic constant:
    # https://dl3.pushbulletusercontent.com/a3fLVC8boTzRoxevD1OgCzRzERB9z2EZ/unknown.png
    let
      ctx = decodeCtx(ctxStack[^1], node)
      cx = parseFloat(node.attr("cx"))
      cy = parseFloat(node.attr("cy"))
      r = parseFloat(node.attr("r"))
      magic = (4.0 * (-1.0 + sqrt(2.0)) / 3) * r

    let path = newPath()
    path.moveTo(cx + r, cy)
    path.bezierCurveTo(cx + r, cy + magic, cx + magic, cy + r, cx, cy + r)
    path.bezierCurveTo(cx - magic, cy + r, cx - r, cy + magic, cx - r, cy)
    path.bezierCurveTo(cx - r, cy - magic, cx - magic, cy - r, cx, cy - r)
    path.bezierCurveTo(cx + magic, cy - r, cx + r, cy - magic, cx + r, cy)
    path.closePath()

    let d = $path
    if ctx.fill != ColorRGBA():
      let (bounds, fillImg) = fillPathBounds(d, ctx.fill, ctx.transform)
      img.draw(fillImg, bounds.xy)
    if ctx.stroke != ColorRGBA() and ctx.strokeWidth > 0:
      let (bounds, strokeImg) = strokePathBounds(
        d, ctx.stroke, ctx.strokeWidth, ctx.transform
      )
      img.draw(strokeImg, bounds.xy)

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
    for node in root:
      result.draw(node, ctxStack)
  except PixieError as e:
    raise e
  except:
    raise newException(PixieError, "Unable to load SVG")
