import pixie, pixie/fileformats/svg, strformat, strutils, xrays, xmlparser,
    xmltree

const files = [
  "line01",
  "polyline01",
  "polygon01",
  "rect01",
  "rect02",
  "circle01",
  "ellipse01",
  "triangle01",
  "quad01",
  "Ghostscript_Tiger",
  "scale",
  "miterlimit",
  "dashes",
  "dragon2"
]

for file in files:
  let image = readImage(&"tests/fileformats/svg/{file}.svg")
  image.xray(&"tests/fileformats/svg/masters/{file}.png")

block:
  let
    svg = parseSvg(
      readFile("tests/fileformats/svg/accessibility-outline.svg"),
      512, 512
    )
    image = newImage(svg)
  image.xray(&"tests/fileformats/svg/masters/accessibility-outline.png")

block:
  # Test using XML node by itself, see: https://github.com/treeform/pixie/pull/533
  let
    xmlNode = parseXml(readFile("tests/fileformats/svg/accessibility-outline.svg"))
    svg = parseSvg(
      xmlNode,
      512, 512
    )

block:
  # parseSvg accepts an SVG with width/height but no viewBox
  let svg = parseSvg(
    """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48"></svg>"""
  )
  doAssert svg.width == 64
  doAssert svg.height == 48

block:
  # viewBox values may be comma-separated, decimal or carry a unit
  let svg = parseSvg(
    """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0,0 64.0,48px"></svg>"""
  )
  doAssert svg.width == 64
  doAssert svg.height == 48

block:
  # newSvg + addShape + toSvgString produces valid re-parseable SVG
  let
    svg = newSvg(100, 100)
    path = newPath()
  path.rect(10, 10, 80, 80)
  svg.addShape(path, "#ff0000")
  let svg2 = parseSvg(svg.toSvgString())
  doAssert svg2.width == 100
  doAssert svg2.height == 100

block:
  # fill-rule survives a round-trip
  let
    svg = newSvg(50, 50)
    path = newPath()
  path.rect(5, 5, 40, 40)
  svg.addShape(path, "#00ff00", fillRule = EvenOdd)
  let s = svg.toSvgString()
  doAssert "fill-rule=\"evenodd\"" in s
  doAssert parseSvg(s).toSvgString() == s

block:
  # toSvgString raises for gradient fills
  let svg = parseSvg("""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
    <linearGradient id="g" x1="0" y1="0" x2="10" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#000000"/>
      <stop offset="1" stop-color="#ffffff"/>
    </linearGradient>
    <rect x="0" y="0" width="10" height="10" fill="url(#g)"/>
  </svg>""")
  try:
    discard svg.toSvgString()
    doAssert false, "expected PixieError for gradient fill"
  except PixieError:
    discard
