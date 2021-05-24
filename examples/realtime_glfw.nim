## This example show how to have real time pixie using glfw API.

import math, opengl, pixie, staticglfw

let
  w: int32 = 256
  h: int32 = 256

var
  screen = newImage(w, h)
  ctx = newContext(screen)
  frameCount = 0
  window: Window

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

  # update texture with new pixels from surface
  var dataPtr = ctx.image.data[0].addr
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, GLsizei w, GLsizei h, GL_RGBA,
      GL_UNSIGNED_BYTE, dataPtr)

  # draw a quad over the whole screen
  glClear(GL_COLOR_BUFFER_BIT)
  glBegin(GL_QUADS)
  glTexCoord2d(0.0, 0.0); glVertex2d(-1.0, +1.0)
  glTexCoord2d(1.0, 0.0); glVertex2d(+1.0, +1.0)
  glTexCoord2d(1.0, 1.0); glVertex2d(+1.0, -1.0)
  glTexCoord2d(0.0, 1.0); glVertex2d(-1.0, -1.0)
  glEnd()

  inc frameCount
  swapBuffers(window)

if init() == 0:
  quit("Failed to Initialize GLFW.")

windowHint(RESIZABLE, false.cint)
window = createWindow(w.cint, h.cint, "GLFW/Pixie", nil, nil)

makeContextCurrent(window)
loadExtensions()

# allocate a texture and bind it
var dataPtr = ctx.image.data[0].addr
glTexImage2D(GL_TEXTURE_2D, 0, 3, GLsizei w, GLsizei h, 0, GL_RGBA,
    GL_UNSIGNED_BYTE, dataPtr)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP)
glEnable(GL_TEXTURE_2D)

while windowShouldClose(window) != 1:
  pollEvents()
  display()
