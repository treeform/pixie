## This example show how to have real time pixie using the X11 API.

import math, pixie, x11/[x, xlib], std/os

let
  w: int32 = 256
  h: int32 = 256

var
  screen = newImage(w, h)
  ctx = newContext(screen)

var
  display: PDisplay
  window: Window
  deleteMessage: Atom
  graphicsContext: GC
  frameCount = 0


proc render() =
  ## Called every frame by main while loop
  
  # draw shiny sphere on gradient background
  let linerGradient = newPaint(pkGradientLinear)
  linerGradient.gradientHandlePositions.add(vec2(0, 0))
  linerGradient.gradientHandlePositions.add(vec2(0, 256))
  linerGradient.gradientStops.add(
    ColorStop(color: pixie.color(0, 0, 0, 1), position: 0))
  linerGradient.gradientStops.add(
    ColorStop(color: pixie.color(1, 1, 1, 1), position: 1))
  ctx.fillStyle = linerGradient
  ctx.fillRect(0, 0, 256, 256)
  let radialGradient = newPaint(pkGradientRadial)
  radialGradient.gradientHandlePositions.add(vec2(128, 128))
  radialGradient.gradientHandlePositions.add(vec2(256, 128))
  radialGradient.gradientHandlePositions.add(vec2(128, 256))
  radialGradient.gradientStops.add(
    ColorStop(color: pixie.color(1, 1, 1, 1), position: 0))
  radialGradient.gradientStops.add(
    ColorStop(color: pixie.color(0, 0, 0, 1), position: 1))
  ctx.fillStyle = radialGradient
  ctx.fillCircle(circle(
    vec2(128.0, 128.0 + sin(float32(frameCount)/10.0) * 20),
    76.8
  ))
  inc frameCount
  var frameBuffer = addr ctx.image.data[0]
  let image = XCreateImage(display, DefaultVisualOfScreen(
      DefaultScreenOfDisplay(display)), 24, ZPixmap, 0, cast[cstring](
      frameBuffer), w.cuint, h.cuint, 8, w*4)
  discard XPutImage(display, window, graphicsContext, image, 0, 0, 0, 0, w.cuint, h.cuint)

import
  x11/xlib,
  x11/xutil,
  x11/x

const
  borderWidth = 0
  eventMask = ButtonPressMask or KeyPressMask or ExposureMask

proc init() =
  display = XOpenDisplay(nil)
  if display == nil:
    quit "Failed to open display"

  let
    screen = XDefaultScreen(display)
    rootWindow = XRootWindow(display, screen)
    foregroundColor = XBlackPixel(display, screen)
    backgroundColor = XWhitePixel(display, screen)

  window = XCreateSimpleWindow(display, rootWindow, -1, -1, w.cuint, h.cuint,
      borderWidth, foregroundColor, backgroundColor)


  discard XSetStandardProperties(display, window, "X11 Example", "window", 0,
      nil, 0, nil)

  discard XSelectInput(display, window, eventMask)
  discard XMapWindow(display, window)

  deleteMessage = XInternAtom(display, "WM_DELETE_WINDOW", false.XBool)
  discard XSetWMProtocols(display, window, deleteMessage.addr, 1)

  graphicsContext = XDefaultGC(display, screen)


proc mainLoop() =
  ## Process events until the quit event is received
  var event: XEvent
  var exposed: bool = false
  while true:
    if exposed: render()
    if XPending(display) > 0:
      discard XNextEvent(display, event.addr)
      case event.theType
      of Expose:
        render()
        exposed = true
      of ClientMessage:
        if cast[Atom](event.xclient.data.l[0]) == deleteMessage:
          break
      of KeyPress:
        let key = XLookupKeysym(cast[PXKeyEvent](event.addr), 0)
        if key != 0:
          echo "Key ", key, " pressed"
      of ButtonPressMask:
        echo "Mouse button ", event.xbutton.button, " pressed at ",
            event.xbutton.x, ",", event.xbutton.y
      else:
        discard
    sleep 14

proc main() =
  init()
  mainLoop()
  discard XDestroyWindow(display, window)
  discard XCloseDisplay(display)

main()
