import pixie, chroma, vmath, fidget/opengl/perf, pixie/fileformats/bmp

timeIt "benchDrawFast1 COPY":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    c = a.drawFast1(b, translate(vec2(25, 25))) # Copy
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast1Copy.png")
  echo tmp

timeIt "benchDrawFast2 COPY":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    c = a.drawFast2(b, translate(vec2(25, 25)), bmCopy)
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast2Copy.png")
  echo tmp

timeIt "benchDrawFast3 COPY":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    c = a.drawFast3(b, translate(vec2(25, 25)), bmCopy)
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast3Copy.png")
  echo tmp

timeIt "benchDrawFast2 Normal":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    c = a.drawFast2(b, translate(vec2(25, 25)), bmNormal)
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast2Normal.png")
  echo tmp

timeIt "benchDrawFast3 Normal":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    c = a.drawFast3(b, translate(vec2(25, 25)), bmNormal)
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast3Normal.png")
  echo tmp

timeIt "benchDrawFast2 Saturation":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 0, 0, 255))
    c = a.drawFast2(b, translate(vec2(25, 25)), bmSaturation)
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast2Saturation.png")
  echo tmp

timeIt "benchDrawFast3 Saturation":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 0, 0, 255))
    c = a.drawFast3(b, translate(vec2(25, 25)), bmSaturation)
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast3Saturation.png")
  echo tmp

timeIt "benchDrawFast3 Rotation":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 0, 0, 255))
    c = a.drawFast3(b, translate(vec2(25, 25)) * rotationMat3(PI/2), bmNormal)
    tmp += c.width * c.height
  c.writeFile("tests/images/benchDrawFast3Rotation.png")
  echo tmp
