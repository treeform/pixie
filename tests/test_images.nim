import pixie, chroma, vmath, os

proc writeAndCheck(image: Image, fileName: string) =
  image.writeFile(fileName)
  let masterFileName = fileName.changeFileExt(".master.png")
  if not existsFile(masterFileName):
    quit("Master file: " & masterFileName & " not found!")
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
  var c = a.draw(b, pos=vec2(25, 25))
  c.writeAndCheck("tests/images/draw.png")

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.draw(b, pos=vec2(25, 25), COPY)
  c.writeAndCheck("tests/images/drawCopy.png")

block:
  var a = newImage(100, 100)
  a.fill(rgba(255, 0, 0, 255))
  var b = newImage(100, 100)
  b.fill(rgba(0, 255, 0, 255))
  var c = a.draw(b, pos=vec2(25.15, 25.15))
  c.writeAndCheck("tests/images/drawSmooth.png")
