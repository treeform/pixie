import benchy, cairo, pixie

block:
  let
    backdrop = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/dragon2.png")
    source = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = imageSurfaceCreate(FORMAT_ARGB32, 1568, 940)
    ctx = tmp.create()

  timeIt "cairo draw normal":
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

  timeIt "pixie draw normal":
    tmp.draw(backdrop)
    tmp.draw(source)

  # tmp.writeFile("tmp2.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw overwrite":
    tmp.draw(backdrop, blendMode = OverwriteBlend)
    tmp.draw(source)

  # tmp.writeFile("tmp2.png")

block:
  let
    backdrop = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/dragon2.png")
    source = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = imageSurfaceCreate(FORMAT_ARGB32, 1568, 940)
    ctx = tmp.create()

  timeIt "cairo draw mask":
    ctx.setSource(backdrop, 0, 0)
    ctx.mask(source, 0, 0)
    tmp.flush()

  # tmp.writeToPng("tmp_masked.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw mask":
    tmp.draw(backdrop)
    tmp.draw(source, blendMode = MaskBlend)

  # tmp.writeFile("tmp_masked2.png")

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
