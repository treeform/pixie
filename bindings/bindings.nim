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

exportEnums [
  FileFormat, BlendMode, PaintKind, WindingRule, LineCap, LineJoin,
  HorizontalAlignment, VerticalAlignment, TextCase
]

exportObjects [Vector2, Matrix3, Rect, Color, ColorStop, TextMetrics]

exportProcs:
  export bindings.checkError
  export bindings.takeError

exportSeq seq[float32]:
  discard

exportSeq seq[Span]:
  export pixie.typeset
  export pixie.computeBounds

exportRefObject Image, ["width", "height"]:
  export pixie.writeFile
  export pixie.wh
  export pixie.copy
  export pixie.getColor
  export pixie.setColor
  export pixie.fill
  export pixie.flipHorizontal
  export pixie.flipVertical
  export pixie.subImage
  export pixie.minifyBy2
  export pixie.magnifyBy2
  export pixie.applyOpacity
  export pixie.invert
  export pixie.blur
  export pixie.newMask
  export pixie.resize
  export pixie.shadow
  export pixie.superImage
  export pixie.draw
  export pixie.fillGradient
  export pixie.fillText
  export pixie.strokeText
  export pixie.fillPath
  export pixie.strokePath
  export pixie.newContext

exportRefObject Mask, ["width", "height"]:
  export pixie.writeFile
  export pixie.wh
  export pixie.copy
  export pixie.getValue
  export pixie.setValue
  export pixie.fill
  export pixie.minifyBy2
  export pixie.spread
  export pixie.ceil
  export pixie.newImage
  export pixie.applyOpacity
  export pixie.invert
  export pixie.blur
  export pixie.draw
  export pixie.fillText
  export pixie.strokeText
  export pixie.fillPath
  export pixie.strokePath

exportRefObject Paint, ["*"]:
  export pixie.newPaint

exportRefObject Path, ["*"]:
  export pixie.transform
  export pixie.addPath
  export pixie.closePath
  export pixie.computeBounds
  export pixie.fillOverlaps
  export pixie.strokeOverlaps

  toggleBasicOnly()

  export pixie.moveTo
  export pixie.lineTo
  export pixie.bezierCurveTo
  export pixie.quadraticCurveTo
  export pixie.ellipticalArcTo
  export pixie.arc
  export pixie.arcTo
  export pixie.rect
  export pixie.roundedRect
  export pixie.ellipse
  export pixie.circle
  export pixie.polygon

exportRefObject Typeface, ["*"]:
  export pixie.ascent
  export pixie.descent
  export pixie.lineGap
  export pixie.lineHeight
  export pixie.getGlyphPath
  export pixie.getAdvance
  export pixie.getKerningAdjustment
  export pixie.newFont

exportRefObject Font, ["*"]:
  export pixie.scale
  export pixie.defaultLineHeight
  export pixie.typeset
  export pixie.computeBounds

exportRefObject Span, ["*"]:
  discard

exportRefObject Arrangement, []:
  export pixie.computeBounds

exportRefObject Context, ["*"]:
  export pixie.save
  export pixie.saveLayer
  export pixie.restore
  export pixie.beginPath
  export pixie.closePath
  export pixie.fill
  export pixie.clip
  export pixie.stroke
  export pixie.measureText
  export pixie.getTransform
  export pixie.setTransform
  export pixie.transform
  export pixie.resetTransform
  export bindings.drawImage1
  export bindings.drawImage2
  export bindings.drawImage3

  toggleBasicOnly()

  export pixie.moveTo
  export pixie.lineTo
  export pixie.bezierCurveTo
  export pixie.quadraticCurveTo
  export pixie.ellipticalArcTo
  export pixie.arc
  export pixie.arcTo
  export pixie.rect
  export pixie.roundedRect
  export pixie.ellipse
  export pixie.circle
  export pixie.polygon
  export pixie.clearRect
  export pixie.fillRect
  export pixie.strokeRect
  export pixie.fillText
  export pixie.strokeText
  export pixie.translate
  export pixie.scale
  export pixie.rotate
  export pixie.isPointInPath
  export pixie.isPointInStroke

exportProcs:
  export pixie.newImage
  export pixie.newMask
  export pixie.newPaint
  export pixie.newPath
  export pixie.newSpan
  export pixie.newContext
  export pixie.readImage
  export pixie.readmask
  export pixie.readTypeface
  export pixie.readFont
  export pixie.parsePath
  export pixie.miterLimitToAngle
  export pixie.angleToMiterLimit

writeFiles("bindings/generated", "pixie")

include generated/dllapi
