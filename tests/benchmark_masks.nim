import benchy, chroma, pixie

let mask = newMask(2560, 1440)

proc reset() =
  mask.fill(63)

reset()

timeIt "minifyBy2":
  let minified = mask.minifyBy2()
  doAssert minified[0, 0] == 63

reset()

timeIt "invert":
  mask.invert()

reset()

timeIt "applyOpacity":
  mask.applyOpacity(0.5)

reset()

timeIt "blur":
  mask.blur(40)

reset()

timeIt "ceil":
  mask.ceil()

reset()

block spread_1:
  var p: Path
  p.rect(500, 500, 500, 500)

  timeIt "spread_1":
    mask.fill(0)
    mask.fillPath(p)
    mask.spread(10)

block spread_2:
  var p: Path
  p.rect(500, 500, 1000, 1000)

  timeIt "spread_2":
    mask.fill(0)
    mask.fillPath(p)
    mask.spread(10)

block spread_3:
  timeIt "spread_3":
    mask.fill(255)
    mask.spread(10)

block spread_4:
  timeIt "spread_4":
    mask.fill(0)
    mask.setValueUnsafe(1000, 1000, 255)
    mask.spread(10)
