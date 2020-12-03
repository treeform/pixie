import staticglfw, opengl, pixie, times

if init() == 0:
  raise newException(Exception, "Failed to Initialize GLFW")
windowHint(VISIBLE, false.cint)
var window = createWindow(512, 512, "GLFW3 WINDOW", nil, nil)
window.makeContextCurrent()
# This must be called to make any GL function work
loadExtensions()


let start = epochTime()

# Draw red color screen.
glClearColor(1, 1, 1, 1)
glClear(GL_COLOR_BUFFER_BIT)

glLoadIdentity()
glTranslatef(-0.25, -0.25, 0)
glBegin(GL_QUADS)
glColor3f(1.0, 0.0, 0.0)
glVertex2f(0.0, 0.0)
glVertex2f(1.0, 0.0)
glVertex2f(1.0, 1.0)
glVertex2f(0.0, 1.0)
glEnd()

glTranslatef(-0.25, -0.25, 0)
glBegin(GL_QUADS)
glColor3f(0.0, 0.0, 1.0)
glVertex2f(0.0, 0.0)
glVertex2f(1.0, 0.0)
glVertex2f(1.0, 1.0)
glVertex2f(0.0, 1.0)
glEnd()

glTranslatef(-0.25, -0.25, 0)
glBegin(GL_QUADS)
glColor3f(0.0, 1.0, 0.0)
glVertex2f(0.0, 0.0)
glVertex2f(1.0, 0.0)
glVertex2f(1.0, 1.0)
glVertex2f(0.0, 1.0)
glEnd()

var screen = newImage(512, 512)
glReadPixels(
  0, 0,
  512, 512,
  GL_RGBA, GL_UNSIGNED_BYTE,
  screen.data[0].addr
)

echo epochTime() - start


screen.writeFile("screen.png")
