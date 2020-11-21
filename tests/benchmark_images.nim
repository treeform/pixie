import pixie, chroma, vmath, fidget/opengl/perf, pixie/fileformats/bmp

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  a.inplaceDraw(b, pos=vec2(25, 25))
  writeFile("tests/images/inplaceDraw.bmp", a.encodeBmp())

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.copyDraw(b, pos=vec2(25, 25))
  writeFile("tests/images/copyDraw.bmp", c.encodeBmp())


timeIt "inplaceDraw":
  var tmp = 0
  for i in 0 ..< 100000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    a.inplaceDraw(b, pos=vec2(25, 25))
    tmp += a.width * a.height
  echo tmp

timeIt "copyDraw":
  var tmp = 0
  for i in 0 ..< 100000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    var c = a.copyDraw(b, pos=vec2(25, 25))
    tmp += c.width * c.height
  echo tmp
