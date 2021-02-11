import pixie, chroma, vmath, benchy

block:
  let
    a = newImage(1000, 1000)
    b = newImage(50, 50)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "draw small-on-big bmNormal":
    a.draw(b, translate(vec2(25, 25)), bmNormal)
    keep(b)

block:
  let
    a = newImage(1000, 1000)
    b = newImage(50, 50)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "draw small-on-big Smooth bmNormal":
    a.draw(b, translate(vec2(25.2, 25.2)), bmNormal)
    keep(b)

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "draw big-on-bigger bmNormal":
    a.draw(b, translate(vec2(25, 25)), bmNormal)
    keep(b)

block:
  let
    a = newImage(1000, 1000)
    b = newImage(500, 500)
  a.fill(rgba(255, 0, 0, 255))
  b.fill(rgba(0, 255, 0, 255))

  timeIt "draw big-on-bigger Smooth bmNormal":
    a.draw(b, translate(vec2(25.2, 25.2)), bmNormal)
    keep(b)
