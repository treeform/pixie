import benchy, cairo, chroma, math, pixie

block:
  let
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

  let a = newImage(1920, 1080)
  a.fill(rgba(255, 255, 255, 255))

  timeIt "pixie1":
    let p = newPath()
    p.moveTo(0, 0)
    p.lineTo(1920, 0)
    p.lineTo(1920, 1080)
    p.lineTo(0, 1080)
    p.closePath()
    a.fillPath(p, rgba(0, 0, 255, 255))

  # a.writeFile("pixie1.png")

block:
  let
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

  let a = newImage(1920, 1080)
  a.fill(rgba(255, 255, 255, 255))

  timeIt "pixie2":
    let p = newPath()
    p.moveTo(500, 240)
    p.lineTo(1500, 240)
    p.lineTo(1920, 600)
    p.lineTo(0, 600)
    p.closePath()
    a.fillPath(p, rgba(0, 0, 255, 255))

  # a.writeFile("pixie2.png")

# block:
#   let
#     a = imageSurfaceCreate(FORMAT_ARGB32, 1000, 1000)
#     b = imageSurfaceCreate(FORMAT_ARGB32, 500, 500)
#     ac = a.create()
#     bc = b.create()

#   ac.setSourceRgba(1, 0, 0, 1)
#   ac.newPath()
#   ac.rectangle(0, 0, 1000, 1000)
#   ac.fill()

#   bc.setSourceRgba(0, 1, 0, 1)
#   bc.newPath()
#   bc.rectangle(0, 0, 500, 500)
#   bc.fill()

#   let pattern = patternCreateForSurface(b)

#   timeIt "a":
#     ac.setSource(pattern)
#     ac.save()
#     ac.translate(25.2, 25.2)
#     ac.rectangle(0, 0, 500, 500)
#     ac.fill()
#     ac.restore()

#   discard a.writeToPng("a.png")
