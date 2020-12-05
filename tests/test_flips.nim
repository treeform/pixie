import pixie, chroma, vmath

block:

  var a = newImage(101, 101)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(50, 50)
  b.fill(rgba(0, 255, 0, 255))

  a.draw(b, vec2(0, 0))

  a.writeFile("tests/images/flipped1.png")
  a.flipVertical()
  a.writeFile("tests/images/flipped2.png")
  a.flipHorizontal()
  a.writeFile("tests/images/flipped3.png")
