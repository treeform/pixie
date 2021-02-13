import cairo, math, benchy, pixie, chroma

var
  surface = imageSurfaceCreate(FORMAT_ARGB32, 1000, 1000)
  ctx = surface.create()

ctx.setSourceRgba(0, 0, 0, 1)
ctx.fill()
ctx.setSourceRgba(0, 0, 1, 1)

timeIt "cairo":
  ctx.newPath()
  ctx.moveTo(0, 0)
  ctx.lineTo(500, 0)
  ctx.lineTo(500, 500)
  ctx.lineTo(0, 500)
  ctx.closePath()
  ctx.fill()
  surface.flush()

# discard surface.writeToPng("cairo.png")

var a = newImage(1000, 1000)
a.fill(rgba(0, 0, 0, 255))

timeIt "pixie":
  var p: paths.Path
  p.moveTo(0, 0)
  p.lineTo(500, 0)
  p.lineTo(500, 500)
  p.lineTo(0, 500)
  p.closePath()
  a.fillPath(p, rgba(0, 0, 255, 255))

# a.writeFile("pixie.png")
