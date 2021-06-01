import pixie, wNim/wApp, wNim/wFrame, wNim/wImage, wNim/wPaintDC

let
  w = 256
  h = 256

var
  screen = newImage(w, h)
  ctx = newContext(screen)
  frameCount = 0
  image = Image(w, h)
  app = App()
  frame = Frame()

proc draw() =
  # draw shiny sphere on gradient background
  var linerGradient = Paint(kind: pkGradientLinear)
  linerGradient.gradientHandlePositions.add(vec2(0, 0))
  linerGradient.gradientHandlePositions.add(vec2(0, 256))
  linerGradient.gradientStops.add(
    ColorStop(color: rgbx(0, 0, 0, 255), position: 0))
  linerGradient.gradientStops.add(
    ColorStop(color: rgbx(255, 255, 255, 255), position: 1))
  ctx.fillStyle = linerGradient
  ctx.fillRect(0, 0, 256, 256)

  var radialGradient = Paint(kind: pkGradientRadial)
  radialGradient.gradientHandlePositions.add(vec2(128, 128))
  radialGradient.gradientHandlePositions.add(vec2(256, 128))
  radialGradient.gradientHandlePositions.add(vec2(128, 256))
  radialGradient.gradientStops.add(
    ColorStop(color: rgbx(255, 255, 255, 255), position: 0))
  radialGradient.gradientStops.add(
    ColorStop(color: rgbx(0, 0, 0, 255), position: 1))
  ctx.fillStyle = radialGradient
  ctx.fillCircle(vec2(128.0, 128.0 + sin(float(frameCount)/10.0) * 20), 76.8)

  inc frameCount

proc render() =

  proc GdipCreateBitmapFromScan0(width: cint, height: cint, stride: cint,
    format: cint, scan0: pointer, bitmap: pointer): cint
    {.stdcall, discardable, dynlib: "gdiplus", importc.}

  proc GdipDisposeImage(image: pointer): cint
    {.stdcall, discardable, dynlib: "gdiplus", importc.}

  const PixelFormat32bppARGB = 2498570

  GdipDisposeImage(image.mGdipBmp)

  GdipCreateBitmapFromScan0(cint w, cint h, cint w * 4,
    PixelFormat32bppARGB, ctx.image.data[0].addr, addr image.mGdipBmp)

frame.clientSize = (w, h)

frame.startTimer(0.01)

frame.wEvent_Timer do ():
  draw()
  render()
  frame.refresh(false)

frame.wEvent_Paint do ():
  var dc = PaintDC(frame)
  dc.drawImage(image)

frame.show()
app.mainLoop()
