import pixie, chroma, vmath, benchy

block:
  var a = newImage(1000, 1000)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(500, 500)
  b.fill(rgba(0, 255, 0, 255))

  timeIt "drawCorrect bmNormal":
    a.drawCorrect(b, translate(vec2(25, 25)), bmNormal)
    keep(b)

block:
  var a = newImage(1000, 1000)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(500, 500)
  b.fill(rgba(0, 255, 0, 255))

  timeIt "draw bmNormal":
    a.draw(b, translate(vec2(25, 25)), bmNormal)
    keep(b)

block:
  var a = newImage(1000, 1000)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(500, 500)
  b.fill(rgba(0, 255, 0, 255))

  timeIt "drawCorrect Smooth bmNormal":
    a.drawCorrect(b, translate(vec2(25.2, 25.2)), bmNormal)
    keep(b)

block:
  var a = newImage(1000, 1000)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(500, 500)
  b.fill(rgba(0, 255, 0, 255))

  timeIt "draw Smooth bmNormal":
    a.draw(b, translate(vec2(25.2, 25.2)), bmNormal)
    keep(b)
