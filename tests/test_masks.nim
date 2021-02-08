import pixie, pixie/fileformats/png

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

  writeFile("tests/images/masks/maskMinified.png", mask.minifyBy2().encodePng())
