import cairo, math, times

var
  surface = imageSurfaceCreate(FORMAT_ARGB32, 256, 256)
  ctx = surface.create()

let start = epochTime()

ctx.setSourceRGB(0, 0, 1)
ctx.newPath()  # current path is not consumed by ctx.clip()
ctx.rectangle(96, 96, 128, 128)
ctx.fill()

ctx.setSourceRGB(0, 1, 0)
ctx.newPath()  # current path is not consumed by ctx.clip()
ctx.rectangle(64, 64, 128, 128)
ctx.fill()

for i in 0 .. 10000:

  ctx.setSourceRGB(1, 0, 0)
  ctx.newPath()  # current path is not consumed by ctx.clip()
  ctx.rectangle(32, 32, 128, 128)
  ctx.fill()

echo epochTime() - start

discard surface.writeToPng("cairotest.png")
