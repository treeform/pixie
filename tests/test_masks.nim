import chroma, pixie, pixie/fileformats/png

block:
  let
    mask = newMask(100, 100)
    r = 10.0
    x = 10.0
    y = 10.0
    h = 80.0
    w = 80.0
  var path: Path
  path.moveTo(x + r, y)
  path.arcTo(x + w, y, x + w, y + h, r)
  path.arcTo(x + w, y + h, x, y + h, r)
  path.arcTo(x, y + h, x, y, r)
  path.arcTo(x, y, x + w, y, r)
  mask.fillPath(path)

  let minified = mask.minifyBy2()

  doAssert minified.width == 50 and minified.height == 50

  writeFile("tests/images/masks/maskMinified.png", minified.encodePng())

block:
  let image = newImage(100, 100)
  image.fill(rgba(255, 100, 100, 255))

  var path: Path
  path.ellipse(image.width / 2, image.height / 2, 25, 25)

  let mask = newMask(image.width, image.height)
  mask.fillPath(path)

  image.draw(mask)
  image.toStraightAlpha()
  image.writeFile("tests/images/masks/circleMask.png")

block:
  let a = newMask(100, 100)
  a.fill(255)

  var path: Path
  path.ellipse(a.width / 2, a.height / 2, 25, 25)

  let b = newMask(a.width, a.height)
  b.fillPath(path)

  a.draw(b)
  writeFile("tests/images/masks/maskedMask.png", a.encodePng())
