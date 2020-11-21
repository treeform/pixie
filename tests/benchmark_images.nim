import pixie, chroma, vmath, fidget/opengl/perf, pixie/fileformats/bmp

proc inPlaceDraw*(destImage: Image, srcImage: Image, mat: Mat3, blendMode = Normal) =
  ## Draws one image onto another using matrix with color blending.
  for y in 0 ..< destImage.width:
    for x in 0 ..< destImage.height:
      let srcPos = mat * vec2(x.float32, y.float32)
      let destRgba = destImage.getRgbaUnsafe(x, y)
      var rgba = destRgba
      var srcRgba = rgba(0, 0, 0, 0)
      if srcImage.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        srcRgba = srcImage.getRgbaSmooth(srcPos.x - 0.5, srcPos.y - 0.5)
      if blendMode.hasEffect(srcRgba):
        rgba = blendMode.mix(destRgba, srcRgba)
      destImage.setRgbaUnsafe(x, y, rgba)

proc inPlaceDraw*(destImage: Image, srcImage: Image, pos = vec2(0, 0), blendMode = Normal) =
  destImage.inPlaceDraw(srcImage, translate(-pos), blendMode)

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  a.inPlaceDraw(b, pos=vec2(25, 25))
  writeFile("tests/images/inPlaceDraw.bmp", a.encodeBmp())

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.draw(b, pos=vec2(25, 25))
  writeFile("tests/images/copyDraw.bmp", c.encodeBmp())

timeIt "inPlaceDraw":
  var tmp = 0
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    a.inPlaceDraw(b, pos=vec2(25, 25))
    tmp += a.width * a.height
  echo tmp

timeIt "copyDraw":
  var tmp = 0
  for i in 0 ..< 1000:
    var a = newImage(100, 100)
    a.fill(rgba(255, 0, 0, 255))
    var b = newImage(100, 100)
    b.fill(rgba(0, 255, 0, 255))
    var c = a.draw(b, pos=vec2(25, 25))
    tmp += c.width * c.height
  echo tmp
