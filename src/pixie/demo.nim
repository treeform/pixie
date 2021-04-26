import opengl, pixie, staticglfw except Image

export pixie, staticglfw except Image

var
  screen* = newImage(800, 600)
  window*: Window

proc getMousePos*(): Vec2 =
  ## Get the mouse position.
  var xpos, ypos: float64
  getCursorPos(window, xpos.addr, ypos.addr)
  vec2(xpos, ypos)

proc isMouseDown*(): bool =
  ## Get if the left mouse button is down.
  getMouseButton(window, MOUSE_BUTTON_LEFT) == PRESS

proc isKeyDown*(keyCode: int): bool =
  ## Get if the key is currently being held down.
  ## See key codes: https://www.glfw.org/docs/3.3/group__keys.html
  ## Examples: KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT
  getKey(window, keyCode.cint) == PRESS

proc tick*() =
  ## Called this every frame in a while loop.

  # Update texture with new pixels from surface.
  var dataPtr = screen.data[0].addr
  glTexSubImage2D(
    GL_TEXTURE_2D, 0, 0, 0,
    screen.width.GLsizei, screen.height.GLsizei,
    GL_RGBA, GL_UNSIGNED_BYTE, dataPtr
  )

  # Draw a quad over the whole screen.
  glClear(GL_COLOR_BUFFER_BIT)
  glBegin(GL_QUADS)
  glTexCoord2d(0.0, 0.0); glVertex2d(-1.0, +1.0)
  glTexCoord2d(1.0, 0.0); glVertex2d(+1.0, +1.0)
  glTexCoord2d(1.0, 1.0); glVertex2d(+1.0, -1.0)
  glTexCoord2d(0.0, 1.0); glVertex2d(-1.0, -1.0)
  glEnd()

  swapBuffers(window)

  pollEvents()

  if windowShouldClose(window) == 1:
    quit()

proc start*(title = "Demo") =
  ## Start the demo.
  if init() == 0:
    quit("Failed to Initialize GLFW.")

  windowHint(RESIZABLE, false.cint)
  window = createWindow(screen.width.cint, screen.height.cint, title, nil, nil)
  if window == nil:
    quit("Failed to create window.")
  makeContextCurrent(window)
  loadExtensions()

  # Allocate a texture and bind it.
  var dataPtr = screen.data[0].addr
  glTexImage2D(
    GL_TEXTURE_2D, 0, 3,
    screen.width.GLsizei, screen.height.GLsizei,
    0, GL_RGBA, GL_UNSIGNED_BYTE, dataPtr
  )
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP)
  glEnable(GL_TEXTURE_2D)
