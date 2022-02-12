import benchy, chroma, vmath

include pixie/images

block:
  let
    a = newImage(1000, 1000)
    b = newImage(50, 50)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "drawCorrect small-on-big":
    a.drawCorrect(b, translate(vec2(25, 25)), blendMode = BlendNormal)
    keep(b)

block:
  let
    a = newImage(1000, 1000)
    b = newImage(50, 50)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "drawUber small-on-big":
    a.drawUber(b, translate(vec2(25, 25)), blendMode = BlendNormal)
    keep(b)

block:
  let
    a = newImage(1000, 1000)
    b = newImage(50, 50)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "drawCorrect small-on-big smooth":
    a.drawCorrect(b, translate(vec2(25.1, 25.1)), blendMode = BlendNormal)
    keep(b)

block:
  let
    a = newImage(1000, 1000)
    b = newImage(50, 50)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "drawUber small-on-big smooth":
    a.drawUber(b, translate(vec2(25.1, 25.1)), blendMode = BlendNormal)
    keep(b)
