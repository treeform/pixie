## This example show how to have real time pixie using sdl2 API.

import math, pixie, sdl2, sdl2/gfx

let
  w: int32 = 256
  h: int32 = 256

var
  screen = newImage(w, h)
  ctx = newContext(screen)
  frameCount = 0
  window: WindowPtr
  render: RendererPtr
  mainSurface: SurfacePtr
  mainTexture: TexturePtr
  evt = sdl2.defaultEvent

proc display() =
  ## Called every frame by main while loop

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

  var dataPtr = ctx.image.data[0].addr
  mainSurface.pixels = dataPtr
  mainTexture = render.createTextureFromSurface(mainSurface)
  render.copy(mainTexture, nil, nil)
  render.present()

discard sdl2.init(INIT_EVERYTHING)
window = createWindow("SDL/Pixie", 100, 100, cint w, cint h, SDL_WINDOW_SHOWN)
const
  rmask = uint32 0x000000ff
  gmask = uint32 0x0000ff00
  bmask = uint32 0x00ff0000
  amask = uint32 0xff000000
mainSurface = createRGBSurface(0, cint w, cint h, 32, rmask, gmask, bmask, amask)

render = createRenderer(window, -1, 0)

while true:
  while pollEvent(evt):
    if evt.kind == QuitEvent:
      quit(0)
  display()
  delay(14)
