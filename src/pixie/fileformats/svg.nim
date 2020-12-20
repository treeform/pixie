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
    if transform.startsWith("matrix("):
      let arr = transform[7..^2].split(",")
      if arr.len != 6:
        failInvalid()
      var m = mat3()
      m[0] = parseFloat(arr[0])
      m[1] = parseFloat(arr[1])
      m[3] = parseFloat(arr[2])
      m[4] = parseFloat(arr[3])
      m[6] = parseFloat(arr[4])
      m[7] = parseFloat(arr[5])
      result.transform = result.transform * m
    else:
      raise newException(
        PixieError, "Unsupported SVG transform: " & transform & "."
      )

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
    if ctx.stroke != ColorRGBA():
      let (bounds, strokeImg) = strokePathBounds(
        d, ctx.stroke, ctx.strokeWidth, ctx.transform
      )
      img.draw(strokeImg, bounds.xy)
  of "rect":
    let
      ctx = decodeCtx(ctxStack[^1], node)
      x = parseFloat(node.attr("x"))
      y = parseFloat(node.attr("y"))
      width = parseFloat(node.attr("width"))
      height = parseFloat(node.attr("height"))
      path = newPath()
    path.moveTo(x, y)
    path.lineTo(x + width, x)
    path.lineTo(x + width, y + height)
    path.lineTo(x, y + height)
    path.closePath()
    if ctx.fill != ColorRGBA():
      img.fillPath(path, ctx.fill, ctx.transform)
    if ctx.stroke != ColorRGBA():
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
    for node in root:
      result.draw(node, ctxStack)
  except PixieError as e:
    raise e
  except:
    raise newException(PixieError, "Unable to load SVG")
