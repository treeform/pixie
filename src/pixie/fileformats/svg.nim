## Load and Save SVG files.

import chroma, pixie/images, pixie/common, pixie/paths, vmath, xmlparser, xmltree,
  strutils, strutils, bumpy

const svgSignature* = "<?xml"

template failInvalid() =
  raise newException(PixieError, "Invalid SVG data")

proc draw(img: Image, matStack: var seq[Mat3], xml: XmlNode) =
  if xml.tag != "g":
    raise newException(PixieError, "Unsupported SVG tag: " & xml.tag & ".")

  let
    fill = xml.attr("fill")
    stroke = xml.attr("stroke")
    strokeWidth = xml.attr("stroke-width")
    transform = xml.attr("transform")

  if transform != "":
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
      matStack.add(matStack[^1] * m)
    else:
      raise newException(
        PixieError, "Unsupported SVG transform: " & transform & ".")

  for child in xml:
    if child.tag == "path":
      let d = child.attr("d")

      if fill != "none" and fill != "":
        let
          fillColor = parseHtmlColor(fill).rgba
          (bounds, fillImg) = fillPathBounds(d, fillColor, matStack[^1])
        img.draw(fillImg, bounds.xy)

      if stroke != "none" and stroke != "":
        let
          strokeColor = parseHtmlColor(stroke).rgba
          strokeWidth =
            if strokeWidth == "": 1.0 # Default stroke width is 1px
            else: parseFloat(strokeWidth)
          (bounds, strokeImg) =
            strokePathBounds(d, strokeColor, strokeWidth, matStack[^1])
        img.draw(strokeImg, bounds.xy)
    else:
      img.draw(matStack, child)

  if transform != "":
    discard matStack.pop()

proc decodeSvg*(data: string): Image =
  ## Render SVG file and return the image.
  try:
    let xml = parseXml(data)
    if xml.tag != "svg":
      failInvalid()

    let
      viewBox = xml.attr("viewBox")
      box = viewBox.split(" ")
    if parseInt(box[0]) != 0 or parseInt(box[1]) != 0:
      failInvalid()

    let
      width = parseInt(box[2])
      height = parseInt(box[3])
    result = newImage(width, height)
    var matStack = @[mat3()]
    for n in xml:
      result.draw(matStack, n)
  except PixieError as e:
    raise e
  except:
     raise newException(PixieError, "Unable to load SVG")
