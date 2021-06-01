## This example show how to have real time pixie using win32 API.

import pixie, winim/lean

let
  w: int32 = 256
  h: int32 = 256

var
  screen = newImage(w, h)
  ctx = newContext(screen)
  frameCount = 0
  hwnd: HWND
  running = true

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

  # Draw image pixels onto win32 window.
  let
    w = screen.width.int32
    h = screen.height.int32
    dc = GetDC(hwnd)
  var info = BITMAPINFO()
  info.bmiHeader.biBitCount = 32
  info.bmiHeader.biWidth = w
  info.bmiHeader.biHeight = h
  info.bmiHeader.biPlanes = 1
  info.bmiHeader.biSize = DWORD sizeof(BITMAPINFOHEADER)
  info.bmiHeader.biSizeImage = w * h * 4
  info.bmiHeader.biCompression = BI_RGB
  var bgrBuffer = newSeq[uint8](screen.data.len * 4)
  # Convert to BGRA.
  for i, c in screen.data:
    bgrBuffer[i*4+0] = c.b
    bgrBuffer[i*4+1] = c.g
    bgrBuffer[i*4+2] = c.r
  discard StretchDIBits(
    dc,
    0,
    h - 1,
    w,
    -h,
    0,
    0,
    w,
    h,
    bgrBuffer[0].addr,
    info,
    DIB_RGB_COLORS,
    SRCCOPY
  )
  discard ReleaseDC(hwnd, dc)

proc windowProc(hwnd: HWND, message: UINT, wParam: WPARAM,
    lParam: LPARAM): LRESULT {.stdcall.} =
  case message
  of WM_DESTROY:
    PostQuitMessage(0)
    running = false
    return 0
  else:
    return DefWindowProc(hwnd, message, wParam, lParam)

proc main() =
  var
    hInstance = GetModuleHandle(nil)
    appName = "Win32/Pixie"
    msg: MSG
    wndclass: WNDCLASS

  wndclass.style = CS_HREDRAW or CS_VREDRAW
  wndclass.lpfnWndProc = windowProc
  wndclass.cbClsExtra = 0
  wndclass.cbWndExtra = 0
  wndclass.hInstance = hInstance
  wndclass.hIcon = LoadIcon(0, IDI_APPLICATION)
  wndclass.hCursor = LoadCursor(0, IDC_ARROW)
  wndclass.hbrBackground = GetStockObject(WHITE_BRUSH)
  wndclass.lpszMenuName = nil
  wndclass.lpszClassName = appName

  if RegisterClass(wndclass) == 0:
    MessageBox(0, "This program requires Windows NT!", appName, MB_ICONERROR)
    return

  # Figure out the right size of the window we want.
  var rect: lean.RECT
  rect.left = 0
  rect.top = 0
  rect.right = w
  rect.bottom = h
  AdjustWindowRectEx(cast[LPRECT](rect.addr), WS_OVERLAPPEDWINDOW, 0, 0)

  # Open the window.
  hwnd = CreateWindow(
    appName,
    "Win32/Pixie",
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    rect.right - rect.left,
    rect.bottom - rect.top,
    0,
    0,
    hInstance,
    nil
  )

  ShowWindow(hwnd, SW_SHOW)
  UpdateWindow(hwnd)

  while running:
    draw()
    PeekMessage(msg, 0, 0, 0, PM_REMOVE)
    TranslateMessage(msg)
    DispatchMessage(msg)

main()
