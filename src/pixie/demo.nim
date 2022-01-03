import boxy, opengl, pixie, windy

export pixie, windy

var
  window*: Window
  screen*: Image
  ctx*: Context
  bxy: Boxy

proc tick*() =
  ## Called this every frame in a while loop.

  bxy.addImage("screen", ctx.image, genMipmaps = false)

  bxy.beginFrame(window.framebufferSize)
  bxy.drawRect(rect(vec2(0, 0), window.framebufferSize.vec2), color(1, 1, 1, 1))
  bxy.drawImage("screen", vec2(0, 0))
  bxy.endFrame()

  swapBuffers(window)

  pollEvents()

  if window.closeRequested:
    quit()

  ctx.setTransform(scale(vec2(window.contentScale, window.contentScale)))

proc start*(title = "Demo", windowSize = ivec2(800, 600)) =
  ## Start the demo.
  window = newWindow(title, windowSize)
  window.style = Decorated

  makeContextCurrent(window)
  loadExtensions()

  let pixelSize = windowSize.vec2 * window.contentScale
  screen = newImage(pixelSize.x.int, pixelSize.y.int)
  ctx = newContext(screen)
  bxy = newBoxy()
