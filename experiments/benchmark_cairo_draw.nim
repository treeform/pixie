import benchy, cairo, pixie

block:
  let
    backdrop = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/dragon2.png")
    source = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = imageSurfaceCreate(FORMAT_ARGB32, 1568, 940)
    ctx = tmp.create()

  timeIt "cairo draw basic":
    # ctx.setSourceRgba(0.5, 0.5, 0.5, 1)
    # let operator = ctx.getOperator()
    # ctx.setOperator(OperatorSource)
    # ctx.paint()
    # ctx.setOperator(operator)

    ctx.setSource(backdrop, 0, 0)
    ctx.paint()
    ctx.setSource(source, 0, 0)
    ctx.paint()
    tmp.flush()

  # echo tmp.writeToPng("tmp.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw basic":
    # tmp.fill(rgbx(127, 127, 127, 255))
    tmp.draw(backdrop)
    tmp.draw(source)

  # tmp.writeFile("tmp2.png")

block:
  let
    backdrop = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/dragon2.png")
    source = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = imageSurfaceCreate(FORMAT_ARGB32, 1568, 940)
    ctx = tmp.create()

  timeIt "cairo draw mask":
    ctx.setSourceRgba(1, 1, 1, 1)
    let operator = ctx.getOperator()
    ctx.setOperator(OperatorSource)
    ctx.paint()
    ctx.setOperator(operator)

    ctx.setSource(backdrop, 0, 0)
    ctx.mask(source, 0, 0)
    tmp.flush()

  echo tmp.writeToPng("tmp_masked.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw mask":
    tmp.draw(backdrop)
    tmp.draw(source, blendMode = bmMask)

  tmp.writeFile("tmp_masked2.png")

block:
  let
    backdrop = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/dragon2.png")
    source = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = imageSurfaceCreate(FORMAT_ARGB32, 1568, 940)
    ctx = tmp.create()

  timeIt "cairo draw smooth":
    var
      mat = mat3()
      matrix = cairo.Matrix(
        xx: mat[0, 0],
        yx: mat[0, 1],
        xy: mat[1, 0],
        yy: mat[1, 1],
        x0: mat[2, 0],
        y0: mat[2, 1],
      )
    ctx.setMatrix(matrix.unsafeAddr)
    ctx.setSource(backdrop, 0, 0)
    ctx.paint()
    mat = translate(vec2(0.5, 0.5))
    matrix = cairo.Matrix(
      xx: mat[0, 0],
      yx: mat[0, 1],
      xy: mat[1, 0],
      yy: mat[1, 1],
      x0: mat[2, 0],
      y0: mat[2, 1],
    )
    ctx.setMatrix(matrix.unsafeAddr)
    ctx.setSource(source, 0, 0)
    ctx.paint()
    tmp.flush()

  # echo tmp.writeToPng("tmp.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw smooth":
    tmp.draw(backdrop)
    tmp.draw(source, translate(vec2(0.5, 0.5)))

  # tmp.writeFile("tmp2.png")

block:
  let
    backdrop = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/dragon2.png")
    source = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = imageSurfaceCreate(FORMAT_ARGB32, 1568, 940)
    ctx = tmp.create()

  timeIt "cairo draw smooth rotated":
    var
      mat = mat3()
      matrix = cairo.Matrix(
        xx: mat[0, 0],
        yx: mat[0, 1],
        xy: mat[1, 0],
        yy: mat[1, 1],
        x0: mat[2, 0],
        y0: mat[2, 1],
      )
    ctx.setMatrix(matrix.unsafeAddr)
    ctx.setSource(backdrop, 0, 0)
    ctx.paint()
    mat = rotate(15.toRadians)
    matrix = cairo.Matrix(
      xx: mat[0, 0],
      yx: mat[0, 1],
      xy: mat[1, 0],
      yy: mat[1, 1],
      x0: mat[2, 0],
      y0: mat[2, 1],
    )
    ctx.setMatrix(matrix.unsafeAddr)
    ctx.setSource(source, 0, 0)
    ctx.paint()
    tmp.flush()

  # echo tmp.writeToPng("tmp.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw smooth rotated":
    tmp.draw(backdrop)
    tmp.draw(source, rotate(15.toRadians))

  # tmp.writeFile("tmp2.png")
