import pixie, strformat, xrays
import pixie/images {.all.}

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.drawCorrect(b, translate(vec2(250, 250)), blendMode = OverwriteBlend)
  a.writeFile("tests/images/rotate0.png")

import benchy

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)

  timeIt "drawCorrect":
    a.fill(rgba(255, 0, 0, 255))
    b.fill(rgba(0, 255, 0, 255))

    a.drawCorrect(b, translate(vec2(250, 250)), blendMode = OverwriteBlend)


block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)

  timeIt "draw":
    a.fill(rgba(255, 0, 0, 255))
    b.fill(rgba(0, 255, 0, 255))

    a.draw(b, translate(vec2(250, 250)), blendMode = OverwriteBlend)
