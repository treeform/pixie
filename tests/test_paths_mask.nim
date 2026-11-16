import pixie

block:
  # Sloping edges put fully covered pixels in the same scanline as partial
  # coverage, exercising both SIMD blocks and scalar prefixes/tails.
  let white = rgbx(255, 255, 255, 255)
  for width in [1, 15, 16, 17, 31, 32, 33, 64, 80]:
    for shift in 0 .. 7:
      let
        path = newPath()
        x = shift.float32
      path.moveTo(x + 0.25, 0.25)
      path.lineTo(x + width.float32 + 0.75, 1.75)
      path.lineTo(x + width.float32 + 0.25, 7.75)
      path.lineTo(x + 0.75, 6.25)
      path.closePath()

      let coverage = newImage(width + 32, 9)
      coverage.fillPath(path, white)
      for alpha in [1'u8, 128, 201, 255]:
        let
          actual = newImage(coverage.width, coverage.height)
          paint = newPaint(SolidPaint)
          mask = rgbx(alpha, alpha, alpha, alpha)
        actual.fill(white)
        paint.color = color(1, 1, 1, alpha.float32 / 255)
        paint.blendMode = MaskBlend
        actual.fillPath(path, paint)
        for i, pixel in actual.data:
          let expected = mask * coverage.data[i].a
          doAssert pixel == expected,
            "mask width=" & $width & " shift=" & $shift &
            " alpha=" & $alpha & " pixel=" & $(i mod actual.width) &
            "," & $(i div actual.width)
