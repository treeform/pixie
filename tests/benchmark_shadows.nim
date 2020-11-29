import pixie, chroma, vmath, fidget/opengl/perf

timeIt "spread":
  var tmp = 0
  var spread: Image
  for i in 0 ..< 100:
    var a = newImageFill(100, 100, rgba(0, 0, 0, 0))
    var b = newImageFill(50, 50, rgba(0, 0, 0, 255))
    a.draw(b, vec2(25, 25))

    spread = a.spread(spread = 10)

    b = newImageFill(50, 50, rgba(255, 255, 255, 255))
    spread.draw(b, vec2(25, 25))

    tmp += spread.width * spread.height
  spread.writeFile("tests/images/spread1.png")
  echo tmp

timeIt "blur":
  var tmp = 0
  var blur: Image
  for i in 0 ..< 100:
    var a = newImageFill(100, 100, rgba(0, 0, 0, 0))
    var b = newImageFill(50, 50, rgba(255, 255, 255, 255))
    a.draw(b, vec2(25, 25))

    blur = a.blur(radius = 10)

    b = newImageFill(50, 50, rgba(255, 255, 255, 255))
    blur.draw(b, vec2(25, 25))

    tmp += blur.width * blur.height
  blur.writeFile("tests/images/blur1.png")
  echo tmp

timeIt "shadow":
  var tmp = 0
  var shadow: Image
  for i in 0 ..< 100:
    var a = newImageFill(100, 100, rgba(0, 0, 0, 0))
    var b = newImageFill(50, 50, rgba(0, 0, 0, 255))
    a.draw(b, vec2(25, 25))

    shadow = a.shadow(
      offset = vec2(0, 0), spread = 10, blur = 10, color = rgba(0, 0, 0, 255))

    b = newImageFill(50, 50, rgba(255, 255, 255, 255))
    shadow.draw(b, vec2(25, 25))

    tmp += shadow.width * shadow.height
  shadow.writeFile("tests/images/shadow1.png")
  echo tmp

# import print
# timeIt "Shadow Stops":
#   var tmp = 0
#   var shadow: Image
#   for i in 0 ..< 1:
#     var a = newImageFill(10, 200, rgba(0, 0, 0, 0))
#     var b = newImageFill(50, 50, rgba(0, 0, 0, 255))
#     a.draw(b, vec2(-25, -25))

#     for spread in 0 .. 0:
#       let spread = spread.float
#       for blur in 0 .. 10:
#         let blur = blur.float
#         print spread, blur

#         shadow = a.shadow(
#           offset = vec2(0, 0), spread = spread, blur = blur, color = rgba(0, 0, 0, 255))

#         for y in 25 ..< (25 + spread + blur).int:
#           echo y - 25, ":", shadow[5, y].a

#         b = newImageFill(50, 50, rgba(255, 255, 255, 255))
#         shadow.draw(b, vec2(-25, -25))

#     tmp += shadow.width * shadow.height
#   shadow.writeFile("tests/images/shadowStops.png")
#   echo tmp
