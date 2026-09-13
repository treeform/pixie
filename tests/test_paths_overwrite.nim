import pixie, std/math

block:
  # clearRect uses transparent OverwriteBlend paint. Positive path coverage
  # must still clear a pixel even though the resulting source alpha is zero.
  let image = newImage(128, 64)
  let backdrop = rgbx(0, 0, 255, 255)
  image.fill(backdrop)
  let ctx = image.newContext()
  ctx.clearRect(10.25, 10.25, 70.5, 40.5)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let expected =
        if x in 10 .. 80 and y in 10 .. 50:
          rgbx(0, 0, 0, 0)
        else:
          backdrop
      doAssert image[x, y] == expected, "clearRect pixel " & $x & "," & $y

block:
  # Overwrite must preserve uncovered pixels and replace covered pixels,
  # including when translucent paint rounds to a fully transparent source.
  for shape in ["circle", "star", "triangle", "rectangle"]:
    let
      width = if shape == "star": 260 else: 128
      height = if shape == "star": 200 else: 64
      path = newPath()
    case shape
    of "circle":
      path.circle(circle(vec2(64, 32), 40))
    of "star":
      for i in 0 ..< 80:
        let
          angle = i.float32 * PI.float32 / 40
          radius = if (i and 1) == 0: 42.0 else: 92.0
          point = vec2(130 + cos(angle) * radius, 100 + sin(angle) * radius)
        if i == 0: path.moveTo(point)
        else: path.lineTo(point)
      path.closePath()
    of "triangle":
      path.moveTo(10.25, 10.25)
      path.lineTo(90.75, 10.25)
      path.lineTo(30.25, 50.75)
      path.closePath()
    else:
      path.rect(10.25, 10.25, 70.5, 40.5)

    # Opaque paint reveals coverage independently of the tested paint's alpha.
    let coverage = newImage(width, height)
    coverage.fillPath(path, color(1, 0, 0, 1))
    for alpha in [255, 128, 1, 0]:
      let
        paint = newPaint(SolidPaint)
        source = newImage(width, height)
        actual = newImage(width, height)
        backdrop = rgbx(0, 0, 255, 255)
      paint.color = color(1, 0, 0, alpha.float32 / 255)
      # NormalBlend onto transparent black yields the expected source color.
      source.fillPath(path, paint)
      actual.fill(backdrop)
      paint.blendMode = OverwriteBlend
      actual.fillPath(path, paint)
      for i, pixel in actual.data:
        let expected =
          if coverage.data[i].a == 0: backdrop
          else: source.data[i]
        doAssert pixel == expected,
          shape & " alpha=" & $alpha & " pixel=" & $(i mod width) & "," & $(i div width)
