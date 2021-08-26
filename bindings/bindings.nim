import bindy, pixie, unicode

type
  Vector2 = object
    x*, y*: float32

  Matrix3 = object
    a*, b*, c*, d*, e*, f*, g*, h*, i*: float32

var lastError*: ref PixieError

proc takeError*(): string =
  result = lastError.msg
  lastError = nil

proc checkError*(): bool  =
  result = lastError != nil

proc drawImage1*(
  ctx: Context, image: Image, dx, dy: float32
) {.raises: [PixieError].} =
  ctx.drawImage(image, dx, dy)

proc drawImage2*(
  ctx: Context, image: Image, dx, dy, dWidth, dHeight: float32
) {.raises: [PixieError].} =
  ctx.drawImage(image, dx, dy, dWidth, dHeight)

proc drawImage3*(
  ctx: Context,
  image: Image,
  sx, sy, sWidth, sHeight,
  dx, dy, dWidth, dHeight: float32
) {.raises: [PixieError].} =
  ctx.drawImage(image, sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight)

exportEnums:
  export
    FileFormat,
    BlendMode,
    PaintKind,
    WindingRule,
    LineCap,
    LineJoin,
    HorizontalAlignment,
    VerticalAlignment,
    TextCase

exportObjects:
  export
    Vector2,
    Matrix3,
    Rect,
    Color,
    ColorStop,
    TextMetrics

exportProcs:
  export
    bindings.checkError,
    bindings.takeError

exportSeq seq[float32]:
  discard

exportSeq seq[Span]:
  export
    pixie.typeset,
    pixie.computeBounds

exportRefObject Image, ["width", "height"]:
  discard newImage(0, 0)
  export
    pixie.writeFile,
    pixie.wh,
    pixie.copy,
    pixie.getColor,
    pixie.setColor,
    pixie.fill,
    pixie.flipHorizontal,
    pixie.flipVertical,
    pixie.subImage,
    pixie.minifyBy2,
    pixie.magnifyBy2,
    pixie.applyOpacity,
    pixie.invert,
    pixie.blur,
    pixie.newMask,
    pixie.resize,
    pixie.shadow,
    pixie.superImage,
    pixie.draw,
    pixie.fillGradient,
    pixie.fillText,
    pixie.strokeText,
    pixie.fillPath,
    pixie.strokePath,
    pixie.newContext

exportRefObject Mask, ["width", "height"]:
  discard newMask(0, 0)
  export
    pixie.writeFile,
    pixie.wh,
    pixie.copy,
    pixie.getValue,
    pixie.setValue,
    pixie.fill,
    pixie.minifyBy2,
    pixie.spread,
    pixie.ceil,
    pixie.newImage,
    pixie.applyOpacity,
    pixie.invert,
    pixie.blur,
    pixie.draw,
    pixie.fillText,
    pixie.strokeText,
    pixie.fillPath,
    pixie.strokePath

exportRefObject Paint, ["*"]:
  discard newPaint(pkSolid)
  export
    pixie.newPaint

exportRefObject Path, ["*"]:
  discard newPath()
  export
    pixie.transform,
    pixie.addPath,
    pixie.closePath,
    pixie.computeBounds,
    pixie.fillOverlaps,
    pixie.strokeOverlaps

  toggleBasicOnly()

  export
    pixie.moveTo,
    pixie.lineTo,
    pixie.bezierCurveTo,
    pixie.quadraticCurveTo,
    pixie.ellipticalArcTo,
    pixie.arc,
    pixie.arcTo,
    pixie.rect,
    pixie.roundedRect,
    pixie.ellipse,
    pixie.circle,
    pixie.polygon

exportRefObject Typeface, ["*"]:
  discard
  export
    pixie.ascent,
    pixie.descent,
    pixie.lineGap,
    pixie.lineHeight,
    pixie.getGlyphPath,
    pixie.getAdvance,
    pixie.getKerningAdjustment,
    pixie.newFont

exportRefObject Font, ["*"]:
  discard
  export
    pixie.scale,
    pixie.defaultLineHeight,
    pixie.typeset,
    pixie.computeBounds

exportRefObject Span, ["*"]:
  discard newSpan("", Font())

exportRefObject Arrangement, []:
  discard
  export
    pixie.computeBounds

exportRefObject Context, ["*"]:
  discard newContext(0, 0)
  export
    pixie.save,
    pixie.saveLayer,
    pixie.restore,
    pixie.beginPath,
    pixie.closePath,
    pixie.fill,
    pixie.clip,
    pixie.stroke,
    pixie.measureText,
    pixie.getTransform,
    pixie.setTransform,
    pixie.transform,
    pixie.resetTransform,
    bindings.drawImage1,
    bindings.drawImage2,
    bindings.drawImage3

  toggleBasicOnly()

  export
    pixie.moveTo,
    pixie.lineTo,
    pixie.bezierCurveTo,
    pixie.quadraticCurveTo,
    pixie.ellipticalArcTo,
    pixie.arc,
    pixie.arcTo,
    pixie.rect,
    pixie.roundedRect,
    pixie.ellipse,
    pixie.circle,
    pixie.polygon,
    pixie.clearRect,
    pixie.fillRect,
    pixie.strokeRect,
    pixie.fillText,
    pixie.strokeText,
    pixie.translate,
    pixie.scale,
    pixie.rotate,
    pixie.isPointInPath,
    pixie.isPointInStroke

exportProcs:
  export
    pixie.readImage,
    pixie.readmask,
    pixie.readTypeface,
    pixie.readFont,
    pixie.parsePath,
    pixie.miterLimitToAngle,
    pixie.angleToMiterLimit

writeFiles("bindings/generated", "pixie")

include generated/internal
