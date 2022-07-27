import benchy, cairo, pixie, pixie/fileformats/svg {.all.}, pixie/paths {.all.}

type
  Fill = object
    shapes: seq[Polygon]
    transform: Mat3
    paint: Paint
    windingRule: WindingRule

  Benchmark = object
    name: string
    fills: seq[Fill]

var benchmarks: seq[Benchmark]

let
  opaque = newPaint(SolidPaint)
  notOpaque = newPaint(SolidPaint)
opaque.color = color(0, 0, 0, 1)
notOpaque.color = color(0, 0, 0, 0.5)

block: # Basic rect
  let path = newPath()
  path.rect(rect(50, 50, 800, 800))

  let shapes = path.commandsToShapes(true, 1)

  benchmarks.add(Benchmark(
    name: "rect opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: opaque,
    windingRule: NonZero
  )]))

  benchmarks.add(Benchmark(
    name: "rect not opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: notOpaque,
    windingRule: NonZero
  )]))

block: # Rounded rect
  let path = newPath()
  path.roundedRect(rect(0, 0, 900, 900), 100, 100, 100, 100)

  let shapes = path.commandsToShapes(true, 1)

  benchmarks.add(Benchmark(
    name: "roundedRect opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: opaque,
    windingRule: NonZero
    )]))

  benchmarks.add(Benchmark(
    name: "roundedRect not opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: notOpaque,
    windingRule: NonZero
    )]))

block: # Pentagon
  let path = newPath()
  path.polygon(vec2(450, 450), 400, 5)

  let shapes = path.commandsToShapes(true, 1)

  benchmarks.add(Benchmark(
    name: "pentagon opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: opaque,
    windingRule: NonZero
  )]))

  benchmarks.add(Benchmark(
    name: "pentagon not opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: notOpaque,
    windingRule: NonZero
  )]))

block: # Circle
  let path = newPath()
  path.circle(circle(vec2(450, 450), 400))

  let shapes = path.commandsToShapes(true, 1)

  benchmarks.add(Benchmark(
    name: "circle opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: opaque,
    windingRule: NonZero
  )]))

  benchmarks.add(Benchmark(
    name: "circle not opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: notOpaque,
    windingRule: NonZero
  )]))

block: # Heart
  let path = parsePath("""
      M 100,300
      A 200,200 0,0,1 500,300
      A 200,200 0,0,1 900,300
      Q 900,600 500,900
      Q 100,600 100,300 z
  """)

  let shapes = path.commandsToShapes(true, 1)

  benchmarks.add(Benchmark(
    name: "heart opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: opaque,
    windingRule: NonZero
  )]))

  benchmarks.add(Benchmark(
    name: "heart not opaque",
    fills: @[Fill(
    shapes: shapes,
    transform: mat3(),
    paint: notOpaque,
    windingRule: NonZero
  )]))

block: # Tiger
  let
    data = readFile("tests/fileformats/svg/Ghostscript_Tiger.svg")
    parsed = parseSvg(data)

  var fills: seq[Fill]

  for (path, props) in parsed.elements:
    if props.display and props.opacity > 0:
      if props.fill != "none":
        let
          shapes = path.commandsToShapes(true, 1)
          paint = parseSomePaint(props.fill)
        fills.add(Fill(
          shapes: shapes,
          transform: props.transform,
          paint: paint,
          windingRule: props.fillRule
        ))

      if props.stroke != rgbx(0, 0, 0, 0) and props.strokeWidth > 0:
        let strokeShapes = strokeShapes(
          parseSomePath(path, false, props.transform.pixelScale),
          props.strokeWidth,
          props.strokeLineCap,
          props.strokeLineJoin,
          props.strokeMiterLimit,
          props.strokeDashArray,
          props.transform.pixelScale
        )
        let paint = props.stroke.copy()
        paint.color.a *= (props.opacity * props.strokeOpacity)
        fills.add(Fill(
          shapes: strokeShapes,
          transform: props.transform,
          paint: paint,
          windingRule: NonZero
        ))

  benchmarks.add(Benchmark(
    name: "tiger",
    fills: fills
  ))

block:
  for benchmark in benchmarks:
    let
      surface = imageSurfaceCreate(FORMAT_ARGB32, 900, 900)
      ctx = surface.create()

    ctx.setLineWidth(1)

    timeIt "[cairo] " & benchmark.name:
      for fill in benchmark.fills:
        if fill.shapes.len > 0:
          ctx.newPath()
          for shape in fill.shapes:
            ctx.moveTo(shape[0].x, shape[0].y)
            for v in shape:
              ctx.lineTo(v.x, v.y)
          let
            color = fill.paint.color
            matrix = Matrix(
              xx: fill.transform[0, 0],
              yx: fill.transform[0, 1],
              xy: fill.transform[1, 0],
              yy: fill.transform[1, 1],
              x0: fill.transform[2, 0],
              y0: fill.transform[2, 1],
            )
          ctx.setSourceRgba(color.r, color.g, color.b, color.a)
          ctx.setMatrix(matrix.unsafeAddr)
          ctx.setFillRule(
            if fill.windingRule == NonZero:
              FillRuleWinding
            else:
              FillRuleEvenOdd
          )
          ctx.fill()
          # ctx.stroke()

    # discard surface.writeToPng(("cairo_" & benchmark.name & ".png").cstring)

block:
  for benchmark in benchmarks:
    let image = newImage(900, 900)

    timeIt "[pixie] " & benchmark.name:
      for fill in benchmark.fills:
        if fill.shapes.len > 0:
          let p = newPath()
          for shape in fill.shapes:
            p.moveTo(shape[0])
            for v in shape:
              p.lineTo(v)
          image.fillPath(
            p,
            fill.paint,
            fill.transform,
            fill.windingRule
          )
          # image.strokePath(
          #   p,
          #   fill.paint,
          #   fill.transform,
          #   1
          # )

    # image.writeFile("pixie_" & benchmark.name & ".png")
