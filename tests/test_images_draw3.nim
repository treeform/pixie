import pixie, strformat, xrays

block:
  for d in 0 .. 36:
    echo d*10
    let
      a = newImage(100, 100)
      b = readImage(&"tests/images/turtle@10x.png")
    a.fill(rgba(255, 255, 255, 255))
    let m = translate(vec2(50, 50)) * rotate(d.float32*10.toRadians) * scale(vec2(0.1, 0.1))
    a.draw(b, m)


    a.writeFile(&"tests/images/turtle{d*10}.png")
