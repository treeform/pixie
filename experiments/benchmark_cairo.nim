import benchy, cairo, chroma, math, pixie, pixie/paths {.all.}, strformat

proc doDiff(a, b: Image, name: string) =
  let (diffScore, diffImage) = diff(a, b)
  echo &"{name} score: {diffScore}"
  diffImage.writeFile(&"{name}_diff.png")

block:
  let path = newPath()
  path.moveTo(0, 0)
  path.lineTo(1920, 0)
  path.lineTo(1920, 1080)
  path.lineTo(0, 1080)
  path.closePath()

  let shapes = path.commandsToShapes(true, 1)

  let
    surface = imageSurfaceCreate(FORMAT_ARGB32, 1920, 1080)
    ctx = surface.create()
  ctx.setSourceRgba(0, 0, 1, 1)

  timeIt "cairo1":
    ctx.newPath()
    ctx.moveTo(shapes[0][0].x, shapes[0][0].y)
    for shape in shapes:
      for v in shape:
        ctx.lineTo(v.x, v.y)
    ctx.fill()
    surface.flush()

  # discard surface.writeToPng("cairo1.png")

  let a = newImage(1920, 1080)

  timeIt "pixie1":
    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    a.fillPath(p, rgba(0, 0, 255, 255))

  # a.writeFile("pixie1.png")

block:
  let path = newPath()
  path.moveTo(500, 240)
  path.lineTo(1500, 240)
  path.lineTo(1920, 600)
  path.lineTo(0, 600)
  path.closePath()

  let shapes = path.commandsToShapes(true, 1)

  let
    surface = imageSurfaceCreate(FORMAT_ARGB32, 1920, 1080)
    ctx = surface.create()

  timeIt "cairo2":
    ctx.setSourceRgba(1, 1, 1, 1)
    let operator = ctx.getOperator()
    ctx.setOperator(OperatorSource)
    ctx.paint()
    ctx.setOperator(operator)

    ctx.setSourceRgba(0, 0, 1, 1)

    ctx.newPath()
    ctx.moveTo(shapes[0][0].x, shapes[0][0].y)
    for shape in shapes:
      for v in shape:
        ctx.lineTo(v.x, v.y)
    ctx.fill()
    surface.flush()

  # discard surface.writeToPng("cairo2.png")

  let a = newImage(1920, 1080)

  timeIt "pixie2":
    a.fill(rgba(255, 255, 255, 255))

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    a.fillPath(p, rgba(0, 0, 255, 255))

  # a.writeFile("pixie2.png")

block:
  let path = parsePath("""
      M 100,300
      A 200,200 0,0,1 500,300
      A 200,200 0,0,1 900,300
      Q 900,600 500,900
      Q 100,600 100,300 z
  """)

  let shapes = path.commandsToShapes(true, 1)

  let
    surface = imageSurfaceCreate(FORMAT_ARGB32, 1000, 1000)
    ctx = surface.create()

  timeIt "cairo3":
    ctx.setSourceRgba(1, 1, 1, 1)
    let operator = ctx.getOperator()
    ctx.setOperator(OperatorSource)
    ctx.paint()
    ctx.setOperator(operator)

    ctx.setSourceRgba(1, 0, 0, 1)

    ctx.newPath()
    ctx.moveTo(shapes[0][0].x, shapes[0][0].y)
    for shape in shapes:
      for v in shape:
        ctx.lineTo(v.x, v.y)
    ctx.fill()
    surface.flush()

  # discard surface.writeToPng("cairo3.png")

  let a = newImage(1000, 1000)

  timeIt "pixie3":
    a.fill(rgba(255, 255, 255, 255))

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    a.fillPath(p, rgba(255, 0, 0, 255))

  # a.writeFile("pixie3.png")

  # doDiff(readImage("cairo3.png"), a, "cairo3")

block:
  let path = newPath()
  path.roundedRect(200, 200, 600, 600, 10, 10, 10, 10)

  let shapes = path.commandsToShapes(true, 1)

  let
    surface = imageSurfaceCreate(FORMAT_ARGB32, 1000, 1000)
    ctx = surface.create()

  timeIt "cairo4":
    ctx.setSourceRgba(0, 0, 0, 0)
    let operator = ctx.getOperator()
    ctx.setOperator(OperatorSource)
    ctx.paint()
    ctx.setOperator(operator)

  # timeIt "cairo4":
  #   let
  #     surface = imageSurfaceCreate(FORMAT_ARGB32, 1000, 1000)
  #     ctx = surface.create()

    ctx.setSourceRgba(1, 0, 0, 0.5)

    ctx.newPath()
    ctx.moveTo(shapes[0][0].x, shapes[0][0].y)
    for shape in shapes:
      for v in shape:
        ctx.lineTo(v.x, v.y)
    ctx.fill()
    surface.flush()

  # discard surface.writeToPng("cairo4.png")

  var a: Image
  a = newImage(1000, 1000)
  timeIt "pixie4":
    # a = newImage(1000, 1000)

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    a.fillPath(p, rgba(255, 0, 0, 127))

  # a.writeFile("pixie4.png")

  # doDiff(readImage("cairo4.png"), a, "4")

  timeIt "pixie4 mask":
    let mask = newMask(1000, 1000)

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    mask.fillPath(p)

  var tmp: Image
  timeIt "pixie fillImage":
    tmp = path.fillImage(1000, 1000, rgba(255, 0, 0, 127))

  # tmp.writeFile("tmp.png")
