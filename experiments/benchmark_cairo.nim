import benchy, cairo, chroma, math, pixie

block:
  var
    surface = imageSurfaceCreate(FORMAT_ARGB32, 1920, 1080)
    ctx = surface.create()

  ctx.setSourceRgba(0, 0, 1, 1)

  timeIt "cairo1":
    ctx.newPath()
    ctx.moveTo(0, 0)
    ctx.lineTo(1920, 0)
    ctx.lineTo(1920, 1080)
    ctx.lineTo(0, 1080)
    ctx.closePath()
    ctx.fill()
    surface.flush()

  # discard surface.writeToPng("cairo1.png")

  var a = newImage(1920, 1080)
  a.fill(rgba(255, 255, 255, 255))

  timeIt "pixie1":
    var p: pixie.Path
    p.moveTo(0, 0)
    p.lineTo(1920, 0)
    p.lineTo(1920, 1080)
    p.lineTo(0, 1080)
    p.closePath()
    a.fillPath(p, rgba(0, 0, 255, 255))

  # a.writeFile("pixie1.png")

block:
  var
    surface = imageSurfaceCreate(FORMAT_ARGB32, 1920, 1080)
    ctx = surface.create()

  ctx.setSourceRgba(0, 0, 1, 1)

  timeIt "cairo2":
    ctx.newPath()
    ctx.moveTo(500, 240)
    ctx.lineTo(1500, 240)
    ctx.lineTo(1920, 600)
    ctx.lineTo(0, 600)
    ctx.closePath()
    ctx.fill()
  surface.flush()

  # discard surface.writeToPng("cairo2.png")

  var a = newImage(1920, 1080)
  a.fill(rgba(255, 255, 255, 255))

  timeIt "pixie2":
    var p: pixie.Path
    p.moveTo(500, 240)
    p.lineTo(1500, 240)
    p.lineTo(1920, 600)
    p.lineTo(0, 600)
    p.closePath()
    a.fillPath(p, rgba(0, 0, 255, 255))

  # a.writeFile("pixie2.png")
