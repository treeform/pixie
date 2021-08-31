import bumpy, chroma, unicode, vmath

export bumpy, chroma, unicode, vmath

when defined(windows):
  const libName = "pixie.dll"
elif defined(macosx):
  const libName = "libpixie.dylib"
else:
  const libName = "libpixie.so"

{.push dynlib: libName.}

type PixieError = object of ValueError

const defaultMiterLimit* = 4.0

const autoLineHeight* = -1.0

type FileFormat* = enum
  ffPng
  ffBmp
  ffJpg
  ffGif

type BlendMode* = enum
  bmNormal
  bmDarken
  bmMultiply
  bmColorBurn
  bmLighten
  bmScreen
  bmColorDodge
  bmOverlay
  bmSoftLight
  bmHardLight
  bmDifference
  bmExclusion
  bmHue
  bmSaturation
  bmColor
  bmLuminosity
  bmMask
  bmOverwrite
  bmSubtractMask
  bmExcludeMask

type PaintKind* = enum
  pkSolid
  pkImage
  pkImageTiled
  pkGradientLinear
  pkGradientRadial
  pkGradientAngular

type WindingRule* = enum
  wrNonZero
  wrEvenOdd

type LineCap* = enum
  lcButt
  lcRound
  lcSquare

type LineJoin* = enum
  ljMiter
  ljRound
  ljBevel

type HorizontalAlignment* = enum
  haLeft
  haCenter
  haRight

type VerticalAlignment* = enum
  vaTop
  vaMiddle
  vaBottom

type TextCase* = enum
  tcNormal
  tcUpper
  tcLower
  tcTitle

type ColorStop* = object
  color*: Color
  position*: float32

proc colorStop*(color: Color, position: float32): ColorStop =
  result.color = color
  result.position = position

type TextMetrics* = object
  width*: float32

proc textMetrics*(width: float32): TextMetrics =
  result.width = width

type SeqFloat32Obj = object
  reference: pointer

type SeqFloat32* = ref SeqFloat32Obj

proc pixie_seq_float_32_unref(x: SeqFloat32Obj) {.importc: "pixie_seq_float_32_unref", cdecl.}

proc `=destroy`(x: var SeqFloat32Obj) =
  pixie_seq_float_32_unref(x)

type SeqSpanObj = object
  reference: pointer

type SeqSpan* = ref SeqSpanObj

proc pixie_seq_span_unref(x: SeqSpanObj) {.importc: "pixie_seq_span_unref", cdecl.}

proc `=destroy`(x: var SeqSpanObj) =
  pixie_seq_span_unref(x)

type ImageObj = object
  reference: pointer

type Image* = ref ImageObj

proc pixie_image_unref(x: ImageObj) {.importc: "pixie_image_unref", cdecl.}

proc `=destroy`(x: var ImageObj) =
  pixie_image_unref(x)

type MaskObj = object
  reference: pointer

type Mask* = ref MaskObj

proc pixie_mask_unref(x: MaskObj) {.importc: "pixie_mask_unref", cdecl.}

proc `=destroy`(x: var MaskObj) =
  pixie_mask_unref(x)

type PaintObj = object
  reference: pointer

type Paint* = ref PaintObj

proc pixie_paint_unref(x: PaintObj) {.importc: "pixie_paint_unref", cdecl.}

proc `=destroy`(x: var PaintObj) =
  pixie_paint_unref(x)

type PathObj = object
  reference: pointer

type Path* = ref PathObj

proc pixie_path_unref(x: PathObj) {.importc: "pixie_path_unref", cdecl.}

proc `=destroy`(x: var PathObj) =
  pixie_path_unref(x)

type TypefaceObj = object
  reference: pointer

type Typeface* = ref TypefaceObj

proc pixie_typeface_unref(x: TypefaceObj) {.importc: "pixie_typeface_unref", cdecl.}

proc `=destroy`(x: var TypefaceObj) =
  pixie_typeface_unref(x)

type FontObj = object
  reference: pointer

type Font* = ref FontObj

proc pixie_font_unref(x: FontObj) {.importc: "pixie_font_unref", cdecl.}

proc `=destroy`(x: var FontObj) =
  pixie_font_unref(x)

type SpanObj = object
  reference: pointer

type Span* = ref SpanObj

proc pixie_span_unref(x: SpanObj) {.importc: "pixie_span_unref", cdecl.}

proc `=destroy`(x: var SpanObj) =
  pixie_span_unref(x)

type ArrangementObj = object
  reference: pointer

type Arrangement* = ref ArrangementObj

proc pixie_arrangement_unref(x: ArrangementObj) {.importc: "pixie_arrangement_unref", cdecl.}

proc `=destroy`(x: var ArrangementObj) =
  pixie_arrangement_unref(x)

type ContextObj = object
  reference: pointer

type Context* = ref ContextObj

proc pixie_context_unref(x: ContextObj) {.importc: "pixie_context_unref", cdecl.}

proc `=destroy`(x: var ContextObj) =
  pixie_context_unref(x)

proc pixie_check_error(): bool {.importc: "pixie_check_error", cdecl.}

proc checkError*(): bool {.inline.} =
  result = pixie_check_error()

proc pixie_take_error(): cstring {.importc: "pixie_take_error", cdecl.}

proc takeError*(): cstring {.inline.} =
  result = pixie_take_error()

proc pixie_seq_float_32_len(s: SeqFloat32): int {.importc: "pixie_seq_float_32_len", cdecl.}

proc len*(s: SeqFloat32): int =
  pixie_seq_float_32_len(s)

proc pixie_seq_float_32_add(s: SeqFloat32, v: float32) {.importc: "pixie_seq_float_32_add", cdecl.}

proc add*(s: SeqFloat32, v: float32) =
  pixie_seq_float_32_add(s, v)

proc pixie_seq_float_32_get(s: SeqFloat32, i: int): float32 {.importc: "pixie_seq_float_32_get", cdecl.}

proc `[]`*(s: SeqFloat32, i: int): float32 =
  pixie_seq_float_32_get(s, i)

proc pixie_seq_float_32_set(s: SeqFloat32, i: int, v: float32) {.importc: "pixie_seq_float_32_set", cdecl.}

proc `[]=`*(s: SeqFloat32, i: int, v: float32) =
  pixie_seq_float_32_set(s, i, v)

proc pixie_seq_float_32_delete(s: SeqFloat32, i: int) {.importc: "pixie_seq_float_32_delete", cdecl.}

proc delete*(s: SeqFloat32, i: int) =
  pixie_seq_float_32_delete(s, i)

proc pixie_seq_float_32_clear(s: SeqFloat32) {.importc: "pixie_seq_float_32_clear", cdecl.}

proc clear*(s: SeqFloat32) =
  pixie_seq_float_32_clear(s)

proc pixie_new_seq_float_32*(): SeqFloat32 {.importc: "pixie_new_seq_float_32", cdecl.}

proc newSeqFloat32*(): SeqFloat32 =
  pixie_new_seq_float_32()

proc pixie_seq_span_len(s: SeqSpan): int {.importc: "pixie_seq_span_len", cdecl.}

proc len*(s: SeqSpan): int =
  pixie_seq_span_len(s)

proc pixie_seq_span_add(s: SeqSpan, v: Span) {.importc: "pixie_seq_span_add", cdecl.}

proc add*(s: SeqSpan, v: Span) =
  pixie_seq_span_add(s, v)

proc pixie_seq_span_get(s: SeqSpan, i: int): Span {.importc: "pixie_seq_span_get", cdecl.}

proc `[]`*(s: SeqSpan, i: int): Span =
  pixie_seq_span_get(s, i)

proc pixie_seq_span_set(s: SeqSpan, i: int, v: Span) {.importc: "pixie_seq_span_set", cdecl.}

proc `[]=`*(s: SeqSpan, i: int, v: Span) =
  pixie_seq_span_set(s, i, v)

proc pixie_seq_span_delete(s: SeqSpan, i: int) {.importc: "pixie_seq_span_delete", cdecl.}

proc delete*(s: SeqSpan, i: int) =
  pixie_seq_span_delete(s, i)

proc pixie_seq_span_clear(s: SeqSpan) {.importc: "pixie_seq_span_clear", cdecl.}

proc clear*(s: SeqSpan) =
  pixie_seq_span_clear(s)

proc pixie_new_seq_span*(): SeqSpan {.importc: "pixie_new_seq_span", cdecl.}

proc newSeqSpan*(): SeqSpan =
  pixie_new_seq_span()

proc pixie_seq_span_typeset(spans: SeqSpan, bounds: Vec2, h_align: HorizontalAlignment, v_align: VerticalAlignment, wrap: bool): Arrangement {.importc: "pixie_seq_span_typeset", cdecl.}

proc typeset*(spans: SeqSpan, bounds: Vec2 = vec2(0, 0), hAlign: HorizontalAlignment = haLeft, vAlign: VerticalAlignment = vaTop, wrap: bool = true): Arrangement {.inline.} =
  result = pixie_seq_span_typeset(spans, bounds, hAlign, vAlign, wrap)

proc pixie_seq_span_compute_bounds(spans: SeqSpan): Vec2 {.importc: "pixie_seq_span_compute_bounds", cdecl.}

proc computeBounds*(spans: SeqSpan): Vec2 {.inline.} =
  result = pixie_seq_span_compute_bounds(spans)

proc pixie_new_image(width: int, height: int): Image {.importc: "pixie_new_image", cdecl.}

proc newImage*(width: int, height: int): Image {.inline.} =
  result = pixie_new_image(width, height)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_get_width(image: Image): int {.importc: "pixie_image_get_width", cdecl.}

proc width*(image: Image): int {.inline.} =
  pixie_image_get_width(image)

proc pixie_image_set_width(image: Image, width: int) {.importc: "pixie_image_set_width", cdecl.}

proc `width=`*(image: Image, width: int) =
  pixie_image_set_width(image, width)

proc pixie_image_get_height(image: Image): int {.importc: "pixie_image_get_height", cdecl.}

proc height*(image: Image): int {.inline.} =
  pixie_image_get_height(image)

proc pixie_image_set_height(image: Image, height: int) {.importc: "pixie_image_set_height", cdecl.}

proc `height=`*(image: Image, height: int) =
  pixie_image_set_height(image, height)

proc pixie_image_write_file(image: Image, file_path: cstring) {.importc: "pixie_image_write_file", cdecl.}

proc writeFile*(image: Image, filePath: string) {.inline.} =
  pixie_image_write_file(image, filePath.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_wh(image: Image): Vec2 {.importc: "pixie_image_wh", cdecl.}

proc wh*(image: Image): Vec2 {.inline.} =
  result = pixie_image_wh(image)

proc pixie_image_copy(image: Image): Image {.importc: "pixie_image_copy", cdecl.}

proc copy*(image: Image): Image {.inline.} =
  result = pixie_image_copy(image)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_get_color(image: Image, x: int, y: int): Color {.importc: "pixie_image_get_color", cdecl.}

proc getColor*(image: Image, x: int, y: int): Color {.inline.} =
  result = pixie_image_get_color(image, x, y)

proc pixie_image_set_color(image: Image, x: int, y: int, color: Color) {.importc: "pixie_image_set_color", cdecl.}

proc setColor*(image: Image, x: int, y: int, color: Color) {.inline.} =
  pixie_image_set_color(image, x, y, color)

proc pixie_image_fill(image: Image, color: Color) {.importc: "pixie_image_fill", cdecl.}

proc fill*(image: Image, color: Color) {.inline.} =
  pixie_image_fill(image, color)

proc pixie_image_flip_horizontal(image: Image) {.importc: "pixie_image_flip_horizontal", cdecl.}

proc flipHorizontal*(image: Image) {.inline.} =
  pixie_image_flip_horizontal(image)

proc pixie_image_flip_vertical(image: Image) {.importc: "pixie_image_flip_vertical", cdecl.}

proc flipVertical*(image: Image) {.inline.} =
  pixie_image_flip_vertical(image)

proc pixie_image_sub_image(image: Image, x: int, y: int, w: int, h: int): Image {.importc: "pixie_image_sub_image", cdecl.}

proc subImage*(image: Image, x: int, y: int, w: int, h: int): Image {.inline.} =
  result = pixie_image_sub_image(image, x, y, w, h)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_minify_by_2(image: Image, power: int): Image {.importc: "pixie_image_minify_by_2", cdecl.}

proc minifyBy2*(image: Image, power: int = 1): Image {.inline.} =
  result = pixie_image_minify_by_2(image, power)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_magnify_by_2(image: Image, power: int): Image {.importc: "pixie_image_magnify_by_2", cdecl.}

proc magnifyBy2*(image: Image, power: int = 1): Image {.inline.} =
  result = pixie_image_magnify_by_2(image, power)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_apply_opacity(target: Image, opacity: float32) {.importc: "pixie_image_apply_opacity", cdecl.}

proc applyOpacity*(target: Image, opacity: float32) {.inline.} =
  pixie_image_apply_opacity(target, opacity)

proc pixie_image_invert(target: Image) {.importc: "pixie_image_invert", cdecl.}

proc invert*(target: Image) {.inline.} =
  pixie_image_invert(target)

proc pixie_image_blur(image: Image, radius: float32, out_of_bounds: Color) {.importc: "pixie_image_blur", cdecl.}

proc blur*(image: Image, radius: float32, outOfBounds: Color = Color()) {.inline.} =
  pixie_image_blur(image, radius, outOfBounds)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_new_mask(image: Image): Mask {.importc: "pixie_image_new_mask", cdecl.}

proc newMask*(image: Image): Mask {.inline.} =
  result = pixie_image_new_mask(image)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_resize(src_image: Image, width: int, height: int): Image {.importc: "pixie_image_resize", cdecl.}

proc resize*(srcImage: Image, width: int, height: int): Image {.inline.} =
  result = pixie_image_resize(srcImage, width, height)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_shadow(image: Image, offset: Vec2, spread: float32, blur: float32, color: Color): Image {.importc: "pixie_image_shadow", cdecl.}

proc shadow*(image: Image, offset: Vec2, spread: float32, blur: float32, color: Color): Image {.inline.} =
  result = pixie_image_shadow(image, offset, spread, blur, color)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_super_image(image: Image, x: int, y: int, w: int, h: int): Image {.importc: "pixie_image_super_image", cdecl.}

proc superImage*(image: Image, x: int, y: int, w: int, h: int): Image {.inline.} =
  result = pixie_image_super_image(image, x, y, w, h)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_draw(a: Image, b: Image, transform: Mat3, blend_mode: BlendMode) {.importc: "pixie_image_draw", cdecl.}

proc draw*(a: Image, b: Image, transform: Mat3 = mat3(), blendMode: BlendMode = bmNormal) {.inline.} =
  pixie_image_draw(a, b, transform, blendMode)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_mask_draw(image: Image, mask: Mask, transform: Mat3, blend_mode: BlendMode) {.importc: "pixie_image_mask_draw", cdecl.}

proc draw*(image: Image, mask: Mask, transform: Mat3 = mat3(), blendMode: BlendMode = bmMask) {.inline.} =
  pixie_image_mask_draw(image, mask, transform, blendMode)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_fill_gradient(image: Image, paint: Paint) {.importc: "pixie_image_fill_gradient", cdecl.}

proc fillGradient*(image: Image, paint: Paint) {.inline.} =
  pixie_image_fill_gradient(image, paint)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_fill_text(target: Image, font: Font, text: cstring, transform: Mat3, bounds: Vec2, h_align: HorizontalAlignment, v_align: VerticalAlignment) {.importc: "pixie_image_fill_text", cdecl.}

proc fillText*(target: Image, font: Font, text: string, transform: Mat3 = mat3(), bounds: Vec2 = vec2(0, 0), hAlign: HorizontalAlignment = haLeft, vAlign: VerticalAlignment = vaTop) {.inline.} =
  pixie_image_fill_text(target, font, text.cstring, transform, bounds, hAlign, vAlign)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_arrangement_fill_text(target: Image, arrangement: Arrangement, transform: Mat3) {.importc: "pixie_image_arrangement_fill_text", cdecl.}

proc fillText*(target: Image, arrangement: Arrangement, transform: Mat3 = mat3()) {.inline.} =
  pixie_image_arrangement_fill_text(target, arrangement, transform)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_stroke_text(target: Image, font: Font, text: cstring, transform: Mat3, stroke_width: float32, bounds: Vec2, h_align: HorizontalAlignment, v_align: VerticalAlignment, line_cap: LineCap, line_join: LineJoin, miter_limit: float32, dashes: SeqFloat32) {.importc: "pixie_image_stroke_text", cdecl.}

proc strokeText*(target: Image, font: Font, text: string, transform: Mat3 = mat3(), strokeWidth: float32 = 1.0, bounds: Vec2 = vec2(0, 0), hAlign: HorizontalAlignment = haLeft, vAlign: VerticalAlignment = vaTop, lineCap: LineCap = lcButt, lineJoin: LineJoin = ljMiter, miterLimit: float32 = defaultMiterLimit, dashes: SeqFloat32) {.inline.} =
  pixie_image_stroke_text(target, font, text.cstring, transform, strokeWidth, bounds, hAlign, vAlign, lineCap, lineJoin, miterLimit, dashes)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_arrangement_stroke_text(target: Image, arrangement: Arrangement, transform: Mat3, stroke_width: float32, line_cap: LineCap, line_join: LineJoin, miter_limit: float32, dashes: SeqFloat32) {.importc: "pixie_image_arrangement_stroke_text", cdecl.}

proc strokeText*(target: Image, arrangement: Arrangement, transform: Mat3 = mat3(), strokeWidth: float32 = 1.0, lineCap: LineCap = lcButt, lineJoin: LineJoin = ljMiter, miterLimit: float32 = defaultMiterLimit, dashes: SeqFloat32) {.inline.} =
  pixie_image_arrangement_stroke_text(target, arrangement, transform, strokeWidth, lineCap, lineJoin, miterLimit, dashes)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_fill_path(image: Image, path: Path, paint: Paint, transform: Mat3, winding_rule: WindingRule) {.importc: "pixie_image_fill_path", cdecl.}

proc fillPath*(image: Image, path: Path, paint: Paint, transform: Mat3 = mat3(), windingRule: WindingRule = wrNonZero) {.inline.} =
  pixie_image_fill_path(image, path, paint, transform, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_stroke_path(image: Image, path: Path, paint: Paint, transform: Mat3, stroke_width: float32, line_cap: LineCap, line_join: LineJoin, miter_limit: float32, dashes: SeqFloat32) {.importc: "pixie_image_stroke_path", cdecl.}

proc strokePath*(image: Image, path: Path, paint: Paint, transform: Mat3 = mat3(), strokeWidth: float32 = 1.0, lineCap: LineCap = lcButt, lineJoin: LineJoin = ljMiter, miterLimit: float32 = defaultMiterLimit, dashes: SeqFloat32) {.inline.} =
  pixie_image_stroke_path(image, path, paint, transform, strokeWidth, lineCap, lineJoin, miterLimit, dashes)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_image_new_context(image: Image): Context {.importc: "pixie_image_new_context", cdecl.}

proc newContext*(image: Image): Context {.inline.} =
  result = pixie_image_new_context(image)

proc pixie_new_mask(width: int, height: int): Mask {.importc: "pixie_new_mask", cdecl.}

proc newMask*(width: int, height: int): Mask {.inline.} =
  result = pixie_new_mask(width, height)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_get_width(mask: Mask): int {.importc: "pixie_mask_get_width", cdecl.}

proc width*(mask: Mask): int {.inline.} =
  pixie_mask_get_width(mask)

proc pixie_mask_set_width(mask: Mask, width: int) {.importc: "pixie_mask_set_width", cdecl.}

proc `width=`*(mask: Mask, width: int) =
  pixie_mask_set_width(mask, width)

proc pixie_mask_get_height(mask: Mask): int {.importc: "pixie_mask_get_height", cdecl.}

proc height*(mask: Mask): int {.inline.} =
  pixie_mask_get_height(mask)

proc pixie_mask_set_height(mask: Mask, height: int) {.importc: "pixie_mask_set_height", cdecl.}

proc `height=`*(mask: Mask, height: int) =
  pixie_mask_set_height(mask, height)

proc pixie_mask_write_file(mask: Mask, file_path: cstring) {.importc: "pixie_mask_write_file", cdecl.}

proc writeFile*(mask: Mask, filePath: string) {.inline.} =
  pixie_mask_write_file(mask, filePath.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_wh(mask: Mask): Vec2 {.importc: "pixie_mask_wh", cdecl.}

proc wh*(mask: Mask): Vec2 {.inline.} =
  result = pixie_mask_wh(mask)

proc pixie_mask_copy(mask: Mask): Mask {.importc: "pixie_mask_copy", cdecl.}

proc copy*(mask: Mask): Mask {.inline.} =
  result = pixie_mask_copy(mask)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_get_value(mask: Mask, x: int, y: int): uint8 {.importc: "pixie_mask_get_value", cdecl.}

proc getValue*(mask: Mask, x: int, y: int): uint8 {.inline.} =
  result = pixie_mask_get_value(mask, x, y)

proc pixie_mask_set_value(mask: Mask, x: int, y: int, value: uint8) {.importc: "pixie_mask_set_value", cdecl.}

proc setValue*(mask: Mask, x: int, y: int, value: uint8) {.inline.} =
  pixie_mask_set_value(mask, x, y, value)

proc pixie_mask_fill(mask: Mask, value: uint8) {.importc: "pixie_mask_fill", cdecl.}

proc fill*(mask: Mask, value: uint8) {.inline.} =
  pixie_mask_fill(mask, value)

proc pixie_mask_minify_by_2(mask: Mask, power: int): Mask {.importc: "pixie_mask_minify_by_2", cdecl.}

proc minifyBy2*(mask: Mask, power: int = 1): Mask {.inline.} =
  result = pixie_mask_minify_by_2(mask, power)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_spread(mask: Mask, spread: float32) {.importc: "pixie_mask_spread", cdecl.}

proc spread*(mask: Mask, spread: float32) {.inline.} =
  pixie_mask_spread(mask, spread)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_ceil(mask: Mask) {.importc: "pixie_mask_ceil", cdecl.}

proc ceil*(mask: Mask) {.inline.} =
  pixie_mask_ceil(mask)

proc pixie_mask_new_image(mask: Mask): Image {.importc: "pixie_mask_new_image", cdecl.}

proc newImage*(mask: Mask): Image {.inline.} =
  result = pixie_mask_new_image(mask)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_apply_opacity(target: Mask, opacity: float32) {.importc: "pixie_mask_apply_opacity", cdecl.}

proc applyOpacity*(target: Mask, opacity: float32) {.inline.} =
  pixie_mask_apply_opacity(target, opacity)

proc pixie_mask_invert(target: Mask) {.importc: "pixie_mask_invert", cdecl.}

proc invert*(target: Mask) {.inline.} =
  pixie_mask_invert(target)

proc pixie_mask_blur(mask: Mask, radius: float32, out_of_bounds: uint8) {.importc: "pixie_mask_blur", cdecl.}

proc blur*(mask: Mask, radius: float32, outOfBounds: uint8 = 0) {.inline.} =
  pixie_mask_blur(mask, radius, outOfBounds)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_draw(a: Mask, b: Mask, transform: Mat3, blend_mode: BlendMode) {.importc: "pixie_mask_draw", cdecl.}

proc draw*(a: Mask, b: Mask, transform: Mat3 = mat3(), blendMode: BlendMode = bmMask) {.inline.} =
  pixie_mask_draw(a, b, transform, blendMode)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_image_draw(mask: Mask, image: Image, transform: Mat3, blend_mode: BlendMode) {.importc: "pixie_mask_image_draw", cdecl.}

proc draw*(mask: Mask, image: Image, transform: Mat3 = mat3(), blendMode: BlendMode = bmMask) {.inline.} =
  pixie_mask_image_draw(mask, image, transform, blendMode)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_fill_text(target: Mask, font: Font, text: cstring, transform: Mat3, bounds: Vec2, h_align: HorizontalAlignment, v_align: VerticalAlignment) {.importc: "pixie_mask_fill_text", cdecl.}

proc fillText*(target: Mask, font: Font, text: string, transform: Mat3 = mat3(), bounds: Vec2 = vec2(0, 0), hAlign: HorizontalAlignment = haLeft, vAlign: VerticalAlignment = vaTop) {.inline.} =
  pixie_mask_fill_text(target, font, text.cstring, transform, bounds, hAlign, vAlign)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_arrangement_fill_text(target: Mask, arrangement: Arrangement, transform: Mat3) {.importc: "pixie_mask_arrangement_fill_text", cdecl.}

proc fillText*(target: Mask, arrangement: Arrangement, transform: Mat3 = mat3()) {.inline.} =
  pixie_mask_arrangement_fill_text(target, arrangement, transform)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_stroke_text(target: Mask, font: Font, text: cstring, transform: Mat3, stroke_width: float32, bounds: Vec2, h_align: HorizontalAlignment, v_align: VerticalAlignment, line_cap: LineCap, line_join: LineJoin, miter_limit: float32, dashes: SeqFloat32) {.importc: "pixie_mask_stroke_text", cdecl.}

proc strokeText*(target: Mask, font: Font, text: string, transform: Mat3 = mat3(), strokeWidth: float32 = 1.0, bounds: Vec2 = vec2(0, 0), hAlign: HorizontalAlignment = haLeft, vAlign: VerticalAlignment = vaTop, lineCap: LineCap = lcButt, lineJoin: LineJoin = ljMiter, miterLimit: float32 = defaultMiterLimit, dashes: SeqFloat32) {.inline.} =
  pixie_mask_stroke_text(target, font, text.cstring, transform, strokeWidth, bounds, hAlign, vAlign, lineCap, lineJoin, miterLimit, dashes)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_arrangement_stroke_text(target: Mask, arrangement: Arrangement, transform: Mat3, stroke_width: float32, line_cap: LineCap, line_join: LineJoin, miter_limit: float32, dashes: SeqFloat32) {.importc: "pixie_mask_arrangement_stroke_text", cdecl.}

proc strokeText*(target: Mask, arrangement: Arrangement, transform: Mat3 = mat3(), strokeWidth: float32 = 1.0, lineCap: LineCap = lcButt, lineJoin: LineJoin = ljMiter, miterLimit: float32 = defaultMiterLimit, dashes: SeqFloat32) {.inline.} =
  pixie_mask_arrangement_stroke_text(target, arrangement, transform, strokeWidth, lineCap, lineJoin, miterLimit, dashes)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_fill_path(mask: Mask, path: Path, transform: Mat3, winding_rule: WindingRule, blend_mode: BlendMode) {.importc: "pixie_mask_fill_path", cdecl.}

proc fillPath*(mask: Mask, path: Path, transform: Mat3 = mat3(), windingRule: WindingRule = wrNonZero, blendMode: BlendMode = bmNormal) {.inline.} =
  pixie_mask_fill_path(mask, path, transform, windingRule, blendMode)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_mask_stroke_path(mask: Mask, path: Path, transform: Mat3, stroke_width: float32, line_cap: LineCap, line_join: LineJoin, miter_limit: float32, dashes: SeqFloat32, blend_mode: BlendMode) {.importc: "pixie_mask_stroke_path", cdecl.}

proc strokePath*(mask: Mask, path: Path, transform: Mat3 = mat3(), strokeWidth: float32 = 1.0, lineCap: LineCap = lcButt, lineJoin: LineJoin = ljMiter, miterLimit: float32 = defaultMiterLimit, dashes: SeqFloat32, blendMode: BlendMode = bmNormal) {.inline.} =
  pixie_mask_stroke_path(mask, path, transform, strokeWidth, lineCap, lineJoin, miterLimit, dashes, blendMode)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_new_paint(kind: PaintKind): Paint {.importc: "pixie_new_paint", cdecl.}

proc newPaint*(kind: PaintKind): Paint {.inline.} =
  result = pixie_new_paint(kind)

proc pixie_paint_get_kind(paint: Paint): PaintKind {.importc: "pixie_paint_get_kind", cdecl.}

proc kind*(paint: Paint): PaintKind {.inline.} =
  pixie_paint_get_kind(paint)

proc pixie_paint_set_kind(paint: Paint, kind: PaintKind) {.importc: "pixie_paint_set_kind", cdecl.}

proc `kind=`*(paint: Paint, kind: PaintKind) =
  pixie_paint_set_kind(paint, kind)

proc pixie_paint_get_blend_mode(paint: Paint): BlendMode {.importc: "pixie_paint_get_blend_mode", cdecl.}

proc blendMode*(paint: Paint): BlendMode {.inline.} =
  pixie_paint_get_blend_mode(paint)

proc pixie_paint_set_blend_mode(paint: Paint, blendMode: BlendMode) {.importc: "pixie_paint_set_blend_mode", cdecl.}

proc `blendMode=`*(paint: Paint, blendMode: BlendMode) =
  pixie_paint_set_blend_mode(paint, blendMode)

proc pixie_paint_get_opacity(paint: Paint): float32 {.importc: "pixie_paint_get_opacity", cdecl.}

proc opacity*(paint: Paint): float32 {.inline.} =
  pixie_paint_get_opacity(paint)

proc pixie_paint_set_opacity(paint: Paint, opacity: float32) {.importc: "pixie_paint_set_opacity", cdecl.}

proc `opacity=`*(paint: Paint, opacity: float32) =
  pixie_paint_set_opacity(paint, opacity)

proc pixie_paint_get_color(paint: Paint): Color {.importc: "pixie_paint_get_color", cdecl.}

proc color*(paint: Paint): Color {.inline.} =
  pixie_paint_get_color(paint)

proc pixie_paint_set_color(paint: Paint, color: Color) {.importc: "pixie_paint_set_color", cdecl.}

proc `color=`*(paint: Paint, color: Color) =
  pixie_paint_set_color(paint, color)

proc pixie_paint_get_image(paint: Paint): Image {.importc: "pixie_paint_get_image", cdecl.}

proc image*(paint: Paint): Image {.inline.} =
  pixie_paint_get_image(paint)

proc pixie_paint_set_image(paint: Paint, image: Image) {.importc: "pixie_paint_set_image", cdecl.}

proc `image=`*(paint: Paint, image: Image) =
  pixie_paint_set_image(paint, image)

proc pixie_paint_get_image_mat(paint: Paint): Mat3 {.importc: "pixie_paint_get_image_mat", cdecl.}

proc imageMat*(paint: Paint): Mat3 {.inline.} =
  pixie_paint_get_image_mat(paint)

proc pixie_paint_set_image_mat(paint: Paint, imageMat: Mat3) {.importc: "pixie_paint_set_image_mat", cdecl.}

proc `imageMat=`*(paint: Paint, imageMat: Mat3) =
  pixie_paint_set_image_mat(paint, imageMat)

type PaintGradientHandlePositions = object
    paint: Paint

proc gradientHandlePositions*(paint: Paint): PaintGradientHandlePositions =
  PaintGradientHandlePositions(paint: paint)

proc pixie_paint_gradient_handle_positions_len(s: Paint): int {.importc: "pixie_paint_gradient_handle_positions_len", cdecl.}

proc len*(s: PaintGradientHandlePositions): int =
  pixie_paint_gradient_handle_positions_len(s.paint)

proc pixie_paint_gradient_handle_positions_add(s: Paint, v: Vec2) {.importc: "pixie_paint_gradient_handle_positions_add", cdecl.}

proc add*(s: PaintGradientHandlePositions, v: Vec2) =
  pixie_paint_gradient_handle_positions_add(s.paint, v)

proc pixie_paint_gradient_handle_positions_get(s: Paint, i: int): Vec2 {.importc: "pixie_paint_gradient_handle_positions_get", cdecl.}

proc `[]`*(s: PaintGradientHandlePositions, i: int): Vec2 =
  pixie_paint_gradient_handle_positions_get(s.paint, i)

proc pixie_paint_gradient_handle_positions_set(s: Paint, i: int, v: Vec2) {.importc: "pixie_paint_gradient_handle_positions_set", cdecl.}

proc `[]=`*(s: PaintGradientHandlePositions, i: int, v: Vec2) =
  pixie_paint_gradient_handle_positions_set(s.paint, i, v)

proc pixie_paint_gradient_handle_positions_delete(s: Paint, i: int) {.importc: "pixie_paint_gradient_handle_positions_delete", cdecl.}

proc delete*(s: PaintGradientHandlePositions, i: int) =
  pixie_paint_gradient_handle_positions_delete(s.paint, i)

proc pixie_paint_gradient_handle_positions_clear(s: Paint) {.importc: "pixie_paint_gradient_handle_positions_clear", cdecl.}

proc clear*(s: PaintGradientHandlePositions) =
  pixie_paint_gradient_handle_positions_clear(s.paint)

type PaintGradientStops = object
    paint: Paint

proc gradientStops*(paint: Paint): PaintGradientStops =
  PaintGradientStops(paint: paint)

proc pixie_paint_gradient_stops_len(s: Paint): int {.importc: "pixie_paint_gradient_stops_len", cdecl.}

proc len*(s: PaintGradientStops): int =
  pixie_paint_gradient_stops_len(s.paint)

proc pixie_paint_gradient_stops_add(s: Paint, v: ColorStop) {.importc: "pixie_paint_gradient_stops_add", cdecl.}

proc add*(s: PaintGradientStops, v: ColorStop) =
  pixie_paint_gradient_stops_add(s.paint, v)

proc pixie_paint_gradient_stops_get(s: Paint, i: int): ColorStop {.importc: "pixie_paint_gradient_stops_get", cdecl.}

proc `[]`*(s: PaintGradientStops, i: int): ColorStop =
  pixie_paint_gradient_stops_get(s.paint, i)

proc pixie_paint_gradient_stops_set(s: Paint, i: int, v: ColorStop) {.importc: "pixie_paint_gradient_stops_set", cdecl.}

proc `[]=`*(s: PaintGradientStops, i: int, v: ColorStop) =
  pixie_paint_gradient_stops_set(s.paint, i, v)

proc pixie_paint_gradient_stops_delete(s: Paint, i: int) {.importc: "pixie_paint_gradient_stops_delete", cdecl.}

proc delete*(s: PaintGradientStops, i: int) =
  pixie_paint_gradient_stops_delete(s.paint, i)

proc pixie_paint_gradient_stops_clear(s: Paint) {.importc: "pixie_paint_gradient_stops_clear", cdecl.}

proc clear*(s: PaintGradientStops) =
  pixie_paint_gradient_stops_clear(s.paint)

proc pixie_paint_new_paint(paint: Paint): Paint {.importc: "pixie_paint_new_paint", cdecl.}

proc newPaint*(paint: Paint): Paint {.inline.} =
  result = pixie_paint_new_paint(paint)

proc pixie_new_path(): Path {.importc: "pixie_new_path", cdecl.}

proc newPath*(): Path {.inline.} =
  result = pixie_new_path()

proc pixie_path_transform(path: Path, mat: Mat3) {.importc: "pixie_path_transform", cdecl.}

proc transform*(path: Path, mat: Mat3) {.inline.} =
  pixie_path_transform(path, mat)

proc pixie_path_add_path(path: Path, other: Path) {.importc: "pixie_path_add_path", cdecl.}

proc addPath*(path: Path, other: Path) {.inline.} =
  pixie_path_add_path(path, other)

proc pixie_path_close_path(path: Path) {.importc: "pixie_path_close_path", cdecl.}

proc closePath*(path: Path) {.inline.} =
  pixie_path_close_path(path)

proc pixie_path_compute_bounds(path: Path, transform: Mat3): Rect {.importc: "pixie_path_compute_bounds", cdecl.}

proc computeBounds*(path: Path, transform: Mat3 = mat3()): Rect {.inline.} =
  result = pixie_path_compute_bounds(path, transform)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_path_fill_overlaps(path: Path, test: Vec2, transform: Mat3, winding_rule: WindingRule): bool {.importc: "pixie_path_fill_overlaps", cdecl.}

proc fillOverlaps*(path: Path, test: Vec2, transform: Mat3 = mat3(), windingRule: WindingRule = wrNonZero): bool {.inline.} =
  result = pixie_path_fill_overlaps(path, test, transform, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_path_stroke_overlaps(path: Path, test: Vec2, transform: Mat3, stroke_width: float32, line_cap: LineCap, line_join: LineJoin, miter_limit: float32, dashes: SeqFloat32): bool {.importc: "pixie_path_stroke_overlaps", cdecl.}

proc strokeOverlaps*(path: Path, test: Vec2, transform: Mat3 = mat3(), strokeWidth: float32 = 1.0, lineCap: LineCap = lcButt, lineJoin: LineJoin = ljMiter, miterLimit: float32 = defaultMiterLimit, dashes: SeqFloat32): bool {.inline.} =
  result = pixie_path_stroke_overlaps(path, test, transform, strokeWidth, lineCap, lineJoin, miterLimit, dashes)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_path_move_to(path: Path, x: float32, y: float32) {.importc: "pixie_path_move_to", cdecl.}

proc moveTo*(path: Path, x: float32, y: float32) {.inline.} =
  pixie_path_move_to(path, x, y)

proc pixie_path_line_to(path: Path, x: float32, y: float32) {.importc: "pixie_path_line_to", cdecl.}

proc lineTo*(path: Path, x: float32, y: float32) {.inline.} =
  pixie_path_line_to(path, x, y)

proc pixie_path_bezier_curve_to(path: Path, x_1: float32, y_1: float32, x_2: float32, y_2: float32, x_3: float32, y_3: float32) {.importc: "pixie_path_bezier_curve_to", cdecl.}

proc bezierCurveTo*(path: Path, x1: float32, y1: float32, x2: float32, y2: float32, x3: float32, y3: float32) {.inline.} =
  pixie_path_bezier_curve_to(path, x1, y1, x2, y2, x3, y3)

proc pixie_path_quadratic_curve_to(path: Path, x_1: float32, y_1: float32, x_2: float32, y_2: float32) {.importc: "pixie_path_quadratic_curve_to", cdecl.}

proc quadraticCurveTo*(path: Path, x1: float32, y1: float32, x2: float32, y2: float32) {.inline.} =
  pixie_path_quadratic_curve_to(path, x1, y1, x2, y2)

proc pixie_path_elliptical_arc_to(path: Path, rx: float32, ry: float32, x_axis_rotation: float32, large_arc_flag: bool, sweep_flag: bool, x: float32, y: float32) {.importc: "pixie_path_elliptical_arc_to", cdecl.}

proc ellipticalArcTo*(path: Path, rx: float32, ry: float32, xAxisRotation: float32, largeArcFlag: bool, sweepFlag: bool, x: float32, y: float32) {.inline.} =
  pixie_path_elliptical_arc_to(path, rx, ry, xAxisRotation, largeArcFlag, sweepFlag, x, y)

proc pixie_path_arc(path: Path, x: float32, y: float32, r: float32, a_0: float32, a_1: float32, ccw: bool) {.importc: "pixie_path_arc", cdecl.}

proc arc*(path: Path, x: float32, y: float32, r: float32, a0: float32, a1: float32, ccw: bool) {.inline.} =
  pixie_path_arc(path, x, y, r, a0, a1, ccw)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_path_arc_to(path: Path, x_1: float32, y_1: float32, x_2: float32, y_2: float32, r: float32) {.importc: "pixie_path_arc_to", cdecl.}

proc arcTo*(path: Path, x1: float32, y1: float32, x2: float32, y2: float32, r: float32) {.inline.} =
  pixie_path_arc_to(path, x1, y1, x2, y2, r)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_path_rect(path: Path, x: float32, y: float32, w: float32, h: float32, clockwise: bool) {.importc: "pixie_path_rect", cdecl.}

proc rect*(path: Path, x: float32, y: float32, w: float32, h: float32, clockwise: bool = true) {.inline.} =
  pixie_path_rect(path, x, y, w, h, clockwise)

proc pixie_path_rounded_rect(path: Path, x: float32, y: float32, w: float32, h: float32, nw: float32, ne: float32, se: float32, sw: float32, clockwise: bool) {.importc: "pixie_path_rounded_rect", cdecl.}

proc roundedRect*(path: Path, x: float32, y: float32, w: float32, h: float32, nw: float32, ne: float32, se: float32, sw: float32, clockwise: bool = true) {.inline.} =
  pixie_path_rounded_rect(path, x, y, w, h, nw, ne, se, sw, clockwise)

proc pixie_path_ellipse(path: Path, cx: float32, cy: float32, rx: float32, ry: float32) {.importc: "pixie_path_ellipse", cdecl.}

proc ellipse*(path: Path, cx: float32, cy: float32, rx: float32, ry: float32) {.inline.} =
  pixie_path_ellipse(path, cx, cy, rx, ry)

proc pixie_path_circle(path: Path, cx: float32, cy: float32, r: float32) {.importc: "pixie_path_circle", cdecl.}

proc circle*(path: Path, cx: float32, cy: float32, r: float32) {.inline.} =
  pixie_path_circle(path, cx, cy, r)

proc pixie_path_polygon(path: Path, x: float32, y: float32, size: float32, sides: int) {.importc: "pixie_path_polygon", cdecl.}

proc polygon*(path: Path, x: float32, y: float32, size: float32, sides: int) {.inline.} =
  pixie_path_polygon(path, x, y, size, sides)

proc pixie_typeface_get_file_path(typeface: Typeface): cstring {.importc: "pixie_typeface_get_file_path", cdecl.}

proc filePath*(typeface: Typeface): cstring {.inline.} =
  pixie_typeface_get_file_path(typeface).`$`

proc pixie_typeface_set_file_path(typeface: Typeface, filePath: cstring) {.importc: "pixie_typeface_set_file_path", cdecl.}

proc `filePath=`*(typeface: Typeface, filePath: string) =
  pixie_typeface_set_file_path(typeface, filePath.cstring)

proc pixie_typeface_ascent(typeface: Typeface): float32 {.importc: "pixie_typeface_ascent", cdecl.}

proc ascent*(typeface: Typeface): float32 {.inline.} =
  result = pixie_typeface_ascent(typeface)

proc pixie_typeface_descent(typeface: Typeface): float32 {.importc: "pixie_typeface_descent", cdecl.}

proc descent*(typeface: Typeface): float32 {.inline.} =
  result = pixie_typeface_descent(typeface)

proc pixie_typeface_line_gap(typeface: Typeface): float32 {.importc: "pixie_typeface_line_gap", cdecl.}

proc lineGap*(typeface: Typeface): float32 {.inline.} =
  result = pixie_typeface_line_gap(typeface)

proc pixie_typeface_line_height(typeface: Typeface): float32 {.importc: "pixie_typeface_line_height", cdecl.}

proc lineHeight*(typeface: Typeface): float32 {.inline.} =
  result = pixie_typeface_line_height(typeface)

proc pixie_typeface_get_glyph_path(typeface: Typeface, rune: int32): Path {.importc: "pixie_typeface_get_glyph_path", cdecl.}

proc getGlyphPath*(typeface: Typeface, rune: Rune): Path {.inline.} =
  result = pixie_typeface_get_glyph_path(typeface, rune.int32)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_typeface_get_advance(typeface: Typeface, rune: int32): float32 {.importc: "pixie_typeface_get_advance", cdecl.}

proc getAdvance*(typeface: Typeface, rune: Rune): float32 {.inline.} =
  result = pixie_typeface_get_advance(typeface, rune.int32)

proc pixie_typeface_get_kerning_adjustment(typeface: Typeface, left: int32, right: int32): float32 {.importc: "pixie_typeface_get_kerning_adjustment", cdecl.}

proc getKerningAdjustment*(typeface: Typeface, left: Rune, right: Rune): float32 {.inline.} =
  result = pixie_typeface_get_kerning_adjustment(typeface, left.int32, right.int32)

proc pixie_typeface_new_font(typeface: Typeface): Font {.importc: "pixie_typeface_new_font", cdecl.}

proc newFont*(typeface: Typeface): Font {.inline.} =
  result = pixie_typeface_new_font(typeface)

proc pixie_font_get_typeface(font: Font): Typeface {.importc: "pixie_font_get_typeface", cdecl.}

proc typeface*(font: Font): Typeface {.inline.} =
  pixie_font_get_typeface(font)

proc pixie_font_set_typeface(font: Font, typeface: Typeface) {.importc: "pixie_font_set_typeface", cdecl.}

proc `typeface=`*(font: Font, typeface: Typeface) =
  pixie_font_set_typeface(font, typeface)

proc pixie_font_get_size(font: Font): float32 {.importc: "pixie_font_get_size", cdecl.}

proc size*(font: Font): float32 {.inline.} =
  pixie_font_get_size(font)

proc pixie_font_set_size(font: Font, size: float32) {.importc: "pixie_font_set_size", cdecl.}

proc `size=`*(font: Font, size: float32) =
  pixie_font_set_size(font, size)

proc pixie_font_get_line_height(font: Font): float32 {.importc: "pixie_font_get_line_height", cdecl.}

proc lineHeight*(font: Font): float32 {.inline.} =
  pixie_font_get_line_height(font)

proc pixie_font_set_line_height(font: Font, lineHeight: float32) {.importc: "pixie_font_set_line_height", cdecl.}

proc `lineHeight=`*(font: Font, lineHeight: float32) =
  pixie_font_set_line_height(font, lineHeight)

type FontPaints = object
    font: Font

proc paints*(font: Font): FontPaints =
  FontPaints(font: font)

proc pixie_font_paints_len(s: Font): int {.importc: "pixie_font_paints_len", cdecl.}

proc len*(s: FontPaints): int =
  pixie_font_paints_len(s.font)

proc pixie_font_paints_add(s: Font, v: Paint) {.importc: "pixie_font_paints_add", cdecl.}

proc add*(s: FontPaints, v: Paint) =
  pixie_font_paints_add(s.font, v)

proc pixie_font_paints_get(s: Font, i: int): Paint {.importc: "pixie_font_paints_get", cdecl.}

proc `[]`*(s: FontPaints, i: int): Paint =
  pixie_font_paints_get(s.font, i)

proc pixie_font_paints_set(s: Font, i: int, v: Paint) {.importc: "pixie_font_paints_set", cdecl.}

proc `[]=`*(s: FontPaints, i: int, v: Paint) =
  pixie_font_paints_set(s.font, i, v)

proc pixie_font_paints_delete(s: Font, i: int) {.importc: "pixie_font_paints_delete", cdecl.}

proc delete*(s: FontPaints, i: int) =
  pixie_font_paints_delete(s.font, i)

proc pixie_font_paints_clear(s: Font) {.importc: "pixie_font_paints_clear", cdecl.}

proc clear*(s: FontPaints) =
  pixie_font_paints_clear(s.font)

proc pixie_font_get_text_case(font: Font): TextCase {.importc: "pixie_font_get_text_case", cdecl.}

proc textCase*(font: Font): TextCase {.inline.} =
  pixie_font_get_text_case(font)

proc pixie_font_set_text_case(font: Font, textCase: TextCase) {.importc: "pixie_font_set_text_case", cdecl.}

proc `textCase=`*(font: Font, textCase: TextCase) =
  pixie_font_set_text_case(font, textCase)

proc pixie_font_get_underline(font: Font): bool {.importc: "pixie_font_get_underline", cdecl.}

proc underline*(font: Font): bool {.inline.} =
  pixie_font_get_underline(font)

proc pixie_font_set_underline(font: Font, underline: bool) {.importc: "pixie_font_set_underline", cdecl.}

proc `underline=`*(font: Font, underline: bool) =
  pixie_font_set_underline(font, underline)

proc pixie_font_get_strikethrough(font: Font): bool {.importc: "pixie_font_get_strikethrough", cdecl.}

proc strikethrough*(font: Font): bool {.inline.} =
  pixie_font_get_strikethrough(font)

proc pixie_font_set_strikethrough(font: Font, strikethrough: bool) {.importc: "pixie_font_set_strikethrough", cdecl.}

proc `strikethrough=`*(font: Font, strikethrough: bool) =
  pixie_font_set_strikethrough(font, strikethrough)

proc pixie_font_get_no_kerning_adjustments(font: Font): bool {.importc: "pixie_font_get_no_kerning_adjustments", cdecl.}

proc noKerningAdjustments*(font: Font): bool {.inline.} =
  pixie_font_get_no_kerning_adjustments(font)

proc pixie_font_set_no_kerning_adjustments(font: Font, noKerningAdjustments: bool) {.importc: "pixie_font_set_no_kerning_adjustments", cdecl.}

proc `noKerningAdjustments=`*(font: Font, noKerningAdjustments: bool) =
  pixie_font_set_no_kerning_adjustments(font, noKerningAdjustments)

proc pixie_font_scale(font: Font): float32 {.importc: "pixie_font_scale", cdecl.}

proc scale*(font: Font): float32 {.inline.} =
  result = pixie_font_scale(font)

proc pixie_font_default_line_height(font: Font): float32 {.importc: "pixie_font_default_line_height", cdecl.}

proc defaultLineHeight*(font: Font): float32 {.inline.} =
  result = pixie_font_default_line_height(font)

proc pixie_font_typeset(font: Font, text: cstring, bounds: Vec2, h_align: HorizontalAlignment, v_align: VerticalAlignment, wrap: bool): Arrangement {.importc: "pixie_font_typeset", cdecl.}

proc typeset*(font: Font, text: string, bounds: Vec2 = vec2(0, 0), hAlign: HorizontalAlignment = haLeft, vAlign: VerticalAlignment = vaTop, wrap: bool = true): Arrangement {.inline.} =
  result = pixie_font_typeset(font, text.cstring, bounds, hAlign, vAlign, wrap)

proc pixie_font_compute_bounds(font: Font, text: cstring): Vec2 {.importc: "pixie_font_compute_bounds", cdecl.}

proc computeBounds*(font: Font, text: string): Vec2 {.inline.} =
  result = pixie_font_compute_bounds(font, text.cstring)

proc pixie_new_span(text: cstring, font: Font): Span {.importc: "pixie_new_span", cdecl.}

proc newSpan*(text: string, font: Font): Span {.inline.} =
  result = pixie_new_span(text.cstring, font)

proc pixie_span_get_text(span: Span): cstring {.importc: "pixie_span_get_text", cdecl.}

proc text*(span: Span): cstring {.inline.} =
  pixie_span_get_text(span).`$`

proc pixie_span_set_text(span: Span, text: cstring) {.importc: "pixie_span_set_text", cdecl.}

proc `text=`*(span: Span, text: string) =
  pixie_span_set_text(span, text.cstring)

proc pixie_span_get_font(span: Span): Font {.importc: "pixie_span_get_font", cdecl.}

proc font*(span: Span): Font {.inline.} =
  pixie_span_get_font(span)

proc pixie_span_set_font(span: Span, font: Font) {.importc: "pixie_span_set_font", cdecl.}

proc `font=`*(span: Span, font: Font) =
  pixie_span_set_font(span, font)

proc pixie_arrangement_compute_bounds(arrangement: Arrangement): Vec2 {.importc: "pixie_arrangement_compute_bounds", cdecl.}

proc computeBounds*(arrangement: Arrangement): Vec2 {.inline.} =
  result = pixie_arrangement_compute_bounds(arrangement)

proc pixie_new_context(width: int, height: int): Context {.importc: "pixie_new_context", cdecl.}

proc newContext*(width: int, height: int): Context {.inline.} =
  result = pixie_new_context(width, height)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_get_image(context: Context): Image {.importc: "pixie_context_get_image", cdecl.}

proc image*(context: Context): Image {.inline.} =
  pixie_context_get_image(context)

proc pixie_context_set_image(context: Context, image: Image) {.importc: "pixie_context_set_image", cdecl.}

proc `image=`*(context: Context, image: Image) =
  pixie_context_set_image(context, image)

proc pixie_context_get_fill_style(context: Context): Paint {.importc: "pixie_context_get_fill_style", cdecl.}

proc fillStyle*(context: Context): Paint {.inline.} =
  pixie_context_get_fill_style(context)

proc pixie_context_set_fill_style(context: Context, fillStyle: Paint) {.importc: "pixie_context_set_fill_style", cdecl.}

proc `fillStyle=`*(context: Context, fillStyle: Paint) =
  pixie_context_set_fill_style(context, fillStyle)

proc pixie_context_get_stroke_style(context: Context): Paint {.importc: "pixie_context_get_stroke_style", cdecl.}

proc strokeStyle*(context: Context): Paint {.inline.} =
  pixie_context_get_stroke_style(context)

proc pixie_context_set_stroke_style(context: Context, strokeStyle: Paint) {.importc: "pixie_context_set_stroke_style", cdecl.}

proc `strokeStyle=`*(context: Context, strokeStyle: Paint) =
  pixie_context_set_stroke_style(context, strokeStyle)

proc pixie_context_get_global_alpha(context: Context): float32 {.importc: "pixie_context_get_global_alpha", cdecl.}

proc globalAlpha*(context: Context): float32 {.inline.} =
  pixie_context_get_global_alpha(context)

proc pixie_context_set_global_alpha(context: Context, globalAlpha: float32) {.importc: "pixie_context_set_global_alpha", cdecl.}

proc `globalAlpha=`*(context: Context, globalAlpha: float32) =
  pixie_context_set_global_alpha(context, globalAlpha)

proc pixie_context_get_line_width(context: Context): float32 {.importc: "pixie_context_get_line_width", cdecl.}

proc lineWidth*(context: Context): float32 {.inline.} =
  pixie_context_get_line_width(context)

proc pixie_context_set_line_width(context: Context, lineWidth: float32) {.importc: "pixie_context_set_line_width", cdecl.}

proc `lineWidth=`*(context: Context, lineWidth: float32) =
  pixie_context_set_line_width(context, lineWidth)

proc pixie_context_get_miter_limit(context: Context): float32 {.importc: "pixie_context_get_miter_limit", cdecl.}

proc miterLimit*(context: Context): float32 {.inline.} =
  pixie_context_get_miter_limit(context)

proc pixie_context_set_miter_limit(context: Context, miterLimit: float32) {.importc: "pixie_context_set_miter_limit", cdecl.}

proc `miterLimit=`*(context: Context, miterLimit: float32) =
  pixie_context_set_miter_limit(context, miterLimit)

proc pixie_context_get_line_cap(context: Context): LineCap {.importc: "pixie_context_get_line_cap", cdecl.}

proc lineCap*(context: Context): LineCap {.inline.} =
  pixie_context_get_line_cap(context)

proc pixie_context_set_line_cap(context: Context, lineCap: LineCap) {.importc: "pixie_context_set_line_cap", cdecl.}

proc `lineCap=`*(context: Context, lineCap: LineCap) =
  pixie_context_set_line_cap(context, lineCap)

proc pixie_context_get_line_join(context: Context): LineJoin {.importc: "pixie_context_get_line_join", cdecl.}

proc lineJoin*(context: Context): LineJoin {.inline.} =
  pixie_context_get_line_join(context)

proc pixie_context_set_line_join(context: Context, lineJoin: LineJoin) {.importc: "pixie_context_set_line_join", cdecl.}

proc `lineJoin=`*(context: Context, lineJoin: LineJoin) =
  pixie_context_set_line_join(context, lineJoin)

proc pixie_context_get_font(context: Context): cstring {.importc: "pixie_context_get_font", cdecl.}

proc font*(context: Context): cstring {.inline.} =
  pixie_context_get_font(context).`$`

proc pixie_context_set_font(context: Context, font: cstring) {.importc: "pixie_context_set_font", cdecl.}

proc `font=`*(context: Context, font: string) =
  pixie_context_set_font(context, font.cstring)

proc pixie_context_get_font_size(context: Context): float32 {.importc: "pixie_context_get_font_size", cdecl.}

proc fontSize*(context: Context): float32 {.inline.} =
  pixie_context_get_font_size(context)

proc pixie_context_set_font_size(context: Context, fontSize: float32) {.importc: "pixie_context_set_font_size", cdecl.}

proc `fontSize=`*(context: Context, fontSize: float32) =
  pixie_context_set_font_size(context, fontSize)

proc pixie_context_get_text_align(context: Context): HorizontalAlignment {.importc: "pixie_context_get_text_align", cdecl.}

proc textAlign*(context: Context): HorizontalAlignment {.inline.} =
  pixie_context_get_text_align(context)

proc pixie_context_set_text_align(context: Context, textAlign: HorizontalAlignment) {.importc: "pixie_context_set_text_align", cdecl.}

proc `textAlign=`*(context: Context, textAlign: HorizontalAlignment) =
  pixie_context_set_text_align(context, textAlign)

proc pixie_context_save(ctx: Context) {.importc: "pixie_context_save", cdecl.}

proc save*(ctx: Context) {.inline.} =
  pixie_context_save(ctx)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_save_layer(ctx: Context) {.importc: "pixie_context_save_layer", cdecl.}

proc saveLayer*(ctx: Context) {.inline.} =
  pixie_context_save_layer(ctx)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_restore(ctx: Context) {.importc: "pixie_context_restore", cdecl.}

proc restore*(ctx: Context) {.inline.} =
  pixie_context_restore(ctx)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_begin_path(ctx: Context) {.importc: "pixie_context_begin_path", cdecl.}

proc beginPath*(ctx: Context) {.inline.} =
  pixie_context_begin_path(ctx)

proc pixie_context_close_path(ctx: Context) {.importc: "pixie_context_close_path", cdecl.}

proc closePath*(ctx: Context) {.inline.} =
  pixie_context_close_path(ctx)

proc pixie_context_fill(ctx: Context, winding_rule: WindingRule) {.importc: "pixie_context_fill", cdecl.}

proc fill*(ctx: Context, windingRule: WindingRule = wrNonZero) {.inline.} =
  pixie_context_fill(ctx, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_path_fill(ctx: Context, path: Path, winding_rule: WindingRule) {.importc: "pixie_context_path_fill", cdecl.}

proc fill*(ctx: Context, path: Path, windingRule: WindingRule = wrNonZero) {.inline.} =
  pixie_context_path_fill(ctx, path, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_clip(ctx: Context, winding_rule: WindingRule) {.importc: "pixie_context_clip", cdecl.}

proc clip*(ctx: Context, windingRule: WindingRule = wrNonZero) {.inline.} =
  pixie_context_clip(ctx, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_path_clip(ctx: Context, path: Path, winding_rule: WindingRule) {.importc: "pixie_context_path_clip", cdecl.}

proc clip*(ctx: Context, path: Path, windingRule: WindingRule = wrNonZero) {.inline.} =
  pixie_context_path_clip(ctx, path, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_stroke(ctx: Context) {.importc: "pixie_context_stroke", cdecl.}

proc stroke*(ctx: Context) {.inline.} =
  pixie_context_stroke(ctx)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_path_stroke(ctx: Context, path: Path) {.importc: "pixie_context_path_stroke", cdecl.}

proc stroke*(ctx: Context, path: Path) {.inline.} =
  pixie_context_path_stroke(ctx, path)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_measure_text(ctx: Context, text: cstring): TextMetrics {.importc: "pixie_context_measure_text", cdecl.}

proc measureText*(ctx: Context, text: string): TextMetrics {.inline.} =
  result = pixie_context_measure_text(ctx, text.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_get_transform(ctx: Context): Mat3 {.importc: "pixie_context_get_transform", cdecl.}

proc getTransform*(ctx: Context): Mat3 {.inline.} =
  result = pixie_context_get_transform(ctx)

proc pixie_context_set_transform(ctx: Context, transform: Mat3) {.importc: "pixie_context_set_transform", cdecl.}

proc setTransform*(ctx: Context, transform: Mat3) {.inline.} =
  pixie_context_set_transform(ctx, transform)

proc pixie_context_transform(ctx: Context, transform: Mat3) {.importc: "pixie_context_transform", cdecl.}

proc transform*(ctx: Context, transform: Mat3) {.inline.} =
  pixie_context_transform(ctx, transform)

proc pixie_context_reset_transform(ctx: Context) {.importc: "pixie_context_reset_transform", cdecl.}

proc resetTransform*(ctx: Context) {.inline.} =
  pixie_context_reset_transform(ctx)

proc pixie_context_draw_image_1(ctx: Context, image: Image, dx: float32, dy: float32) {.importc: "pixie_context_draw_image_1", cdecl.}

proc drawImage1*(ctx: Context, image: Image, dx: float32, dy: float32) {.inline.} =
  pixie_context_draw_image_1(ctx, image, dx, dy)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_draw_image_2(ctx: Context, image: Image, dx: float32, dy: float32, d_width: float32, d_height: float32) {.importc: "pixie_context_draw_image_2", cdecl.}

proc drawImage2*(ctx: Context, image: Image, dx: float32, dy: float32, dWidth: float32, dHeight: float32) {.inline.} =
  pixie_context_draw_image_2(ctx, image, dx, dy, dWidth, dHeight)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_draw_image_3(ctx: Context, image: Image, sx: float32, sy: float32, s_width: float32, s_height: float32, dx: float32, dy: float32, d_width: float32, d_height: float32) {.importc: "pixie_context_draw_image_3", cdecl.}

proc drawImage3*(ctx: Context, image: Image, sx: float32, sy: float32, sWidth: float32, sHeight: float32, dx: float32, dy: float32, dWidth: float32, dHeight: float32) {.inline.} =
  pixie_context_draw_image_3(ctx, image, sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_move_to(ctx: Context, x: float32, y: float32) {.importc: "pixie_context_move_to", cdecl.}

proc moveTo*(ctx: Context, x: float32, y: float32) {.inline.} =
  pixie_context_move_to(ctx, x, y)

proc pixie_context_line_to(ctx: Context, x: float32, y: float32) {.importc: "pixie_context_line_to", cdecl.}

proc lineTo*(ctx: Context, x: float32, y: float32) {.inline.} =
  pixie_context_line_to(ctx, x, y)

proc pixie_context_bezier_curve_to(ctx: Context, cp_1x: float32, cp_1y: float32, cp_2x: float32, cp_2y: float32, x: float32, y: float32) {.importc: "pixie_context_bezier_curve_to", cdecl.}

proc bezierCurveTo*(ctx: Context, cp1x: float32, cp1y: float32, cp2x: float32, cp2y: float32, x: float32, y: float32) {.inline.} =
  pixie_context_bezier_curve_to(ctx, cp1x, cp1y, cp2x, cp2y, x, y)

proc pixie_context_quadratic_curve_to(ctx: Context, cpx: float32, cpy: float32, x: float32, y: float32) {.importc: "pixie_context_quadratic_curve_to", cdecl.}

proc quadraticCurveTo*(ctx: Context, cpx: float32, cpy: float32, x: float32, y: float32) {.inline.} =
  pixie_context_quadratic_curve_to(ctx, cpx, cpy, x, y)

proc pixie_context_arc(ctx: Context, x: float32, y: float32, r: float32, a_0: float32, a_1: float32, ccw: bool) {.importc: "pixie_context_arc", cdecl.}

proc arc*(ctx: Context, x: float32, y: float32, r: float32, a0: float32, a1: float32, ccw: bool = false) {.inline.} =
  pixie_context_arc(ctx, x, y, r, a0, a1, ccw)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_arc_to(ctx: Context, x_1: float32, y_1: float32, x_2: float32, y_2: float32, radius: float32) {.importc: "pixie_context_arc_to", cdecl.}

proc arcTo*(ctx: Context, x1: float32, y1: float32, x2: float32, y2: float32, radius: float32) {.inline.} =
  pixie_context_arc_to(ctx, x1, y1, x2, y2, radius)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_rect(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.importc: "pixie_context_rect", cdecl.}

proc rect*(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.inline.} =
  pixie_context_rect(ctx, x, y, width, height)

proc pixie_context_rounded_rect(ctx: Context, x: float32, y: float32, w: float32, h: float32, nw: float32, ne: float32, se: float32, sw: float32) {.importc: "pixie_context_rounded_rect", cdecl.}

proc roundedRect*(ctx: Context, x: float32, y: float32, w: float32, h: float32, nw: float32, ne: float32, se: float32, sw: float32) {.inline.} =
  pixie_context_rounded_rect(ctx, x, y, w, h, nw, ne, se, sw)

proc pixie_context_ellipse(ctx: Context, x: float32, y: float32, rx: float32, ry: float32) {.importc: "pixie_context_ellipse", cdecl.}

proc ellipse*(ctx: Context, x: float32, y: float32, rx: float32, ry: float32) {.inline.} =
  pixie_context_ellipse(ctx, x, y, rx, ry)

proc pixie_context_circle(ctx: Context, cx: float32, cy: float32, r: float32) {.importc: "pixie_context_circle", cdecl.}

proc circle*(ctx: Context, cx: float32, cy: float32, r: float32) {.inline.} =
  pixie_context_circle(ctx, cx, cy, r)

proc pixie_context_polygon(ctx: Context, x: float32, y: float32, size: float32, sides: int) {.importc: "pixie_context_polygon", cdecl.}

proc polygon*(ctx: Context, x: float32, y: float32, size: float32, sides: int) {.inline.} =
  pixie_context_polygon(ctx, x, y, size, sides)

proc pixie_context_clear_rect(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.importc: "pixie_context_clear_rect", cdecl.}

proc clearRect*(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.inline.} =
  pixie_context_clear_rect(ctx, x, y, width, height)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_fill_rect(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.importc: "pixie_context_fill_rect", cdecl.}

proc fillRect*(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.inline.} =
  pixie_context_fill_rect(ctx, x, y, width, height)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_stroke_rect(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.importc: "pixie_context_stroke_rect", cdecl.}

proc strokeRect*(ctx: Context, x: float32, y: float32, width: float32, height: float32) {.inline.} =
  pixie_context_stroke_rect(ctx, x, y, width, height)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_fill_text(ctx: Context, text: cstring, x: float32, y: float32) {.importc: "pixie_context_fill_text", cdecl.}

proc fillText*(ctx: Context, text: string, x: float32, y: float32) {.inline.} =
  pixie_context_fill_text(ctx, text.cstring, x, y)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_stroke_text(ctx: Context, text: cstring, x: float32, y: float32) {.importc: "pixie_context_stroke_text", cdecl.}

proc strokeText*(ctx: Context, text: string, x: float32, y: float32) {.inline.} =
  pixie_context_stroke_text(ctx, text.cstring, x, y)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_translate(ctx: Context, x: float32, y: float32) {.importc: "pixie_context_translate", cdecl.}

proc translate*(ctx: Context, x: float32, y: float32) {.inline.} =
  pixie_context_translate(ctx, x, y)

proc pixie_context_scale(ctx: Context, x: float32, y: float32) {.importc: "pixie_context_scale", cdecl.}

proc scale*(ctx: Context, x: float32, y: float32) {.inline.} =
  pixie_context_scale(ctx, x, y)

proc pixie_context_rotate(ctx: Context, angle: float32) {.importc: "pixie_context_rotate", cdecl.}

proc rotate*(ctx: Context, angle: float32) {.inline.} =
  pixie_context_rotate(ctx, angle)

proc pixie_context_is_point_in_path(ctx: Context, x: float32, y: float32, winding_rule: WindingRule): bool {.importc: "pixie_context_is_point_in_path", cdecl.}

proc isPointInPath*(ctx: Context, x: float32, y: float32, windingRule: WindingRule = wrNonZero): bool {.inline.} =
  result = pixie_context_is_point_in_path(ctx, x, y, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_path_is_point_in_path(ctx: Context, path: Path, x: float32, y: float32, winding_rule: WindingRule): bool {.importc: "pixie_context_path_is_point_in_path", cdecl.}

proc isPointInPath*(ctx: Context, path: Path, x: float32, y: float32, windingRule: WindingRule = wrNonZero): bool {.inline.} =
  result = pixie_context_path_is_point_in_path(ctx, path, x, y, windingRule)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_is_point_in_stroke(ctx: Context, x: float32, y: float32): bool {.importc: "pixie_context_is_point_in_stroke", cdecl.}

proc isPointInStroke*(ctx: Context, x: float32, y: float32): bool {.inline.} =
  result = pixie_context_is_point_in_stroke(ctx, x, y)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_context_path_is_point_in_stroke(ctx: Context, path: Path, x: float32, y: float32): bool {.importc: "pixie_context_path_is_point_in_stroke", cdecl.}

proc isPointInStroke*(ctx: Context, path: Path, x: float32, y: float32): bool {.inline.} =
  result = pixie_context_path_is_point_in_stroke(ctx, path, x, y)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_read_image(file_path: cstring): Image {.importc: "pixie_read_image", cdecl.}

proc readImage*(filePath: string): Image {.inline.} =
  result = pixie_read_image(filePath.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_read_mask(file_path: cstring): Mask {.importc: "pixie_read_mask", cdecl.}

proc readMask*(filePath: string): Mask {.inline.} =
  result = pixie_read_mask(filePath.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_read_typeface(file_path: cstring): Typeface {.importc: "pixie_read_typeface", cdecl.}

proc readTypeface*(filePath: string): Typeface {.inline.} =
  result = pixie_read_typeface(filePath.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_read_font(file_path: cstring): Font {.importc: "pixie_read_font", cdecl.}

proc readFont*(filePath: string): Font {.inline.} =
  result = pixie_read_font(filePath.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_parse_path(path: cstring): Path {.importc: "pixie_parse_path", cdecl.}

proc parsePath*(path: string): Path {.inline.} =
  result = pixie_parse_path(path.cstring)
  if checkError():
    raise newException(PixieError, $takeError())

proc pixie_miter_limit_to_angle(limit: float32): float32 {.importc: "pixie_miter_limit_to_angle", cdecl.}

proc miterLimitToAngle*(limit: float32): float32 {.inline.} =
  result = pixie_miter_limit_to_angle(limit)

proc pixie_angle_to_miter_limit(angle: float32): float32 {.importc: "pixie_angle_to_miter_limit", cdecl.}

proc angleToMiterLimit*(angle: float32): float32 {.inline.} =
  result = pixie_angle_to_miter_limit(angle)
