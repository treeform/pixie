import bumpy, chroma, pixie/blends, pixie/common, pixie/fonts, pixie/images,
    pixie/masks, pixie/paints, pixie/paths, vmath

## This file provides a Nim version of the Canvas 2D API commonly used on the
## web. The goal is to make picking up Pixie easy for developers familiar with
## using CanvasRenderingContext2D on the web. For more info, see:
## https://developer.mozilla.org/en-US/docs/Web/API/ContextRenderingContext2D

type
  Context* = ref object
    image*: Image
    fillStyle*, strokeStyle*: Paint
    globalAlpha*: float32
    lineWidth*: float32
    miterLimit*: float32
    lineCap*: LineCap
    lineJoin*: LineJoin
    font*: Font
    textAlign*: HAlignMode
    path: Path
    lineDash: seq[float32]
    mat: Mat3
    mask: Mask
    layer: Image
    stateStack: seq[ContextState]

  ContextState = object
    fillStyle, strokeStyle: Paint
    globalAlpha: float32
    lineWidth: float32
    miterLimit: float32
    lineCap: LineCap
    lineJoin: LineJoin
    font: Font
    textAlign: HAlignMode
    lineDash: seq[float32]
    mat: Mat3
    mask: Mask
    layer: Image

  TextMetrics* = object
    width*: float32

proc newContext*(image: Image): Context =
  ## Create a new Context that will draw to the parameter image.
  result = Context()
  result.image = image
  result.mat = mat3()
  result.globalAlpha = 1
  result.lineWidth = 1
  result.miterLimit = 10
  result.fillStyle = Paint(kind: pkSolid, color: rgbx(0, 0, 0, 255))
  result.strokeStyle = Paint(kind: pkSolid, color: rgbx(0, 0, 0, 255))

proc newContext*(width, height: int): Context {.inline.} =
  ## Create a new Context that will draw to a new image of width and height.
  newContext(newImage(width, height))

proc state(ctx: Context): ContextState =
  result.fillStyle = ctx.fillStyle
  result.strokeStyle = ctx.strokeStyle
  result.globalAlpha = ctx.globalAlpha
  result.lineWidth = ctx.lineWidth
  result.miterLimit = ctx.miterLimit
  result.lineCap = ctx.lineCap
  result.lineJoin = ctx.lineJoin
  result.font = ctx.font
  result.textAlign = ctx.textAlign
  result.lineDash = ctx.lineDash
  result.mat = ctx.mat
  result.mask = if ctx.mask != nil: ctx.mask.copy() else: nil

proc save*(ctx: Context) {.inline.} =
  ## Saves the entire state of the context by pushing the current state onto
  ## a stack.
  ctx.stateStack.add(ctx.state())

proc saveLayer*(ctx: Context) =
  ## Saves the entire state of the context by pushing the current state onto
  ## a stack and allocates a new image layer for subsequent drawing. Calling
  ## restore blends the current layer image onto the prior layer or root image.
  var state = ctx.state()
  state.layer = ctx.layer
  ctx.stateStack.add(state)
  ctx.layer = newImage(ctx.image.width, ctx.image.height)

proc restore*(ctx: Context) =
  ## Restores the most recently saved context state by popping the top entry
  ## in the drawing state stack. If there is no saved state, this method does
  ## nothing.
  if ctx.stateStack.len == 0:
    return

  let
    poppedLayer = ctx.layer
    poppedMask = ctx.mask

  let state = ctx.stateStack.pop()
  ctx.fillStyle = state.fillStyle
  ctx.strokeStyle = state.strokeStyle
  ctx.globalAlpha = state.globalAlpha
  ctx.lineWidth = state.lineWidth
  ctx.miterLimit = state.miterLimit
  ctx.lineCap = state.lineCap
  ctx.lineJoin = state.lineJoin
  ctx.font = state.font
  ctx.textAlign = state.textAlign
  ctx.lineDash = state.lineDash
  ctx.mat = state.mat
  ctx.mask = state.mask
  ctx.layer = state.layer

  if poppedLayer != nil: # If there is a layer being popped
    if poppedMask != nil: # If there is a mask, apply it
      poppedLayer.draw(poppedMask)
    if ctx.layer != nil: # If we popped to another layer, draw to it
      ctx.layer.draw(poppedLayer)
    else: # Otherwise draw to the root image
      ctx.image.draw(poppedLayer)

proc fill(ctx: Context, image: Image, path: Path, windingRule: WindingRule) =
  var image = image

  if ctx.globalAlpha != 1:
    ctx.saveLayer()
    image = ctx.layer

  image.fillPath(
    path,
    ctx.fillStyle,
    ctx.mat,
    windingRule
  )

  if ctx.globalAlpha != 1:
    ctx.layer.applyOpacity(ctx.globalAlpha)
    ctx.restore()

proc stroke(ctx: Context, image: Image, path: Path) =
  var image = image

  if ctx.globalAlpha != 1:
    ctx.saveLayer()
    image = ctx.layer

  image.strokePath(
    path,
    ctx.strokeStyle,
    ctx.mat,
    ctx.lineWidth,
    ctx.lineCap,
    ctx.lineJoin,
    ctx.miterLimit,
    ctx.lineDash
  )

  if ctx.globalAlpha != 1:
    ctx.layer.applyOpacity(ctx.globalAlpha)
    ctx.restore()

proc fillText(ctx: Context, image: Image, text: string, at: Vec2) {.inline.} =
  if ctx.font.typeface == nil:
    raise newException(PixieError, "No font has been set on this Context")

  # Canvas positions text relative to the alphabetic baseline by default
  var at = at
  at.y -= round(ctx.font.typeface.ascent * ctx.font.scale)

  ctx.font.paint = ctx.fillStyle

  var image = image

  if ctx.globalAlpha != 1:
    ctx.saveLayer()
    image = ctx.layer

  image.fillText(
    ctx.font,
    text,
    ctx.mat * translate(at),
    hAlign = ctx.textAlign
  )

  if ctx.globalAlpha != 1:
    ctx.layer.applyOpacity(ctx.globalAlpha)
    ctx.restore()

proc strokeText(ctx: Context, image: Image, text: string, at: Vec2) {.inline.} =
  if ctx.font.typeface == nil:
    raise newException(PixieError, "No font has been set on this Context")

  # Canvas positions text relative to the alphabetic baseline by default
  var at = at
  at.y -= round(ctx.font.typeface.ascent * ctx.font.scale)

  ctx.font.paint = ctx.strokeStyle

  var image = image

  if ctx.globalAlpha != 1:
    ctx.saveLayer()
    image = ctx.layer

  image.strokeText(
    ctx.font,
    text,
    ctx.mat * translate(at),
    ctx.lineWidth,
    hAlign = ctx.textAlign,
    lineCap = ctx.lineCap,
    lineJoin = ctx.lineJoin,
    miterLimit = ctx.miterLimit,
    dashes = ctx.lineDash
  )

  if ctx.globalAlpha != 1:
    ctx.layer.applyOpacity(ctx.globalAlpha)
    ctx.restore()

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
  ## Fills the path with the current fillStyle.
  if ctx.mask != nil and ctx.layer == nil:
    ctx.saveLayer()
    ctx.fill(ctx.layer, path, windingRule)
    ctx.restore()
  elif ctx.layer != nil:
    ctx.fill(ctx.layer, path, windingRule)
  else:
    ctx.fill(ctx.image, path, windingRule)

proc fill*(ctx: Context, windingRule = wrNonZero) {.inline.} =
  ## Fills the current path with the current fillStyle.
  ctx.fill(ctx.path, windingRule)

proc clip*(ctx: Context, path: Path, windingRule = wrNonZero) {.inline.} =
  ## Turns the path into the current clipping region. The previous clipping
  ## region, if any, is intersected with the current or given path to create
  ## the new clipping region.
  let mask = newMask(ctx.image.width, ctx.image.height)
  mask.fillPath(path, ctx.mat, windingRule)

  if ctx.mask == nil:
    ctx.mask = mask
  else:
    ctx.mask.draw(mask, blendMode = bmMask)

proc clip*(ctx: Context, windingRule = wrNonZero) {.inline.} =
  ## Turns the current path into the current clipping region. The previous
  ## clipping region, if any, is intersected with the current or given path
  ## to create the new clipping region.
  ctx.clip(ctx.path, windingRule)

proc stroke*(ctx: Context, path: Path) {.inline.} =
  ## Strokes (outlines) the current or given path with the current strokeStyle.
  if ctx.mask != nil and ctx.layer == nil:
    ctx.saveLayer()
    ctx.stroke(ctx.layer, path)
    ctx.restore()
  elif ctx.layer != nil:
    ctx.stroke(ctx.layer, path)
  else:
    ctx.stroke(ctx.image, path)

proc stroke*(ctx: Context) {.inline.} =
  ## Strokes (outlines) the current or given path with the current strokeStyle.
  ctx.stroke(ctx.path)

proc clearRect*(ctx: Context, rect: Rect) =
  ## Erases the pixels in a rectangular area.
  var path: Path
  path.rect(rect)
  if ctx.layer != nil:
    ctx.layer.fillPath(
      path,
      Paint(kind: pkSolid, color: rgbx(0, 0, 0, 0), blendMode: bmOverwrite),
      ctx.mat
    )
  else:
    ctx.image.fillPath(
      path,
      Paint(kind: pkSolid, color: rgbx(0, 0, 0, 0), blendMode: bmOverwrite),
      ctx.mat
    )

proc clearRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ## Erases the pixels in a rectangular area.
  ctx.clearRect(rect(x, y, width, height))

proc fillRect*(ctx: Context, rect: Rect) =
  ## Draws a rectangle that is filled according to the current fillStyle.
  var path: Path
  path.rect(rect)
  ctx.fill(path)

proc fillRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ## Draws a rectangle that is filled according to the current fillStyle.
  ctx.fillRect(rect(x, y, width, height))

proc strokeRect*(ctx: Context, rect: Rect) =
  ## Draws a rectangle that is stroked (outlined) according to the current
  ## strokeStyle and other context settings.
  var path: Path
  path.rect(rect)
  ctx.stroke(path)

proc strokeRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ## Draws a rectangle that is stroked (outlined) according to the current
  ## strokeStyle and other context settings.
  ctx.strokeRect(rect(x, y, width, height))

proc fillText*(ctx: Context, text: string, at: Vec2) =
  ## Draws a text string at the specified coordinates, filling the string's
  ## characters with the current fillStyle
  if ctx.mask != nil and ctx.layer == nil:
    ctx.saveLayer()
    ctx.fillText(ctx.layer, text, at)
    ctx.restore()
  elif ctx.layer != nil:
    ctx.fillText(ctx.layer, text, at)
  else:
    ctx.fillText(ctx.image, text, at)

proc fillText*(ctx: Context, text: string, x, y: float32) {.inline.} =
  ## Draws the outlines of the characters of a text string at the specified
  ## coordinates.
  ctx.fillText(text, vec2(x, y))

proc strokeText*(ctx: Context, text: string, at: Vec2) =
  ## Draws the outlines of the characters of a text string at the specified
  ## coordinates.
  if ctx.mask != nil and ctx.layer == nil:
    ctx.saveLayer()
    ctx.strokeText(ctx.layer, text, at)
    ctx.restore()
  elif ctx.layer != nil:
    ctx.strokeText(ctx.layer, text, at)
  else:
    ctx.strokeText(ctx.image, text, at)

proc strokeText*(ctx: Context, text: string, x, y: float32) {.inline.} =
  ## Draws the outlines of the characters of a text string at the specified
  ## coordinates.
  ctx.strokeText(text, vec2(x, y))

proc measureText*(ctx: Context, text: string): TextMetrics =
  ## Returns a TextMetrics object that contains information about the measured
  ## text (such as its width, for example).
  if ctx.font.typeface == nil:
    raise newException(PixieError, "No font has been set on this Context")

  let bounds = typeset(ctx.font, text).computeBounds()
  result.width = bounds.x

proc getLineDash*(ctx: Context): seq[float32] {.inline.} =
  ctx.lineDash

proc setLineDash*(ctx: Context, lineDash: seq[float32]) {.inline.} =
  ctx.lineDash = lineDash

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
  ## Adds a scaling transformation to the context units horizontally and/or
  ## vertically.
  ctx.mat = ctx.mat * scale(v)

proc scale*(ctx: Context, x, y: float32) {.inline.} =
  ## Adds a scaling transformation to the context units horizontally and/or
  ## vertically.
  ctx.mat = ctx.mat * scale(vec2(x, y))

proc rotate*(ctx: Context, angle: float32) {.inline.} =
  ## Adds a rotation to the transformation matrix.
  ctx.mat = ctx.mat * rotate(-angle)

proc resetTransform*(ctx: Context) {.inline.} =
  ## Resets the current transform to the identity matrix.
  ctx.mat = mat3()

# Additional procs that are not part of the JS API

proc roundedRect*(ctx: Context, x, y, w, h, nw, ne, se, sw: float32) {.inline.} =
  ## Adds a rounded rectangle to the current path.
  ctx.path.roundedRect(x, y, w, h, nw, ne, se, sw)

proc roundedRect*(ctx: Context, rect: Rect, nw, ne, se, sw: float32) {.inline.} =
  ## Adds a rounded rectangle to the current path.
  ctx.path.roundedRect(rect, nw, ne, se, sw)

proc circle*(ctx: Context, cx, cy, r: float32) {.inline.} =
  ## Adds a circle to the current path.
  ctx.path.circle(cx, cy, r)

proc circle*(ctx: Context, center: Vec2, r: float32) {.inline.} =
  ## Adds a circle to the current path.
  ctx.path.circle(center, r)

proc polygon*(ctx: Context, x, y, size: float32, sides: int) {.inline.} =
  ## Adds an n-sided regular polygon at (x, y) of size to the current path.
  ctx.path.polygon(x, y, size, sides)

proc polygon*(ctx: Context, pos: Vec2, size: float32, sides: int) {.inline.} =
  ## Adds an n-sided regular polygon at (x, y) of size to the current path.
  ctx.path.polygon(pos, size, sides)

proc fillRoundedRect*(ctx: Context, rect: Rect, nw, ne, se, sw: float32) =
  ## Draws a rounded rectangle that is filled according to the current fillStyle.
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  ctx.fill(path)

proc fillRoundedRect*(ctx: Context, rect: Rect, radius: float32) {.inline.} =
  ## Draws a rounded rectangle that is filled according to the current fillStyle.
  ctx.fillRoundedRect(rect, radius, radius, radius, radius)

proc strokeRoundedRect*(ctx: Context, rect: Rect, nw, ne, se, sw: float32) =
  ## Draws a rounded rectangle that is stroked (outlined) according to the
  ## current strokeStyle and other context settings.
  var path: Path
  path.roundedRect(rect, nw, ne, se, sw)
  ctx.stroke(path)

proc strokeRoundedRect*(ctx: Context, rect: Rect, radius: float32) {.inline.} =
  ## Draws a rounded rectangle that is stroked (outlined) according to the
  ## current strokeStyle and other context settings.
  ctx.strokeRoundedRect(rect, radius, radius, radius, radius)

proc strokeSegment*(ctx: Context, segment: Segment) =
  ## Strokes a segment (draws a line from segment.at to segment.to) according
  ## to the current strokeStyle and other context settings.
  var path: Path
  path.moveTo(segment.at)
  path.lineTo(segment.to)
  ctx.stroke(path)

proc fillEllipse*(ctx: Context, center: Vec2, rx, ry: float32) =
  ## Draws an ellipse that is filled according to the current fillStyle.
  var path: Path
  path.ellipse(center, rx, ry)
  ctx.fill(path)

proc strokeEllipse*(ctx: Context, center: Vec2, rx, ry: float32) =
  ## Draws an ellipse that is stroked (outlined) according to the current
  ## strokeStyle and other context settings.
  var path: Path
  path.ellipse(center, rx, ry)
  ctx.stroke(path)

proc fillCircle*(ctx: Context, circle: Circle) =
  ## Draws a circle that is filled according to the current fillStyle
  var path: Path
  path.circle(circle.pos, circle.radius)
  ctx.fill(path)

proc fillCircle*(ctx: Context, center: Vec2, radius: float32) =
  ## Draws a circle that is filled according to the current fillStyle.
  var path: Path
  path.ellipse(center, radius, radius)
  ctx.fill(path)

proc strokeCircle*(ctx: Context, circle: Circle) =
  ## Draws a circle that is stroked (outlined) according to the current
  ## strokeStyle and other context settings.
  var path: Path
  path.circle(circle.pos, circle.radius)
  ctx.stroke(path)

proc strokeCircle*(ctx: Context, center: Vec2, radius: float32) =
  ## Draws a circle that is stroked (outlined) according to the current
  ## strokeStyle and other context settings.
  var path: Path
  path.ellipse(center, radius, radius)
  ctx.stroke(path)

proc fillPolygon*(ctx: Context, pos: Vec2, size: float32, sides: int) =
  ## Draws an n-sided regular polygon at (x, y) of size that is filled according
  ## to the current fillStyle.
  var path: Path
  path.polygon(pos, size, sides)
  ctx.fill(path)

proc strokePolygon*(ctx: Context, pos: Vec2, size: float32, sides: int) =
  ## Draws an n-sided regular polygon at (x, y) of size that is stroked
  ## (outlined) according to the current strokeStyle and other context settings.
  var path: Path
  path.polygon(pos, size, sides)
  ctx.stroke(path)
