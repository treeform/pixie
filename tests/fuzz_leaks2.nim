import os, pixie, random

when not defined(pixieLeakCheck):
  quit("Requires -d:pixieLeakCheck")

randomize()

for i in 0 ..< 100_000:
  let image = newImage(400, 400)
  image.fill(rgba(255, 255, 255, 255))

  let ctx = newContext(image)

  ctx.translate(200, 200)
  ctx.scale(vec2(rand(0.1 .. 1.7), rand(0.1 .. 1.7)))
  ctx.rotate(rand(0.0 .. 2*PI))

  ctx.strokeStyle = "#000000"
  ctx.lineCap = sample([RoundCap, ButtCap, SquareCap])
  ctx.lineJoin = sample([MiterJoin, RoundJoin, BevelJoin])
  ctx.lineWidth = rand(0.1 .. 1.0)

  var first = true
  var number = rand(2 .. 100)
  for a in 0 .. number:
    let th = a.float32 / number.float32 * PI
    let pos = vec2(sin(th) * 100, cos(th) * 100)
    if first:
      ctx.moveTo(pos)
      first = false
    else:
      ctx.lineTo(pos)
  ctx.stroke()

  # image.writeFile("tests/fuzz_leaks2.png")
  # break
