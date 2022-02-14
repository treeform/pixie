import benchy, cairo, pixie, pixie/blends, pixie/internal

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

when defined(release):
  {.push checks: off.}

proc drawBasic(backdrop, source: Image) =
  for y in 0 ..< min(backdrop.height, source.height):
    if isOpaque(source.data, source.dataIndex(0, y), source.width):
      copyMem(
        backdrop.data[backdrop.dataIndex(0, y)].addr,
        source.data[source.dataIndex(0, y)].addr,
        min(backdrop.width, source.width) * 4
      )
    else:
      var x: int
      when defined(amd64) and not defined(pixieNoSimd):
        let vec255 = mm_set1_epi32(cast[int32](uint32.high))
        for _ in 0 ..< min(backdrop.width, source.width) div 4:
          let sourceVec = mm_loadu_si128(source.data[source.dataIndex(x, y)].addr)
          if mm_movemask_epi8(mm_cmpeq_epi8(sourceVec, mm_setzero_si128())) != 0xffff:
            if (mm_movemask_epi8(mm_cmpeq_epi8(sourceVec, vec255)) and 0x8888) == 0x8888:
              mm_storeu_si128(backdrop.data[backdrop.dataIndex(x, y)].addr, sourceVec)
            else:
              let backdropVec = mm_loadu_si128(backdrop.data[backdrop.dataIndex(x, y)].addr)
              mm_storeu_si128(
                backdrop.data[backdrop.dataIndex(x, y)].addr,
                blendNormalInlineSimd(backdropVec, sourceVec)
              )
          x += 4
      # No scalar for now

when defined(release):
  {.pop.}

block:
  let
    backdrop = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/dragon2.png")
    source = imageSurfaceCreateFromPng("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = imageSurfaceCreate(FORMAT_ARGB32, 1568, 940)
    ctx = tmp.create()

  timeIt "cairo draw normal":
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

  timeIt "pixie draw normal":
    # tmp.fill(rgbx(127, 127, 127, 255))
    tmp.draw(backdrop)
    tmp.draw(source)

  # tmp.writeFile("tmp2.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw overwrite":
    # tmp.fill(rgbx(127, 127, 127, 255))
    tmp.draw(backdrop, blendMode = OverwriteBlend)
    tmp.draw(source)

  # tmp.writeFile("tmp2.png")

block:
  let
    backdrop = readImage("tests/fileformats/svg/masters/dragon2.png")
    source = readImage("tests/fileformats/svg/masters/Ghostscript_Tiger.png")
    tmp = newImage(1568, 940)

  timeIt "pixie draw basic":
    # tmp.fill(rgbx(127, 127, 127, 255))
    tmp.drawBasic(backdrop)
    tmp.drawBasic(source)

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

  # echo tmp.writeToPng("tmp_masked.png")

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
