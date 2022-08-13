import pixie, pixie/images {.all.}, random

var totalScore = 0f

# var transform = mat3(
#   -0.6151646375656128, 0.7883986830711365, 0.0,
#   -0.7883986830711365, -0.6151646375656128, 0.0,
#   35.54973220825195, 88.14907836914063, 1.0
# )
# var bestScore = 10000f
# var bestF = vec2(-1, 1)
# for i in 0 .. 10000:
#   var rotOnly = transform
#   var f = bestF + vec2(rand(-0.1f .. 0.1f), rand(-0.1f .. 0.1f))
#   rotOnly.pos = f
#   var value = rotOnly * vec2(-1, 1)

#   let score = (value - vec2(-1.2, -0.4)).length
#   if score < bestScore:
#     bestScore = score
#     bestF = f
#     echo bestScore, " ", bestF
# quit()

for i in 0 ..< 1000:
  echo i
  randomize(i)

  let a = newImage(100, 100)
  a.fill(rgbx(255, 255, 255, 255))

  let b = newImage(rand(1 .. 20), rand(1 .. 20))

  let
    pos = vec2(rand(-10f .. 110f), rand(-10f .. 110f))
    th = rand(2 * PI).float32 + 4.1f
    s = rand(0.1 .. 3.0).float32
    # mat = translate(pos) * rotate(th) * scale(vec2(s, s))
    mat = translate(pos) * rotate(th) * scale(vec2(s, s))

  echo a, " ", b, " ", (pos, th, s)

  b.fill(rgbx(0, 0, 0, 255))

  a.drawCorrect(b, mat, NormalBlend, false)

  b.fill(rgbx(0, 0, 0, 255))
  a.draw(b, mat)

  let c = newImage(a.width, a.height)
  c.fill(rgbx(255, 255, 255, 255))
  let path = newPath()
  path.rect(0, 0, b.width.float32, b.height.float32)

  c.fillPath(path, rgbx(0, 0, 0, 255), mat)

  let (score, image) = diff(a, c)
  echo "score -> ", score

  a.writeFile("a.png")
  c.writeFile("b.png")
  image.writeFile("xray.png")

  totalScore += score

  if score > 0.4:
    break

  break


echo "totalScore -> ", totalScore
