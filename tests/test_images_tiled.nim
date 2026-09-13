import pixie

proc repeatImage(tile: Image, columns, rows: int): Image =
  result = newImage(tile.width * columns, tile.height * rows)
  for row in 0 ..< rows:
    for column in 0 ..< columns:
      for y in 0 ..< tile.height:
        for x in 0 ..< tile.width:
          result[column * tile.width + x, row * tile.height + y] = tile[x, y]

block:
  # Wrapped sampling must match an explicitly repeated image, including at
  # negative coordinates and across horizontal, vertical and corner seams.
  for size in [ivec2(3, 2), ivec2(1, 3), ivec2(3, 1), ivec2(1, 1)]:
    let tile = newImage(size.x, size.y)
    for y in 0 ..< tile.height:
      for x in 0 ..< tile.width:
        tile[x, y] = rgbx(
          (x * 37 + y * 13).uint8,
          (x * 11 + y * 43).uint8,
          (x * 23 + y * 17).uint8,
          (128 + x * 19 + y * 29).uint8
        )
    let repeated = repeatImage(tile, 7, 7)
    for y in -2 * tile.height .. 2 * tile.height:
      for x in -2 * tile.width .. 2 * tile.width:
        for fy in [0.float32, 0.25, 0.5, 0.75]:
          for fx in [0.float32, 0.25, 0.5, 0.75]:
            doAssert tile.getRgbaSmooth(x.float32 + fx, y.float32 + fy, true) ==
              repeated.getRgbaSmooth(
                (x + 3 * tile.width).float32 + fx,
                (y + 3 * tile.height).float32 + fy
              )
    doAssert tile.getRgbaSmooth(-2, -2) == rgbx(0, 0, 0, 0)

block:
  # https://github.com/treeform/pixie/issues/597
  let tile = newImage(4, 4)
  tile.fill(rgba(255, 255, 255, 255))
  for x in 0 ..< tile.width:
    tile[x, 0] = rgba(35, 115, 210, 255)

  let repeated = repeatImage(tile, 192, 192)
  for degrees in [-7.float32, 7, -90, 90, 180]:
    let paint = newPaint(TiledImagePaint)
    paint.image = tile
    paint.imageMat = rotate(degrees * PI.float32 / 180)
    let
      image = newImage(256, 160)
      inverse = paint.imageMat.inverse()
    image.fill(paint)
    for y in 0 ..< image.height:
      for x in 0 ..< image.width:
        let
          sample = inverse * vec2(x.float32 + 0.5, y.float32 + 0.5)
          expected = repeated.getRgbaSmooth(
            sample.x - 0.5 + 256, sample.y - 0.5 + 256
          )
          actual = image[x, y]
        # Moving the reference coordinates can change float32 rounding by
        # one channel value, but cannot change the stripe placement or alpha.
        doAssert abs(actual.r.int - expected.r.int) <= 1
        doAssert abs(actual.g.int - expected.g.int) <= 1
        doAssert abs(actual.b.int - expected.b.int) <= 1
        doAssert actual.a == 255
