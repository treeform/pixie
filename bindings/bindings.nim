import genny, pixie, unicode

var lastError: ref PixieError

proc takeError(): string =
  result = lastError.msg
  lastError = nil

proc checkError(): bool =
  result = lastError != nil

type
  Vector2* = object
    x*, y*: float32

  Matrix3* = object
    values*: array[9, float32]

proc matrix3(): Matrix3 =
  cast[Matrix3](mat3())

proc mul(a, b: Matrix3): Matrix3 =
  cast[Matrix3](cast[Mat3](a) * cast[Mat3](b))

proc translate(x, y: float32): Matrix3 =
  cast[Matrix3](translate(vec2(x, y)))

proc rotate(angle: float32): Matrix3 =
  cast[Matrix3](rotate(angle))

proc scale(x, y: float32): Matrix3 =
  cast[Matrix3](scale(vec2(x, y)))

proc inverse(m: Matrix3): Matrix3 =
  cast[Matrix3](inverse(cast[Mat3](m)))

proc parseColor(s: string): Color {.raises: [PixieError]} =
  try:
    result = parseHtmlColor(s)
  except:
    raise currentExceptionAsPixieError()

proc drawImage2(
  ctx: Context, image: Image, dx, dy, dWidth, dHeight: float32
) {.raises: [PixieError].} =
  ctx.drawImage(image, dx, dy, dWidth, dHeight)

proc drawImage3(
  ctx: Context,
  image: Image,
  sx, sy, sWidth, sHeight,
  dx, dy, dWidth, dHeight: float32
) {.raises: [PixieError].} =
  ctx.drawImage(image, sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight)

exportConsts:
  defaultMiterLimit
  autoLineHeight

exportEnums:
  FileFormat
  BlendMode
  PaintKind
  WindingRule
  LineCap
  LineJoin
  HorizontalAlignment
  VerticalAlignment
  TextCase

exportProcs:
  checkError
  takeError

exportObject Vector2:
  discard

exportObject Matrix3:
  constructor:
    matrix3
  procs:
    mul(Matrix3, Matrix3)

exportObject Rect:
  discard

exportObject Color:
  discard

exportObject ColorStop:
  discard

exportObject TextMetrics:
  discard

exportSeq seq[float32]:
  discard

exportSeq seq[Span]:
  procs:
    typeset(seq[Span], Vec2, HorizontalAlignment, VerticalAlignment, bool)
    computeBounds(seq[Span])

exportRefObject Image:
  fields:
    width
    height
  constructor:
    newImage(int, int)
  procs:
    writeFile(Image, string)
    copy(Image)
    getColor
    setColor
    fill(Image, Color)
    flipHorizontal
    flipVertical
    subImage
    minifyBy2(Image, int)
    magnifyBy2(Image, int)
    applyOpacity(Image, float32)
    invert(Image)
    blur(Image, float32, Color)
    newMask(Image)
    resize(Image, int, int)
    shadow(Image, Vec2, float32, float32, Color)
    superImage
    draw(Image, Image, Mat3, BlendMode)
    draw(Image, Mask, Mat3, BlendMode)
    fillGradient
    fillText(Image, Font, string, Mat3, Vec2, HorizontalAlignment, VerticalAlignment)
    fillText(Image, Arrangement, Mat3)
    strokeText(Image, Font, string, Mat3, float32, Vec2, HorizontalAlignment, VerticalAlignment, LineCap, LineJoin, float32, seq[float32])
    strokeText(Image, Arrangement, Mat3, float32, LineCap, LineJoin, float32, seq[float32])
    fillPath(Image, Path, Paint, Mat3, WindingRule)
    strokePath(Image, Path, Paint, Mat3, float32, LineCap, LineJoin, float32, seq[float32])
    newContext(Image)

exportRefObject Mask:
  fields:
    width
    height
  constructor:
    newMask(int, int)
  procs:
    writeFile(Mask, string)
    copy(Mask)
    getValue
    setValue
    fill(Mask, uint8)
    minifyBy2(Mask, int)
    magnifyBy2(Mask, int)
    spread
    ceil(Mask)
    newImage(Mask)
    applyOpacity(Mask, float32)
    invert(Mask)
    blur(Mask, float32, uint8)
    draw(Mask, Mask, Mat3, BlendMode)
    draw(Mask, Image, Mat3, BlendMode)
    fillText(Mask, Font, string, Mat3, Vec2, HorizontalAlignment, VerticalAlignment)
    fillText(Mask, Arrangement, Mat3)
    strokeText(Mask, Font, string, Mat3, float32, Vec2, HorizontalAlignment, VerticalAlignment, LineCap, LineJoin, float32, seq[float32])
    strokeText(Mask, Arrangement, Mat3, float32, LineCap, LineJoin, float32, seq[float32])
    fillPath(Mask, Path, Mat3, WindingRule)
    strokePath(Mask, Path, Mat3, float32, LineCap, LineJoin, float32, seq[float32])

exportRefObject Paint:
  fields:
    kind
    blendMode
    opacity
    color
    image
    imageMat
    gradientHandlePositions
    gradientStops
  constructor:
    newPaint(PaintKind)
  procs:
    newPaint(Paint)

exportRefObject Path:
  constructor:
    newPath
  procs:
    transform(Path, Mat3)
    addPath(Path, Path)
    closePath(Path)
    computeBounds(Path)
    fillOverlaps
    strokeOverlaps
    moveTo(Path, float32, float32)
    lineTo(Path, float32, float32)
    bezierCurveTo(Path, float32, float32, float32, float32, float32, float32)
    quadraticCurveTo(Path, float32, float32, float32, float32)
    ellipticalArcTo(Path, float32, float32, float32, bool, bool, float32, float32)
    arc(Path, float32, float32, float32, float32, float32, bool)
    arcTo(Path, float32, float32, float32, float32, float32)
    rect(Path, float32, float32, float32, float32)
    roundedRect(Path, float32, float32, float32, float32, float32, float32, float32, float32, bool)
    ellipse(Path, float32, float32, float32, float32)
    circle(Path, float32, float32, float32)
    polygon(Path, float32, float32, float32, int)

exportRefObject Typeface:
  fields:
    filePath
  procs:
    ascent
    descent
    lineGap
    lineHeight
    hasGlyph
    getGlyphPath
    getAdvance
    getKerningAdjustment
    newFont

exportRefObject Font:
  fields:
    typeface
    size
    lineHeight
    paints
    paint
    textCase
    underline
    strikethrough
    noKerningAdjustments
  procs:
    scale(Font)
    defaultLineHeight
    typeset(Font, string, Vec2, HorizontalAlignment, VerticalAlignment, bool)
    computeBounds(Font, string)

exportRefObject Span:
  fields:
    text
    font
  constructor:
    newSpan

exportRefObject Arrangement:
  procs:
    computeBounds(Arrangement)

exportRefObject Context:
  fields:
    image
    fillStyle
    strokeStyle
    globalAlpha
    lineWidth
    miterLimit
    lineCap
    lineJoin
    font
    fontSize
    textAlign
  constructor:
    newContext(int, int)
  procs:
    save
    saveLayer
    restore
    beginPath
    closePath(Context)
    fill(Context, WindingRule)
    fill(Context, Path, WindingRule)
    clip(Context, WindingRule)
    clip(Context, Path, WindingRule)
    stroke(Context)
    stroke(Context, Path)
    measureText
    getTransform
    setTransform
    transform(Context, Mat3)
    resetTransform
    drawImage(Context, Image, float32, float32)
    drawImage2
    drawImage3
    moveTo(Context, float32, float32)
    lineTo(Context, float32, float32)
    bezierCurveTo(Context, float32, float32, float32, float32, float32, float32)
    quadraticCurveTo(Context, float32, float32, float32, float32)
    arc(Context, float32, float32, float32, float32, float32, bool)
    arcTo(Context, float32, float32, float32, float32, float32)
    rect(Context, float32, float32, float32, float32)
    roundedRect(Context, float32, float32, float32, float32, float32, float32, float32, float32)
    ellipse(Context, float32, float32, float32, float32)
    circle(Context, float32, float32, float32)
    polygon(Context, float32, float32, float32, int)
    clearRect(Context, float32, float32, float32, float32)
    fillRect(Context, float32, float32, float32, float32)
    strokeRect(Context, float32, float32, float32, float32)
    strokeSegment(Context, float32, float32, float32, float32)
    fillText(Context, string, float32, float32)
    strokeText(Context, string, float32, float32)
    translate(Context, float32, float32)
    scale(Context, float32, float32)
    rotate(Context, float32)
    isPointInPath(Context, float32, float32, WindingRule)
    isPointInPath(Context, Path, float32, float32, WindingRule)
    isPointInStroke(Context, float32, float32)
    isPointInStroke(Context, Path, float32, float32)

exportProcs:
  readImage
  readmask
  readTypeface
  readFont
  parsePath
  miterLimitToAngle
  angleToMiterLimit
  parseColor
  translate(float32, float32)
  rotate(float32)
  scale(float32, float32)
  inverse(Matrix3)

writeFiles("bindings/generated", "Pixie")

include generated/internal
