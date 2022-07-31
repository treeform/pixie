import pixie, random

randomize()

for i in 0 ..< 250:
  let a = newImage(rand(1 .. 20), rand(1 .. 20))
  for j in 0 ..< 25:
    let b = newImage(rand(1 .. 20), rand(1 .. 20))

    let translation = vec2(rand(-25..25).float32, rand(-25..25).float32)

    echo a, " ", b, " ", translation

    a.draw(b, translate(vec2(translation.x.trunc, translation.y.trunc)))
    a.draw(b, translate(translation))

for i in 0 ..< 250:
  let a = newImage(rand(1 .. 2000), rand(1 .. 2000))
  for j in 0 ..< 25:
    let b = newImage(rand(1 .. 1000), rand(1 .. 1000))

    let translation = vec2(rand(-2500..2500).float32, rand(-2500..2500).float32)

    echo a, " ", b, " ", translation

    a.draw(b, translate(vec2(translation.x.trunc, translation.y.trunc)))
    a.draw(b, translate(translation))

for i in 0 ..< 25:
  let a = newImage(rand(1 .. 20), rand(1 .. 20))
  for j in 0 ..< 25:
    let b = newImage(rand(1 .. 20), rand(1 .. 20))

    let
      translation = vec2(rand(25.0), rand(25.0)) - vec2(5, 5)
      rotation = rand(2 * PI).float32

    echo a, " ", b, " ", translation, " ", rotation

    a.draw(b, translate(vec2(translation.x, translation.y)))
    a.draw(b, translate(translation) * rotate(rotation))

for i in 0 ..< 25:
  let a = newImage(rand(1 .. 2000), rand(1 .. 2000))
  for j in 0 ..< 25:
    let b = newImage(rand(1 .. 1000), rand(1 .. 1000))

    let
      translation = vec2(rand(2500.0), rand(2500.0)) - vec2(500, 500)
      rotation = rand(2 * PI).float32

    echo a, " ", b, " ", translation, " ", rotation

    a.draw(b, translate(vec2(translation.x, translation.y)))
    a.draw(b, translate(translation) * rotate(rotation))
