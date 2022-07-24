## Load SVG files.

import chroma, pixie/common, pixie/images, pixie/internal, pixie/paints,
    pixie/paths, strutils, tables, vmath, xmlparser, xmltree

when defined(pixieDebugSvg):
  import strtabs

const
  xmlSignature* = "<?xml"
  svgSignature* = "<svg"

type
  Svg* = ref object
    width*, height*: int
    elements: seq[(Path, SvgProperties)]
    linearGradients: Table[string, LinearGradient]

  SvgProperties = object
    display: bool
    fillRule: WindingRule
    fill: string
    stroke: ColorRGBX
    strokeWidth: float32
    strokeLineCap: LineCap
    strokeLineJoin: LineJoin
    strokeMiterLimit: float32
    strokeDashArray: seq[float32]
    transform: Mat3
    opacity, fillOpacity, strokeOpacity: float32

  LinearGradient = object
    x1, y1, x2, y2: float32
    stops: seq[ColorStop]

template failInvalid() =
  raise newException(PixieError, "Invalid SVG data")

proc attrOrDefault(node: XmlNode, name, default: string): string =
  result = node.attr(name)
  if result.len == 0:
    result = default

proc initSvgProperties(): SvgProperties =
  result.display = true
  result.fill = "black"
  result.strokeWidth = 1
  result.transform = mat3()
  result.strokeMiterLimit = defaultMiterLimit
  result.opacity = 1
  result.fillOpacity = 1
  result.strokeOpacity = 1

proc parseSvgProperties(node: XmlNode, inherited: SvgProperties): SvgProperties =
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

  when defined(pixieDebugSvg):
    proc maybeLogPair(k, v: string) =
      if k notin [
          "fill-rule", "fill", "stroke", "stroke-width", "stroke-linecap",
          "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
          "transform", "style", "version", "viewBox", "width", "height",
          "xmlns", "x", "y", "x1", "x2", "y1", "y2", "id", "d", "cx", "cy",
          "r", "points", "rx", "ry", "enable-background", "xml:space",
          "xmlns:xlink", "data-name", "role", "class", "opacity",
          "fill-opacity", "stroke-opacity"
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
        when defined(pixieDebugSvg):
          maybeLogPair(parts[0], parts[1])
    elif pair.len > 0:
      when defined(pixieDebugSvg):
        echo "Invalid style pair: ", pair

  if display.len > 0:
    result.display = display.strip() != "none"

  if opacity.len > 0:
    result.opacity = clamp(parseFloat(opacity), 0, 1)

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
    result.fill = inherited.fill
  else:
    result.fill = fill

  if stroke == "":
    discard # Inherit
  elif stroke == "currentColor":
    if result.stroke == rgbx(0, 0, 0, 0):
      result.stroke = rgbx(0, 0, 0, 255)
  elif stroke == "none":
    result.stroke = ColorRGBX()
  else:
    result.stroke = parseHtmlColor(stroke).rgbx

  if fillOpacity.len > 0:
    result.fillOpacity = parseFloat(fillOpacity).clamp(0, 1)

  if strokeOpacity.len > 0:
    result.strokeOpacity = parseFloat(strokeOpacity).clamp(0, 1)

  if strokeWidth == "":
    discard # Inherit
  else:
    if strokeWidth.endsWith("px"):
      strokeWidth = strokeWidth[0 .. ^3]
    result.strokeWidth = parseFloat(strokeWidth)
    if result.stroke == rgbx(0, 0, 0, 0):
      result.stroke = rgbx(0, 0, 0, 255)

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

proc parseSvgElement(
  node: XmlNode, svg: Svg, propertiesStack: var seq[SvgProperties]
): seq[(Path, SvgProperties)] =
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
    let props = node.parseSvgProperties(propertiesStack[^1])
    propertiesStack.add(props)
    for child in node:
      result.add child.parseSvgElement(svg, propertiesStack)
    discard propertiesStack.pop()

  of "path":
    let
      d = node.attr("d")
      props = node.parseSvgProperties(propertiesStack[^1])
      path = parsePath(d)

    result.add (path, props)

  of "line":
    let
      props = node.parseSvgProperties(propertiesStack[^1])
      x1 = parseFloat(node.attrOrDefault("x1", "0"))
      y1 = parseFloat(node.attrOrDefault("y1", "0"))
      x2 = parseFloat(node.attrOrDefault("x2", "0"))
      y2 = parseFloat(node.attrOrDefault("y2", "0"))

    let path = newPath()
    path.moveTo(x1, y1)
    path.lineTo(x2, y2)

    result.add (path, props)

  of "polyline", "polygon":
    let
      props = node.parseSvgProperties(propertiesStack[^1])
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

    result.add (path, props)

  of "rect":
    let
      props = node.parseSvgProperties(propertiesStack[^1])
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

    result.add (path, props)

  of "circle", "ellipse":
    let
      props = node.parseSvgProperties(propertiesStack[^1])
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

    result.add (path, props)

  of "radialGradient":
    discard

  of "linearGradient":
    let
      props = node.parseSvgProperties(propertiesStack[^1])
      id = node.attr("id")
      gradientUnits = node.attr("gradientUnits")
      gradientTransform = node.attr("gradientTransform")

    if gradientUnits != "userSpaceOnUse":
      raise newException(
        PixieError, "Unsupported gradient units: " & gradientUnits
      )
    if gradientTransform != "":
      raise newException(
        PixieError, "Unsupported gradient transform: " & gradientTransform
      )

    var linearGradient: LinearGradient
    linearGradient.x1 = parseFloat(node.attr("x1"))
    linearGradient.y1 = parseFloat(node.attr("y1"))
    linearGradient.x2 = parseFloat(node.attr("x2"))
    linearGradient.y2 = parseFloat(node.attr("y2"))

    for child in node:
      if child.tag == "stop":
        var color = child.attr("stop-color")

        if color == "":
          let
            style = child.attr("style")
            pairs = style.split(';')
          for pair in pairs:
            let parts = pair.split(':')
            if parts.len == 2:
              # Do not override element properties
              case parts[0].strip():
              of "stop-color":
                if color == "":
                  color = parts[1].strip()
              else:
                when defined(pixieDebugSvg):
                  maybeLogPair(parts[0], parts[1])
            elif pair.len > 0:
              when defined(pixieDebugSvg):
                echo "Invalid style pair: ", pair

        if color == "":
          raise newException(
            PixieError, "Invalid SVG gradient, missing stop-color"
          )

        linearGradient.stops.add(ColorStop(
          color: color.parseHtmlColor(),
          position: parseFloat(child.attr("offset"))
        ))
      else:
        raise newException(PixieError, "Unexpected SVG tag: " & child.tag)

    svg.linearGradients[id] = linearGradient

  else:
    raise newException(PixieError, "Unsupported SVG tag: " & node.tag)

proc parseSvg*(
  data: string | XmlNode, width = 0, height = 0
): Svg {.raises: [PixieError].} =
  ## Parse SVG XML. Defaults to the SVG's view box size.
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

    var rootProps = initSvgProperties()
    rootProps = root.parseSvgProperties(rootProps)

    if viewBoxMinX != 0 or viewBoxMinY != 0:
      let viewBoxMin = vec2(-viewBoxMinX.float32, -viewBoxMinY.float32)
      rootprops.transform = rootprops.transform * translate(viewBoxMin)

    result = Svg()

    if width == 0 and height == 0: # Default to the view box size
      result.width = viewBoxWidth
      result.height = viewBoxHeight
    else:
      result.width = width
      result.height = height

      let
        scaleX = width.float32 / viewBoxWidth.float32
        scaleY = height.float32 / viewBoxHeight.float32
      rootprops.transform = rootprops.transform * scale(vec2(scaleX, scaleY))

    var propertiesStack = @[rootProps]
    for node in root.items:
      result.elements.add node.parseSvgElement(result, propertiesStack)
  except PixieError as e:
    raise e
  except:
    raise currentExceptionAsPixieError()

proc newImage*(svg: Svg): Image {.raises: [PixieError].} =
  ## Render SVG and return the image.
  result = newImage(svg.width, svg.height)

  try:
    var blendMode = OverwriteBlend # Start as overwrite
    for (path, props) in svg.elements:
      if props.display and props.opacity > 0:
        if props.fill != "none":
          var paint: Paint
          if props.fill.startsWith("url("):
            let closingParen = props.fill.find(")", 5)
            if closingParen == -1:
              raise newException(PixieError, "Malformed fill: " & props.fill)
            let id = props.fill[5 .. closingParen - 1]
            if id in svg.linearGradients:
              let linearGradient = svg.linearGradients[id]
              paint = newPaint(LinearGradientPaint)
              paint.gradientHandlePositions = @[
                props.transform * vec2(linearGradient.x1, linearGradient.y1),
                props.transform * vec2(linearGradient.x2, linearGradient.y2)
              ]
              paint.gradientStops = linearGradient.stops
            else:
              raise newException(PixieError, "Missing SVG resource " & id)
          else:
            paint = parseHtmlColor(props.fill).rgbx

          paint.opacity = props.fillOpacity * props.opacity
          paint.blendMode = blendMode

          result.fillPath(path, paint, props.transform, props.fillRule)

        blendMode = NormalBlend # Switch to normal when compositing multiple paths

        if props.stroke != rgbx(0, 0, 0, 0) and props.strokeWidth > 0:
          let paint = props.stroke.copy()
          paint.color.a *= (props.opacity * props.strokeOpacity)
          result.strokePath(
            path,
            paint,
            props.transform,
            props.strokeWidth,
            props.strokeLineCap,
            props.strokeLineJoin,
            miterLimit = props.strokeMiterLimit,
            dashes = props.strokeDashArray
          )
  except PixieError as e:
    raise e
  except:
    raise currentExceptionAsPixieError()
