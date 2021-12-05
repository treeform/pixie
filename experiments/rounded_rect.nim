import benchy, chroma, pixie, pixie/internal, strformat
import benchy, chroma, pixie

proc newRoundedRectImage1(w, h, r: int, color: Color): Image =
  result = newImage(w, h)
  let ctx = newContext(result)
  ctx.fillStyle = color(0, 1, 0, 1)
  let
    pos = vec2(0, 0)
    wh = vec2(w.float32, h.float32)
    r = r.float32
  ctx.fillRoundedRect(rect(pos, wh), r)

proc newRoundedRectImage15(w, h, r: int, color: Color): Image =
  let path = newPath()
  let
    pos = vec2(0, 0)
    wh = vec2(w.float32, h.float32)
    r = r.float32
  path.roundedRect(rect(pos, wh), r, r, r, r)
  result = path.fillImage(w, h, color(0, 1, 0, 1))

proc newRoundedRectImage2(w, h, r: int, color: Color): Image =
  result = newImage(w, h)
  result.fill(color)

  let
    w1 = w - 1
    h1 = h - 1
  for y in 0 ..< r:
    for x in 0 ..< r:
      var a: float32 = 0
      for s in 0 ..< 5:
        let
          yc = y.float32 + s.float32 / 5 + (1 / 5 / 2)
          xc = r.float32 - sqrt(r.float32*r.float32 - (yc - r.float32) ^ 2)
        let mid = (x.float32 - xc + 1).clamp(0, 1)
        a += 1/5 * mid

      if a < 1:
        var c = color
        c.a = a
        let cx = c.rgbx
        result.setRgbaUnsafe(x, y, cx)
        result.setRgbaUnsafe(w1 - x, y, cx)
        result.setRgbaUnsafe(w1 - x, h1 - y, cx)
        result.setRgbaUnsafe(x, h1 - y, cx)

proc newRoundedRectImage3(w, h, r: int, color: Color): Image =
  result = newImage(w, h)
  result.fill(color)

  if r == 0:
    return

  const
    q = 5
    qf = q.float32
    qoffset: float32 = (1 / qf / 2)

  let
    r = r.clamp(0, min(w, h) div 2)
    rf = r.float32
    w1 = w - 1
    h1 = h - 1
    rgbx = color.rgbx
    channels = [rgbx.r.uint32, rgbx.g.uint32, rgbx.b.uint32, rgbx.a.uint32]

  var coverage = newSeq[uint8](r)

  for y in 0 ..< r:
    zeroMem(coverage[0].addr, coverage.len)
    var yf: float32 = y.float32 + qoffset
    for m in 0 ..< q:
      let hit = sqrt(rf^2 - yf^2)
      coverage[hit.int] += max((1 - (hit - hit.trunc)) * 255 / qf, 0).uint8
      for x in hit.int + 1 ..< r:
        coverage[x] += (255 div q).uint8
      yf += 1 / qf

    for x in 0 ..< r:
      let coverage = 255 - coverage[x]
      if coverage != 255:
        var cx: ColorRGBX
        cx.r = ((channels[0] * coverage) div 255).uint8
        cx.g = ((channels[1] * coverage) div 255).uint8
        cx.b = ((channels[2] * coverage) div 255).uint8
        cx.a = ((channels[3] * coverage) div 255).uint8

        let
          xn = r - x - 1
          yn = r - y - 1
        result.setRgbaUnsafe(xn, yn, cx)
        result.setRgbaUnsafe(w1 - xn, yn, cx)
        result.setRgbaUnsafe(w1 - xn, h1 - yn, cx)
        result.setRgbaUnsafe(xn, h1 - yn, cx)

const r = 16

let img1 = newRoundedRectImage1(200, 200, r, color(0, 1, 0, 1))
img1.writeFile("rrect_current.png")
let img2 = newRoundedRectImage3(200, 200, r, color(0, 1, 0, 1))
img2.writeFile("rrect_new.png")

let (diffScore, diffImage) = diff(img1, img2)
echo &"score: {diffScore}"
diffImage.writeFile("rrect_diff.png")

timeIt "fill rounded rect via path 1":
  for i in 0 ..< 10:
    discard newRoundedRectImage1(200, 200, r, color(0, 1, 0, 1))

timeIt "fill rounded rect via path 1.5":
  for i in 0 ..< 10:
    discard newRoundedRectImage15(200, 200, r, color(0, 1, 0, 1))

timeIt "fill rounded rect via math 2":
  for i in 0 ..< 10:
    discard newRoundedRectImage2(200, 200, 50, color(0, 1, 0, 1))

timeIt "fill rounded rect via math 3":
  for i in 0 ..< 10:
    discard newRoundedRectImage3(200, 200, r, color(0, 1, 0, 1))
