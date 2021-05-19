import bumpy, chroma, pixie/blends, pixie/common, pixie/fonts, pixie/images,
    pixie/paints, pixie/paths, vmath

# https://developer.mozilla.org/en-US/docs/Web/API/ContextRenderingContext2D

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
  result = Context()
  result.image = image
  result.mat = mat3()
  result.lineWidth = 1
  result.fillStyle = Paint(kind: pkSolid, color: rgbx(0, 0, 0, 255))
  result.strokeStyle = Paint(kind: pkSolid, color: rgbx(0, 0, 0, 255))

proc beginPath*(ctx: Context) {.inline.} =
  ctx.path = Path()

proc moveTo*(ctx: Context, v: Vec2) {.inline.} =
  ctx.path.moveTo(v)

proc moveTo*(ctx: Context, x, y: float32) {.inline.} =
  ctx.moveTo(vec2(x, y))

proc lineTo*(ctx: Context, v: Vec2) {.inline.} =
  ctx.path.lineTo(v)

proc lineTo*(ctx: Context, x, y: float32) {.inline.} =
  ctx.lineTo(vec2(x, y))

proc bezierCurveTo*(ctx: Context, cp1, cp2, to: Vec2) {.inline.} =
  ctx.path.bezierCurveTo(cp1, cp2, to)

proc bezierCurveTo*(
  ctx: Context, cp1x, cp1y, cp2x, cp2y, x, y: float32
) {.inline.} =
  ctx.bezierCurveTo(vec2(cp1x, cp1y), vec2(cp2x, cp2y), vec2(x, y))

proc quadraticCurveTo*(ctx: Context, cpx, cpy, x, y: float32) {.inline.} =
  ctx.path.quadraticCurveTo(cpx, cpy, x, y)

proc quadraticCurveTo*(ctx: Context, ctrl, to: Vec2) {.inline.} =
  ctx.path.quadraticCurveTo(ctrl, to)

proc closePath*(ctx: Context) {.inline.} =
  ctx.path.closePath()

proc rect*(ctx: Context, rect: Rect) {.inline.} =
  ctx.path.rect(rect)

proc rect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ctx.path.rect(x, y, width, height)

proc ellipse*(ctx: Context, center: Vec2, rx, ry: float32) {.inline.} =
  ctx.path.ellipse(center, rx, ry)

proc ellipse*(ctx: Context, x, y, rx, ry: float32) {.inline.} =
  ctx.path.ellipse(x, y, rx, ry)

proc fill*(ctx: Context, path: Path, windingRule = wrNonZero) {.inline.} =
  ctx.image.fillPath(
    path,
    ctx.fillStyle,
    ctx.mat,
    windingRule = windingRule
  )

proc fill*(ctx: Context, windingRule = wrNonZero) {.inline.} =
  ctx.fill(ctx.path, windingRule)

proc stroke*(ctx: Context, path: Path) {.inline.} =
  ctx.image.strokePath(
    path,
    ctx.strokeStyle,
    ctx.mat,
    strokeWidth = ctx.lineWidth,
    lineCap = ctx.lineCap,
    lineJoin = ctx.lineJoin
  )

proc stroke*(ctx: Context) {.inline.} =
  ctx.stroke(ctx.path)

proc clearRect*(ctx: Context, rect: Rect) =
  var path: Path
  path.rect(rect)
  ctx.image.fillPath(path, rgbx(0, 0, 0, 0), ctx.mat, blendMode = bmOverwrite)

proc clearRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ctx.clearRect(rect(x, y, width, height))

proc fillRect*(ctx: Context, rect: Rect) =
  var path: Path
  path.rect(rect)
  ctx.image.fillPath(path, ctx.fillStyle, ctx.mat)

proc fillRect*(ctx: Context, x, y, width, height: float32) {.inline.} =
  ctx.fillRect(rect(x, y, width, height))

proc strokeRect*(ctx: Context, rect: Rect) =
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
  ctx.strokeRect(rect(x, y, width, height))

proc fillText*(ctx: Context, text: string, at: Vec2) =
  if ctx.font.typeface == nil:
    raise newException(PixieError, "No font has been set on this Context")

  # Canvas positions text relative to the alphabetic baseline by default
  var at = at
  at.y -= round(ctx.font.typeface.ascent * ctx.font.scale)

  ctx.font.paint = ctx.fillStyle
  ctx.image.fillText(
    ctx.font,
    text,
    at,
    hAlign = ctx.textAlign
  )

proc fillText*(ctx: Context, text: string, x, y: float32) {.inline.} =
  ctx.fillText(text, vec2(x, y))

proc strokeText*(ctx: Context, text: string, at: Vec2) =
  if ctx.font.typeface == nil:
    raise newException(PixieError, "No font has been set on this Context")

  # Canvas positions text relative to the alphabetic baseline by default
  var at = at
  at.y -= round(ctx.font.typeface.ascent * ctx.font.scale)

  ctx.font.paint = ctx.strokeStyle
  ctx.image.strokeText(
    ctx.font,
    text,
    at,
    ctx.lineWidth,
    hAlign = ctx.textAlign,
    lineCap = ctx.lineCap,
    lineJoin = ctx.lineJoin
  )

proc strokeText*(ctx: Context, text: string, x, y: float32) {.inline.} =
  ctx.strokeText(text, vec2(x, y))

proc getTransform*(ctx: Context): Mat3 {.inline.} =
  ctx.mat

proc setTransform*(ctx: Context, transform: Mat3) {.inline.} =
  ctx.mat = transform

proc setTransform*(ctx: Context, a, b, c, d, e, f: float32) {.inline.} =
  ctx.mat = mat3(a, b, 0, c, d, 0, e, f, 1)

proc transform*(ctx: Context, transform: Mat3) {.inline.} =
  ctx.mat = ctx.mat * transform

proc transform*(ctx: Context, a, b, c, d, e, f: float32) {.inline.} =
  ctx.transform(mat3(a, b, 0, c, d, 0, e, f, 1))

proc translate*(ctx: Context, v: Vec2) {.inline.} =
  ctx.mat = ctx.mat * translate(v)

proc translate*(ctx: Context, x, y: float32) {.inline.} =
  ctx.mat = ctx.mat * translate(vec2(x, y))

proc scale*(ctx: Context, v: Vec2) {.inline.} =
  ctx.mat = ctx.mat * scale(v)

proc scale*(ctx: Context, x, y: float32) {.inline.} =
  ctx.mat = ctx.mat * scale(vec2(x, y))

proc rotate*(ctx: Context, angle: float32) {.inline.} =
  ctx.mat = ctx.mat * rotate(-angle)

proc resetTransform*(ctx: Context) {.inline.} =
  ctx.mat = mat3()

proc save*(ctx: Context) =
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
