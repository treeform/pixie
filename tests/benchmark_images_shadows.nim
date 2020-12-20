import pixie, chroma, vmath, benchy

block:

  var a = newImage(100, 100)
  var b = newImage(50, 50)

  timeIt "spread":
    a.fill(rgba(0, 0, 0, 0))
    b.fill(rgba(0, 0, 0, 255))
    a.draw(b, vec2(25, 25))

    a.spread(spread = 10)

  b = newImage(50, 50)
  b.fill(rgba(255, 255, 255, 255))
  a.draw(b, vec2(25, 25))

  # a.writeFile("tests/images/spread1.png")

block:
  var a = newImage(100, 100)
  var b = newImage(50, 50)

  timeIt "blur":
    a.fill(rgba(0, 0, 0, 0))
    b.fill(rgba(255, 255, 255, 255))
    a.draw(b, vec2(25, 25))

    a.blur(radius = 10)

  b = newImage(50, 50)
  b.fill(rgba(255, 255, 255, 255))
  a.draw(b, vec2(25, 25))

  # a.writeFile("tests/images/blur1.png")

block:
  var shadow: Image
  var a = newImage(100, 100)
  var b = newImage(50, 50)

  timeIt "shadow":
    a.fill(rgba(0, 0, 0, 0))
    b.fill(rgba(0, 0, 0, 255))
    a.draw(b, vec2(25, 25))

    shadow = a.shadow(
      offset = vec2(0, 0),
      spread = 10,
      blur = 10,
      color = rgba(0, 0, 0, 255)
    )

  b = newImage(50, 50)
  b.fill(rgba(255, 255, 255, 255))
  shadow.draw(b, vec2(25, 25))
  keep(shadow)

  # shadow.writeFile("tests/images/shadow1.png")


# import print
# timeIt "Shadow Stops":
#   var tmp = 0
#   var shadow: Image
#   for i in 0 ..< 1:
#     var a = newImage(10, 200)
#     var b = newImage(50, 50)
#     b.fill(rgba(0, 0, 0, 255))
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

#         b = newImage(50, 50)
#         b.fill(rgba(255, 255, 255, 255))
#         shadow.draw(b, vec2(-25, -25))

#     tmp += shadow.width * shadow.height
#   shadow.writeFile("tests/images/shadowStops.png")
#   echo tmp
