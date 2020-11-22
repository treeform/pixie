import pixie, chroma, vmath, os

proc writeAndCheck(image: Image, fileName: string) =
  image.writeFile(fileName)
  let masterFileName = fileName.changeFileExt(".master.png")
  if not existsFile(masterFileName):
    echo "Master file: " & masterFileName & " not found!"
    return
  var master = readImage(fileName)
  assert image.width == master.width
  assert image.height == master.height
  assert image.data == master.data

block:
  var image = newImage(10, 10)
  image[0, 0] = rgba(255, 255, 255, 255)
  doAssert image[0, 0] == rgba(255, 255, 255, 255)

block:
  var image = newImage(10, 10)
  image.fill(rgba(255, 0, 0, 255))
  doAssert image[0, 0] == rgba(255, 0, 0, 255)

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.drawFast1(b, x=25, y=25)
  c.writeAndCheck("tests/images/drawFast1.png")

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.drawFast2(b, x=25, y=25, bmCopy)
  c.writeAndCheck("tests/images/drawFast2.png")

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.drawFast3(b, translate(vec2(25.15, 25.15)), bmCopy)
  c.writeAndCheck("tests/images/drawFast3.png")

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.drawFast4(b, translate(vec2(25.15, 25.15)) * rotationMat3(PI/2), bmCopy)
  c.writeAndCheck("tests/images/drawFast4Rot.png")

  var d = a.drawFast3(b, translate(vec2(25.15, 25.15)) * rotationMat3(PI/2), bmCopy)
  d.writeAndCheck("tests/images/drawFast3Rot.png")
