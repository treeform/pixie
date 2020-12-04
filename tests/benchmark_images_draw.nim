import pixie, chroma, vmath, fidget/opengl/perf

# timeIt "drawOverwrite bmOverwrite":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.drawOverwrite(b, translate(vec2(25, 25))) # Copy
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawOverwrite.bmOverwrite.png")
#   echo tmp

# timeIt "drawBlend bmOverwrite":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.drawBlend(b, translate(vec2(25, 25)), bmOverwrite)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawBlend.bmOverwrite.png")
#   echo tmp

# timeIt "drawBlendSmooth bmOverwrite":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.drawBlendSmooth(b, translate(vec2(25, 25)), bmOverwrite)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawBlendSmooth.bmOverwrite.png")
#   echo tmp

# timeIt "drawBlend bmNormal":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.drawBlend(b, translate(vec2(25, 25)), bmNormal)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawBlend.bmNormal.png")
#   echo tmp

# timeIt "drawBlendSmooth bmNormal":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.drawBlendSmooth(b, translate(vec2(25, 25)), bmNormal)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawBlendSmooth.bmNormal.png")
#   echo tmp

timeIt "drawCorrect bmNormal":
  var tmp = 0
  var c: Image
  for i in 0 ..< 1000:
    var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
    var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
    c = a.drawCorrect(b, translate(vec2(25, 25)), bmNormal)
    tmp += c.width * c.height
  c.writeFile("tests/images/bench.drawCorrect.bmNormal.png")
  echo tmp

# timeIt "drawStepper bmNormal":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.drawStepper(b, translate(vec2(25, 25)), bmNormal)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawStepper.bmNormal.png")
#   echo tmp

# timeIt "drawInPlace bmNormal":
#   var tmp = 0
#   var a: Image
#   for i in 0 ..< 1000:
#     a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     a.drawInPlace(b, translate(vec2(25, 25)), bmNormal)
#     tmp += a.width * a.height
#   a.writeFile("tests/images/bench.drawInPlace.bmNormal.png")
#   echo tmp

# timeIt "drawUberCopy bmNormal":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.draw(b, translate(vec2(25, 25)), bmNormal)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawUberCopy.bmNormal.png")
#   echo tmp

timeIt "draw bmNormal":
  var tmp = 0
  var a: Image
  for i in 0 ..< 1000:
    a = newImageFill(100, 100, rgba(255, 0, 0, 255))
    var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
    a.draw(b, translate(vec2(25, 25)), bmNormal)
    tmp += a.width * a.height
  a.writeFile("tests/images/bench.draw.bmNormal.png")
  echo tmp

# timeIt "drawUberCopy Smooth bmNormal":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
#     c = a.draw(b, translate(vec2(25.2, 25.2)), bmNormal)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawUberCopy.Smooth.bmNormal.png")
#   echo tmp

timeIt "draw Smooth bmNormal":
  var tmp = 0
  var a: Image
  for i in 0 ..< 1000:
    a = newImageFill(100, 100, rgba(255, 0, 0, 255))
    var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
    a.draw(b, translate(vec2(25.2, 25.2)), bmNormal)
    tmp += a.width * a.height
  a.writeFile("tests/images/bench.draw.Smooth.bmNormal.png")
  echo tmp

# timeIt "drawBlend bmSaturation":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 0, 0, 255))
#     c = a.drawBlend(b, translate(vec2(25, 25)), bmSaturation)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawBlend.bmSaturation.png")
#   echo tmp

# timeIt "drawBlendSmooth bmSaturation":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImageFill(100, 100, rgba(255, 0, 0, 255))
#     var b = newImageFill(100, 100, rgba(0, 0, 0, 255))
#     c = a.drawBlendSmooth(b, translate(vec2(25, 25)), bmSaturation)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/bench.drawBlendSmooth.bmSaturation.png")
#   echo tmp

# timeIt "benchDrawFast3 Rotation":
#   var tmp = 0
#   var c: Image
#   for i in 0 ..< 1000:
#     var a = newImage(100, 100)
#     a.fill(rgba(255, 0, 0, 255))
#     var b = newImage(100, 100)
#     b.fill(rgba(0, 0, 0, 255))
#     c = a.drawFast3(b, translate(vec2(25, 25)) * rotationMat3(PI/2), bmNormal)
#     tmp += c.width * c.height
#   c.writeFile("tests/images/benchDrawFast3Rotation.png")
#   echo tmp
