import benchy, cairo, chroma, math, pixie, pixie/paths {.all.}, strformat

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2, pixie/internal

proc doDiff(a, b: Image, name: string) =
  let (diffScore, diffImage) = diff(a, b)
  echo &"{name} score: {diffScore}"
  diffImage.writeFile(&"{name}_diff.png")

when defined(release):
  {.push checks: off.}

proc fillMask(
  shapes: seq[seq[Vec2]], width, height: int, windingRule = NonZero
): Mask =
  result = newMask(width, height)

  let
    segments = shapes.shapesToSegments()
    bounds = computeBounds(segments).snapToPixels()
    startY = max(0, bounds.y.int)
    pathHeight = min(height, (bounds.y + bounds.h).int)
    partitioning = partitionSegments(segments, startY, pathHeight)
    width = width.float32

  var
    hits = newSeq[(float32, int16)](partitioning.maxEntryCount)
    numHits: int
    aa: bool
  for y in startY ..< pathHeight:
    computeCoverage(
      cast[ptr UncheckedArray[uint8]](result.data[result.dataIndex(0, y)].addr),
      hits,
      numHits,
      aa,
      width,
      y,
      0,
      partitioning,
      windingRule
    )
    if not aa:
      for (prevAt, at, count) in hits.walk(numHits, windingRule, y, width):
        let
          startIndex = result.dataIndex(prevAt.int, y)
          len = at.int - prevAt.int
        fillUnsafe(result.data, 255, startIndex, len)

proc fillMask*(
  path: SomePath, width, height: int, windingRule = NonZero
): Mask =
  ## Returns a new mask with the path filled. This is a faster alternative
  ## to `newMask` + `fillPath`.
  let shapes = parseSomePath(path, true, 1)
  shapes.fillMask(width, height, windingRule)

proc fillImage(
  shapes: seq[seq[Vec2]],
  width, height: int,
  color: SomeColor,
  windingRule = NonZero
): Image =
  result = newImage(width, height)

  let
    mask = shapes.fillMask(width, height, windingRule)
    rgbx = color.rgbx()

  var i: int
  when defined(amd64) and not defined(pixieNoSimd):
    let
      colorVec = mm_set1_epi32(cast[int32](rgbx))
      oddMask = mm_set1_epi16(cast[int16](0xff00))
      div255 = mm_set1_epi16(cast[int16](0x8081))
      vec255 = mm_set1_epi32(cast[int32](uint32.high))
      vecZero = mm_setzero_si128()
      colorVecEven = mm_slli_epi16(colorVec, 8)
      colorVecOdd = mm_and_si128(colorVec, oddMask)
      iterations = result.data.len div 16
    for _ in 0 ..< iterations:
      var coverageVec = mm_loadu_si128(mask.data[i].addr)
      if mm_movemask_epi8(mm_cmpeq_epi16(coverageVec, vecZero)) != 0xffff:
        if mm_movemask_epi8(mm_cmpeq_epi32(coverageVec, vec255)) == 0xffff:
          for q in [0, 4, 8, 12]:
            mm_storeu_si128(result.data[i + q].addr, colorVec)
        else:
          for q in [0, 4, 8, 12]:
            var unpacked = unpackAlphaValues(coverageVec)
            # Shift the coverages from `a` to `g` and `a` for multiplying
            unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 16))

            var
              sourceEven = mm_mulhi_epu16(colorVecEven, unpacked)
              sourceOdd = mm_mulhi_epu16(colorVecOdd, unpacked)
            sourceEven = mm_srli_epi16(mm_mulhi_epu16(sourceEven, div255), 7)
            sourceOdd = mm_srli_epi16(mm_mulhi_epu16(sourceOdd, div255), 7)

            mm_storeu_si128(
              result.data[i + q].addr,
              mm_or_si128(sourceEven, mm_slli_epi16(sourceOdd, 8))
            )

            coverageVec = mm_srli_si128(coverageVec, 4)

      i += 16

  let channels = [rgbx.r.uint32, rgbx.g.uint32, rgbx.b.uint32, rgbx.a.uint32]
  for i in i ..< result.data.len:
    let coverage = mask.data[i]
    if coverage == 255:
      result.data[i] = rgbx
    elif coverage != 0:
      result.data[i].r = ((channels[0] * coverage) div 255).uint8
      result.data[i].g = ((channels[1] * coverage) div 255).uint8
      result.data[i].b = ((channels[2] * coverage) div 255).uint8
      result.data[i].a = ((channels[3] * coverage) div 255).uint8

proc fillImage*(
  path: SomePath, width, height: int, color: SomeColor, windingRule = NonZero
): Image =
  ## Returns a new image with the path filled. This is a faster alternative
  ## to `newImage` + `fillPath`.
  let shapes = parseSomePath(path, false, 1)
  shapes.fillImage(width, height, color, windingRule)

proc strokeMask*(
  path: SomePath,
  width, height: int,
  strokeWidth: float32 = 1.0,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
): Mask =
  ## Returns a new mask with the path stroked. This is a faster alternative
  ## to `newImage` + `strokePath`.
  let strokeShapes = strokeShapes(
    parseSomePath(path, false, 1),
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes,
    1
  )
  result = strokeShapes.fillMask(width, height, NonZero)

proc strokeImage*(
  path: SomePath,
  width, height: int,
  color: SomeColor,
  strokeWidth: float32 = 1.0,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
): Image =
  ## Returns a new image with the path stroked. This is a faster alternative
  ## to `newImage` + `strokePath`.
  let strokeShapes = strokeShapes(
    parseSomePath(path, false, 1),
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes,
    1
  )
  result = strokeShapes.fillImage(width, height, color, NonZero)

when defined(release):
  {.pop.}


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
    a.fillPath(p, rgbx(0, 0, 255, 255))

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
    a.fill(rgbx(255, 255, 255, 255))

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    a.fillPath(p, rgbx(0, 0, 255, 255))

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
    a.fill(rgbx(255, 255, 255, 255))

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    a.fillPath(p, rgbx(255, 0, 0, 255))

  # a.writeFile("pixie3.png")

  # doDiff(readImage("cairo3.png"), a, "cairo3")

block:
  let path = newPath()
  path.roundedRect(200, 200, 600, 600, 10, 10, 10, 10)

  let shapes = path.commandsToShapes(true, 1)

  # let
  #   surface = imageSurfaceCreate(FORMAT_ARGB32, 1000, 1000)
  #   ctx = surface.create()

  # timeIt "cairo4":
  #   ctx.setSourceRgba(0, 0, 0, 0)
  #   let operator = ctx.getOperator()
  #   ctx.setOperator(OperatorSource)
  #   ctx.paint()
  #   ctx.setOperator(operator)

  timeIt "cairo4":
    let
      surface = imageSurfaceCreate(FORMAT_ARGB32, 1000, 1000)
      ctx = surface.create()

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
  timeIt "pixie4":
    a = newImage(1000, 1000)

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    a.fillPath(p, rgbx(127, 0, 0, 127))

  # a.writeFile("pixie4.png")

  # doDiff(readImage("cairo4.png"), a, "4")

  var b: Image
  let paint = newPaint(SolidPaint)
  paint.color = color(1, 0, 0, 0.5)
  paint.blendMode = OverwriteBlend

  timeIt "pixie4 overwrite":
    b = newImage(1000, 1000)

    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)
    b.fillPath(p, paint)

  # b.writeFile("b.png")

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
    let p = newPath()
    p.moveTo(shapes[0][0])
    for shape in shapes:
      for v in shape:
        p.lineTo(v)

    tmp = p.fillImage(1000, 1000, rgbx(127, 0, 0, 127))

  # tmp.writeFile("tmp.png")
