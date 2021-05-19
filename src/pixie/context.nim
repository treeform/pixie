import bumpy, chroma, pixie/blends, pixie/common, pixie/fonts, pixie/images,
    pixie/paints, pixie/paths, vmath

## This file provides a Nim version of the Canvas 2D API commonly used on the
## web. The goal is to make picking up Pixie easy for developers familiar with
## using CanvasRenderingContext2D on the web. For more info, see:
## https://developer.mozilla.org/en-US/docs/Web/API/ContextRenderingContext2D

type
  Context* = ref object
    image*: Image
    fillStyle*, strokeStyle*: Paint
    lineWidth*: float32
    lineCap*: LineCap
    lineJoin*: LineJoin
    font*: Font
    textAlign*: HAlignMode
    path: Path
    mat: Mat3
    stateStack: seq[ContextState]

  ContextState = object
    mat: Mat3
    fillStyle, strokeStyle: Paint
    lineWidth: float32
    lineCap: LineCap
    lineJoin: LineJoin
    font: Font
    textAlign: HAlignMode

proc newContext*(image: Image): Context =
  ## Create a new Context that will draw to the parameter image.
  result = Context()
  result.image = image
  result.mat = mat3()
  result.lineWidth = 1
  result.fillStyle = Paint(kind: pkSolid, color: rgbx(0, 0, 0, 255))
  result.strokeStyle = Paint(kind: pkSolid, color: rgbx(0, 0, 0, 255))

proc newContext*(width, height: int): Context {.inline.} =
  ## Create a new Context that will draw to a new image of width and height.
  newContext(newImage(width, height))

proc beginPath*(ctx: Context) {.inline.} =
  ## Starts a new path by emptying the list of sub-paths.
  ctx.path = Path()

proc moveTo*(ctx: Context, v: Vec2) {.inline.} =
  ## Begins a new sub-path at the point (x, y).
  ctx.path.moveTo(v)

proc moveTo*(ctx: Context, x, y: float32) {.inline.} =
  ## Begins a new sub-path at the point (x, y).
  ctx.moveTo(vec2(x, y))

proc lineTo*(ctx: Context, v: Vec2) {.inline.} =
  ## Adds a straight line to the current sub-path by connecting the sub-path's
  ## last point to the specified (x, y) coordinates.
  ctx.path.lineTo(v)

proc lineTo*(ctx: Context, x, y: float32) {.inline.} =
  ## Adds a straight line to the current sub-path by connecting the sub-path's
  ## last point to the specified (x, y) coordinates.
  ctx.lineTo(vec2(x, y))

proc bezierCurveTo*(ctx: Context, cp1, cp2, to: Vec2) {.inline.} =
  ## Adds a cubic Bézier curve to the current sub-path. It requires three
  ## points: the first two are control points and the third one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the Bézier curve.
  ctx.path.bezierCurveTo(cp1, cp2, to)

proc bezierCurveTo*(
  ctx: Context, cp1x, cp1y, cp2x, cp2y, x, y: float32
) {.inline.} =
  ## Adds a cubic Bézier curve to the current sub-path. It requires three
  ## points: the first two are control points and the third one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the Bézier curve.
  ctx.bezierCurveTo(vec2(cp1x, cp1y), vec2(cp2x, cp2y), vec2(x, y))

proc quadraticCurveTo*(ctx: Context, cpx, cpy, x, y: float32) {.inline.} =
  ## Adds a quadratic Bézier curve to the current sub-path. It requires two
  ## points: the first one is a control point and the second one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the quadratic
  ## Bézier curve.
  ctx.path.quadraticCurveTo(cpx, cpy, x, y)

proc quadraticCurveTo*(ctx: Context, ctrl, to: Vec2) {.inline.} =
  ## Adds a quadratic Bézier curve to the current sub-path. It requires two
  ## points: the first one is a control point and the second one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the quadratic
  ## Bézier curve.
  ctx.path.quadraticCurveTo(ctrl, to)

proc closePath*(ctx: Context) {.inline.} =
  ## Attempts to add a straight line from the current point to the start of
  ## the current sub-path. If the shape has already been closed or has only
  ## one point, this function does nothing.
  ctx.path.closePath()

proc rect*(ctx: Context, rect: Rect) {.inline.} =
  ## Adds a rectangle to the current path.
  ctx.path.rect(rect)

proc rect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ## Adds a rectangle to the current path.
  ctx.path.rect(x, y, width, height)

proc ellipse*(ctx: Context, center: Vec2, rx, ry: float32) {.inline.} =
  ## Adds an ellipse to the current sub-path.
  ctx.path.ellipse(center, rx, ry)

proc ellipse*(ctx: Context, x, y, rx, ry: float32) {.inline.} =
  ## Adds an ellipse to the current sub-path.
  ctx.path.ellipse(x, y, rx, ry)

proc fill*(ctx: Context, path: Path, windingRule = wrNonZero) {.inline.} =
  ## Fills the current or given path with the current fillStyle.
  ctx.image.fillPath(
    path,
    ctx.fillStyle,
    ctx.mat,
    windingRule = windingRule
  )

proc fill*(ctx: Context, windingRule = wrNonZero) {.inline.} =
  ## Fills the current or given path with the current fillStyle.
  ctx.fill(ctx.path, windingRule)

proc stroke*(ctx: Context, path: Path) {.inline.} =
  ## Strokes (outlines) the current or given path with the current strokeStyle.
  ctx.image.strokePath(
    path,
    ctx.strokeStyle,
    ctx.mat,
    strokeWidth = ctx.lineWidth,
    lineCap = ctx.lineCap,
    lineJoin = ctx.lineJoin
  )

proc stroke*(ctx: Context) {.inline.} =
  ## Strokes (outlines) the current or given path with the current strokeStyle.
  ctx.stroke(ctx.path)

proc clearRect*(ctx: Context, rect: Rect) =
  ## Erases the pixels in a rectangular area.
  var path: Path
  path.rect(rect)
  ctx.image.fillPath(path, rgbx(0, 0, 0, 0), ctx.mat, blendMode = bmOverwrite)

proc clearRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ## Erases the pixels in a rectangular area.
  ctx.clearRect(rect(x, y, width, height))

proc fillRect*(ctx: Context, rect: Rect) =
  ## Draws a rectangle that is filled according to the current fillStyle.
  var path: Path
  path.rect(rect)
  ctx.image.fillPath(path, ctx.fillStyle, ctx.mat)

proc fillRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ## Draws a rectangle that is filled according to the current fillStyle.
  ctx.fillRect(rect(x, y, width, height))

proc strokeRect*(ctx: Context, rect: Rect) =
  ## Draws a rectangle that is stroked (outlined) according to the current
  ## strokeStyle and other context settings.
  var path: Path
  path.rect(rect)
  ctx.image.strokePath(
    path,
    ctx.strokeStyle,
    ctx.mat,
    ctx.lineWidth,
    ctx.lineCap,
    ctx.lineJoin
  )

proc strokeRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ## Draws a rectangle that is stroked (outlined) according to the current
  ## strokeStyle and other context settings.
  ctx.strokeRect(rect(x, y, width, height))

proc fillText*(ctx: Context, text: string, at: Vec2) =
  ## Draws a text string at the specified coordinates, filling the string's
  ## characters with the current fillStyle

  if ctx.font.typeface == nil:
    raise newException(PixieError, "No font has been set on this Context")

  # Canvas positions text relative to the alphabetic baseline by default
  var at = at
  at.y -= round(ctx.font.typeface.ascent * ctx.font.scale)

  ctx.font.paint = ctx.fillStyle
  ctx.image.fillText(
    ctx.font,
    text,
    ctx.mat * translate(at),
    hAlign = ctx.textAlign
  )

proc fillText*(ctx: Context, text: string, x, y: float32) {.inline.} =
  ## Draws the outlines of the characters of a text string at the specified
  ## coordinates.
  ctx.fillText(text, vec2(x, y))

proc strokeText*(ctx: Context, text: string, at: Vec2) =
  ## Draws the outlines of the characters of a text string at the specified
  ## coordinates.

  if ctx.font.typeface == nil:
    raise newException(PixieError, "No font has been set on this Context")

  # Canvas positions text relative to the alphabetic baseline by default
  var at = at
  at.y -= round(ctx.font.typeface.ascent * ctx.font.scale)

  ctx.font.paint = ctx.strokeStyle
  ctx.image.strokeText(
    ctx.font,
    text,
    ctx.mat * translate(at),
    ctx.lineWidth,
    hAlign = ctx.textAlign,
    lineCap = ctx.lineCap,
    lineJoin = ctx.lineJoin
  )

proc strokeText*(ctx: Context, text: string, x, y: float32) {.inline.} =
  ## Draws the outlines of the characters of a text string at the specified
  ## coordinates.
  ctx.strokeText(text, vec2(x, y))

proc getTransform*(ctx: Context): Mat3 {.inline.} =
  ## Retrieves the current transform matrix being applied to the context.
  ctx.mat

proc setTransform*(ctx: Context, transform: Mat3) {.inline.} =
  ## Overrides the transform matrix being applied to the context.
  ctx.mat = transform

proc setTransform*(ctx: Context, a, b, c, d, e, f: float32) {.inline.} =
  ## Overrides the transform matrix being applied to the context.
  ctx.mat = mat3(a, b, 0, c, d, 0, e, f, 1)

proc transform*(ctx: Context, transform: Mat3) {.inline.} =
  ## Multiplies the current transform with the matrix described by the
  ## arguments of this method.
  ctx.mat = ctx.mat * transform

proc transform*(ctx: Context, a, b, c, d, e, f: float32) {.inline.} =
  ## Multiplies the current transform with the matrix described by the
  ## arguments of this method.
  ctx.transform(mat3(a, b, 0, c, d, 0, e, f, 1))

proc translate*(ctx: Context, v: Vec2) {.inline.} =
  ## Adds a translation transformation to the current matrix.
  ctx.mat = ctx.mat * translate(v)

proc translate*(ctx: Context, x, y: float32) {.inline.} =
  ## Adds a translation transformation to the current matrix.
  ctx.mat = ctx.mat * translate(vec2(x, y))

proc scale*(ctx: Context, v: Vec2) {.inline.} =
  ## Adds a scaling transformation to the canvas units horizontally and/or
  ## vertically.
  ctx.mat = ctx.mat * scale(v)

proc scale*(ctx: Context, x, y: float32) {.inline.} =
  ## Adds a scaling transformation to the canvas units horizontally and/or
  ## vertically.
  ctx.mat = ctx.mat * scale(vec2(x, y))

proc rotate*(ctx: Context, angle: float32) {.inline.} =
  ## Adds a rotation to the transformation matrix.
  ctx.mat = ctx.mat * rotate(-angle)

proc resetTransform*(ctx: Context) {.inline.} =
  ## Resets the current transform to the identity matrix.
  ctx.mat = mat3()

proc save*(ctx: Context) =
  ## Saves the entire state of the canvas by pushing the current state onto
  ## a stack.
  var state: ContextState
  state.mat = ctx.mat
  state.fillStyle = ctx.fillStyle
  state.strokeStyle = ctx.strokeStyle
  state.lineWidth = ctx.lineWidth
  state.lineCap = ctx.lineCap
  state.lineJoin = ctx.lineJoin
  state.font = ctx.font
  state.textAlign = ctx.textAlign
  ctx.stateStack.add(state)

proc restore*(ctx: Context) =
  ## Restores the most recently saved canvas state by popping the top entry
  ## in the drawing state stack. If there is no saved state, this method does
  ## nothing.
  if ctx.stateStack.len > 0:
    let state = ctx.stateStack.pop()
    ctx.mat = state.mat
    ctx.fillStyle = state.fillStyle
    ctx.strokeStyle = state.strokeStyle
    ctx.lineWidth = state.lineWidth
    ctx.lineCap = state.lineCap
    ctx.lineJoin = state.lineJoin
    ctx.font = state.font
    ctx.textAlign = state.textAlign
