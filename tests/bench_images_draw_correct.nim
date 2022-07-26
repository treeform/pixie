import benchy, pixie, pixie/images {.all.}, strformat, xrays

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  a.drawCorrect(b, translate(vec2(250, 250)), blendMode = OverwriteBlend)
  a.writeFile("tests/images/rotate0.png")

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
