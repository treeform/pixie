import pixie, random

when not defined(pixieLeakCheck):
  quit("Requires -d:pixieLeakCheck")

randomize()

for i in 0 ..< 100_000:

  let image = newImage(400, 400)
  image.fill(rgba(255, 255, 255, 255))

  let ctx = newContext(image)
  ctx.translate(200, 200)
  ctx.scale(vec2(rand(0.1 .. 1.2), rand(0.1 .. 1.2)))
  ctx.rotate(rand(0.0 .. 2*PI))

  ctx.strokeStyle = "#000000"
  ctx.lineCap = sample([RoundCap, ButtCap, SquareCap])
  ctx.lineJoin = sample([MiterJoin, RoundJoin, BevelJoin])
  ctx.miterLimit = 2
  ctx.lineWidth = rand(0.1 .. 20.0)

  ctx.moveTo(rand(-100 .. 100).float32, rand(-100 .. 100).float32)
  for i in 0 ..< rand(0 .. 100):
    ctx.lineTo(rand(-100 .. 100).float32, rand(-100 .. 100).float32)
  ctx.stroke()

  # image.writeFile("tests/fuzz_leaks.png")
  # break
