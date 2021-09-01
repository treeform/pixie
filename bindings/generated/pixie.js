var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");

var dll = {};

function PixieException(message) {
  this.message = message;
  this.name = 'PixieException';
}

const FileFormat = 'int8'

const BlendMode = 'int8'

const PaintKind = 'int8'

const WindingRule = 'int8'

const LineCap = 'int8'

const LineJoin = 'int8'

const HorizontalAlignment = 'int8'

const VerticalAlignment = 'int8'

const TextCase = 'int8'

function checkError(){
  result = dll.pixie_check_error()
  return result
}

function takeError(){
  result = dll.pixie_take_error()
  return result
}

const Vector2 = Struct({
  'x':'float',
  'y':'float'
})
vector2 = function(x, y){
  var v = new Vector2();
  v.x = x
  v.y = y
  return v;
}

const Matrix3 = Struct({
  'a':'float',
  'b':'float',
  'c':'float',
  'd':'float',
  'e':'float',
  'f':'float',
  'g':'float',
  'h':'float',
  'i':'float'
})
matrix3 = function(){
  return dll.pixie_matrix_3();
}

const Rect = Struct({
  'x':'float',
  'y':'float',
  'w':'float',
  'h':'float'
})
rect = function(x, y, w, h){
  var v = new Rect();
  v.x = x
  v.y = y
  v.w = w
  v.h = h
  return v;
}

const Color = Struct({
  'r':'float',
  'g':'float',
  'b':'float',
  'a':'float'
})
color = function(r, g, b, a){
  var v = new Color();
  v.r = r
  v.g = g
  v.b = b
  v.a = a
  return v;
}

const ColorStop = Struct({
  'color':Color,
  'position':'float'
})
colorStop = function(color, position){
  var v = new ColorStop();
  v.color = color
  v.position = position
  return v;
}

const TextMetrics = Struct({
  'width':'float'
})
textMetrics = function(width){
  var v = new TextMetrics();
  v.width = width
  return v;
}

SeqFloat32 = Struct({'nimRef': 'uint64'});
SeqFloat32.prototype.unref = function(){
  return dll.pixie_seq_float_32_unref(this)
};
function seqFloat32(){
  return dll.pixie_new_seq_float_32();
}
SeqFloat32.prototype.length = function(){
  return dll.pixie_seq_float_32_len(this)
};
SeqFloat32.prototype.get = function(index){
  return dll.pixie_seq_float_32_get(this, index)
};
SeqFloat32.prototype.set = function(index, value){
  dll.pixie_seq_float_32_set(this, index, value)
};
SeqFloat32.prototype.delete = function(index){
  dll.pixie_seq_float_32_delete(this, index)
};
SeqFloat32.prototype.add = function(value){
  dll.pixie_seq_float_32_add(this, value)
};
SeqFloat32.prototype.clear = function(){
  dll.pixie_seq_float_32_clear(this)
};
SeqSpan = Struct({'nimRef': 'uint64'});
SeqSpan.prototype.unref = function(){
  return dll.pixie_seq_span_unref(this)
};
function seqSpan(){
  return dll.pixie_new_seq_span();
}
SeqSpan.prototype.length = function(){
  return dll.pixie_seq_span_len(this)
};
SeqSpan.prototype.get = function(index){
  return dll.pixie_seq_span_get(this, index)
};
SeqSpan.prototype.set = function(index, value){
  dll.pixie_seq_span_set(this, index, value)
};
SeqSpan.prototype.delete = function(index){
  dll.pixie_seq_span_delete(this, index)
};
SeqSpan.prototype.add = function(value){
  dll.pixie_seq_span_add(this, value)
};
SeqSpan.prototype.clear = function(){
  dll.pixie_seq_span_clear(this)
};
SeqSpan.prototype.typeset = function(bounds = Vector2(0, 0), h_align = HA_LEFT, v_align = VA_TOP, wrap = True){
  result = dll.pixie_seq_span_typeset(this, bounds, h_align, v_align, wrap)
  return result
}

SeqSpan.prototype.computeBounds = function(){
  result = dll.pixie_seq_span_compute_bounds(this)
  return result
}

Image = Struct({'nimRef': 'uint64'});
Image.prototype.unref = function(){
  return dll.pixie_image_unref(this)
};
exports.image = function(width, height){
  var result = dll.pixie_new_image(width, height)
  if(checkError()) throw new PixieException(takeError());
  return result
}
Object.defineProperty(Image.prototype, 'width', {
  get: function() {return dll.pixie_image_get_width(this)},
  set: function(v) {dll.pixie_image_set_width(this, v)}
});
Object.defineProperty(Image.prototype, 'height', {
  get: function() {return dll.pixie_image_get_height(this)},
  set: function(v) {dll.pixie_image_set_height(this, v)}
});

Image.prototype.writeFile = function(file_path){
  dll.pixie_image_write_file(this, file_path)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.wh = function(){
  result = dll.pixie_image_wh(this)
  return result
}

Image.prototype.copy = function(){
  result = dll.pixie_image_copy(this)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.getColor = function(x, y){
  result = dll.pixie_image_get_color(this, x, y)
  return result
}

Image.prototype.setColor = function(x, y, color){
  dll.pixie_image_set_color(this, x, y, color)
}

Image.prototype.fill = function(color){
  dll.pixie_image_fill(this, color)
}

Image.prototype.flipHorizontal = function(){
  dll.pixie_image_flip_horizontal(this)
}

Image.prototype.flipVertical = function(){
  dll.pixie_image_flip_vertical(this)
}

Image.prototype.subImage = function(x, y, w, h){
  result = dll.pixie_image_sub_image(this, x, y, w, h)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.minifyBy2 = function(power = 1){
  result = dll.pixie_image_minify_by_2(this, power)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.magnifyBy2 = function(power = 1){
  result = dll.pixie_image_magnify_by_2(this, power)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.applyOpacity = function(opacity){
  dll.pixie_image_apply_opacity(this, opacity)
}

Image.prototype.invert = function(){
  dll.pixie_image_invert(this)
}

Image.prototype.blur = function(radius, out_of_bounds = Color()){
  dll.pixie_image_blur(this, radius, out_of_bounds)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.newMask = function(){
  result = dll.pixie_image_new_mask(this)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.resize = function(width, height){
  result = dll.pixie_image_resize(this, width, height)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.shadow = function(offset, spread, blur, color){
  result = dll.pixie_image_shadow(this, offset, spread, blur, color)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.superImage = function(x, y, w, h){
  result = dll.pixie_image_super_image(this, x, y, w, h)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Image.prototype.draw = function(b, transform = Matrix3(), blend_mode = BM_NORMAL){
  dll.pixie_image_draw(this, b, transform, blend_mode)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.mask_draw = function(mask, transform = Matrix3(), blend_mode = BM_MASK){
  dll.pixie_image_mask_draw(this, mask, transform, blend_mode)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.fillGradient = function(paint){
  dll.pixie_image_fill_gradient(this, paint)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.fillText = function(font, text, transform = Matrix3(), bounds = Vector2(0, 0), h_align = HA_LEFT, v_align = VA_TOP){
  dll.pixie_image_fill_text(this, font, text, transform, bounds, h_align, v_align)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.arrangement_fillText = function(arrangement, transform = Matrix3()){
  dll.pixie_image_arrangement_fill_text(this, arrangement, transform)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.strokeText = function(font, text, transform = Matrix3(), stroke_width = 1.0, bounds = Vector2(0, 0), h_align = HA_LEFT, v_align = VA_TOP, line_cap = LC_BUTT, line_join = LJ_MITER, miter_limit = DEFAULT_MITER_LIMIT, dashes = SeqFloat32([])){
  dll.pixie_image_stroke_text(this, font, text, transform, stroke_width, bounds, h_align, v_align, line_cap, line_join, miter_limit, dashes)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.arrangement_strokeText = function(arrangement, transform = Matrix3(), stroke_width = 1.0, line_cap = LC_BUTT, line_join = LJ_MITER, miter_limit = DEFAULT_MITER_LIMIT, dashes = SeqFloat32([])){
  dll.pixie_image_arrangement_stroke_text(this, arrangement, transform, stroke_width, line_cap, line_join, miter_limit, dashes)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.fillPath = function(path, paint, transform = Matrix3(), winding_rule = WR_NON_ZERO){
  dll.pixie_image_fill_path(this, path, paint, transform, winding_rule)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.strokePath = function(path, paint, transform = Matrix3(), stroke_width = 1.0, line_cap = LC_BUTT, line_join = LJ_MITER, miter_limit = DEFAULT_MITER_LIMIT, dashes = SeqFloat32([])){
  dll.pixie_image_stroke_path(this, path, paint, transform, stroke_width, line_cap, line_join, miter_limit, dashes)
  if(checkError()) throw new PixieException(takeError());
}

Image.prototype.newContext = function(){
  result = dll.pixie_image_new_context(this)
  return result
}

Mask = Struct({'nimRef': 'uint64'});
Mask.prototype.unref = function(){
  return dll.pixie_mask_unref(this)
};
exports.mask = function(width, height){
  var result = dll.pixie_new_mask(width, height)
  if(checkError()) throw new PixieException(takeError());
  return result
}
Object.defineProperty(Mask.prototype, 'width', {
  get: function() {return dll.pixie_mask_get_width(this)},
  set: function(v) {dll.pixie_mask_set_width(this, v)}
});
Object.defineProperty(Mask.prototype, 'height', {
  get: function() {return dll.pixie_mask_get_height(this)},
  set: function(v) {dll.pixie_mask_set_height(this, v)}
});

Mask.prototype.writeFile = function(file_path){
  dll.pixie_mask_write_file(this, file_path)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.wh = function(){
  result = dll.pixie_mask_wh(this)
  return result
}

Mask.prototype.copy = function(){
  result = dll.pixie_mask_copy(this)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Mask.prototype.getValue = function(x, y){
  result = dll.pixie_mask_get_value(this, x, y)
  return result
}

Mask.prototype.setValue = function(x, y, value){
  dll.pixie_mask_set_value(this, x, y, value)
}

Mask.prototype.fill = function(value){
  dll.pixie_mask_fill(this, value)
}

Mask.prototype.minifyBy2 = function(power = 1){
  result = dll.pixie_mask_minify_by_2(this, power)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Mask.prototype.spread = function(spread){
  dll.pixie_mask_spread(this, spread)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.ceil = function(){
  dll.pixie_mask_ceil(this)
}

Mask.prototype.newImage = function(){
  result = dll.pixie_mask_new_image(this)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Mask.prototype.applyOpacity = function(opacity){
  dll.pixie_mask_apply_opacity(this, opacity)
}

Mask.prototype.invert = function(){
  dll.pixie_mask_invert(this)
}

Mask.prototype.blur = function(radius, out_of_bounds = 0){
  dll.pixie_mask_blur(this, radius, out_of_bounds)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.draw = function(b, transform = Matrix3(), blend_mode = BM_MASK){
  dll.pixie_mask_draw(this, b, transform, blend_mode)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.image_draw = function(image, transform = Matrix3(), blend_mode = BM_MASK){
  dll.pixie_mask_image_draw(this, image, transform, blend_mode)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.fillText = function(font, text, transform = Matrix3(), bounds = Vector2(0, 0), h_align = HA_LEFT, v_align = VA_TOP){
  dll.pixie_mask_fill_text(this, font, text, transform, bounds, h_align, v_align)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.arrangement_fillText = function(arrangement, transform = Matrix3()){
  dll.pixie_mask_arrangement_fill_text(this, arrangement, transform)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.strokeText = function(font, text, transform = Matrix3(), stroke_width = 1.0, bounds = Vector2(0, 0), h_align = HA_LEFT, v_align = VA_TOP, line_cap = LC_BUTT, line_join = LJ_MITER, miter_limit = DEFAULT_MITER_LIMIT, dashes = SeqFloat32([])){
  dll.pixie_mask_stroke_text(this, font, text, transform, stroke_width, bounds, h_align, v_align, line_cap, line_join, miter_limit, dashes)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.arrangement_strokeText = function(arrangement, transform = Matrix3(), stroke_width = 1.0, line_cap = LC_BUTT, line_join = LJ_MITER, miter_limit = DEFAULT_MITER_LIMIT, dashes = SeqFloat32([])){
  dll.pixie_mask_arrangement_stroke_text(this, arrangement, transform, stroke_width, line_cap, line_join, miter_limit, dashes)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.fillPath = function(path, transform = Matrix3(), winding_rule = WR_NON_ZERO, blend_mode = BM_NORMAL){
  dll.pixie_mask_fill_path(this, path, transform, winding_rule, blend_mode)
  if(checkError()) throw new PixieException(takeError());
}

Mask.prototype.strokePath = function(path, transform = Matrix3(), stroke_width = 1.0, line_cap = LC_BUTT, line_join = LJ_MITER, miter_limit = DEFAULT_MITER_LIMIT, dashes = SeqFloat32([]), blend_mode = BM_NORMAL){
  dll.pixie_mask_stroke_path(this, path, transform, stroke_width, line_cap, line_join, miter_limit, dashes, blend_mode)
  if(checkError()) throw new PixieException(takeError());
}

Paint = Struct({'nimRef': 'uint64'});
Paint.prototype.unref = function(){
  return dll.pixie_paint_unref(this)
};
exports.paint = function(kind){
  var result = dll.pixie_new_paint(kind)
  return result
}
Object.defineProperty(Paint.prototype, 'kind', {
  get: function() {return dll.pixie_paint_get_kind(this)},
  set: function(v) {dll.pixie_paint_set_kind(this, v)}
});
Object.defineProperty(Paint.prototype, 'blendMode', {
  get: function() {return dll.pixie_paint_get_blend_mode(this)},
  set: function(v) {dll.pixie_paint_set_blend_mode(this, v)}
});
Object.defineProperty(Paint.prototype, 'opacity', {
  get: function() {return dll.pixie_paint_get_opacity(this)},
  set: function(v) {dll.pixie_paint_set_opacity(this, v)}
});
Object.defineProperty(Paint.prototype, 'color', {
  get: function() {return dll.pixie_paint_get_color(this)},
  set: function(v) {dll.pixie_paint_set_color(this, v)}
});
Object.defineProperty(Paint.prototype, 'image', {
  get: function() {return dll.pixie_paint_get_image(this)},
  set: function(v) {dll.pixie_paint_set_image(this, v)}
});
Object.defineProperty(Paint.prototype, 'imageMat', {
  get: function() {return dll.pixie_paint_get_image_mat(this)},
  set: function(v) {dll.pixie_paint_set_image_mat(this, v)}
});
function PaintGradientHandlePositions(paint){
  this.paint = paint;
}
PaintGradientHandlePositions.prototype.length = function(){
  return dll.pixie_paint_gradient_handle_positions_len(this.paint)
};
PaintGradientHandlePositions.prototype.get = function(index){
  return dll.pixie_paint_gradient_handle_positions_get(this.paint, index)
};
PaintGradientHandlePositions.prototype.set = function(index, value){
  dll.pixie_paint_gradient_handle_positions_set(this.paint, index, value)
};
PaintGradientHandlePositions.prototype.delete = function(index){
  dll.pixie_paint_gradient_handle_positions_delete(this.paint, index)
};
PaintGradientHandlePositions.prototype.add = function(value){
  dll.pixie_paint_gradient_handle_positions_add(this.paint, value)
};
PaintGradientHandlePositions.prototype.clear = function(){
  dll.pixie_paint_gradient_handle_positions_clear(this.paint)
};
Object.defineProperty(Paint.prototype, 'gradientHandlePositions', {
  get: function() {return new PaintGradientHandlePositions(this)},
});
function PaintGradientStops(paint){
  this.paint = paint;
}
PaintGradientStops.prototype.length = function(){
  return dll.pixie_paint_gradient_stops_len(this.paint)
};
PaintGradientStops.prototype.get = function(index){
  return dll.pixie_paint_gradient_stops_get(this.paint, index)
};
PaintGradientStops.prototype.set = function(index, value){
  dll.pixie_paint_gradient_stops_set(this.paint, index, value)
};
PaintGradientStops.prototype.delete = function(index){
  dll.pixie_paint_gradient_stops_delete(this.paint, index)
};
PaintGradientStops.prototype.add = function(value){
  dll.pixie_paint_gradient_stops_add(this.paint, value)
};
PaintGradientStops.prototype.clear = function(){
  dll.pixie_paint_gradient_stops_clear(this.paint)
};
Object.defineProperty(Paint.prototype, 'gradientStops', {
  get: function() {return new PaintGradientStops(this)},
});

Paint.prototype.newPaint = function(){
  result = dll.pixie_paint_new_paint(this)
  return result
}

Path = Struct({'nimRef': 'uint64'});
Path.prototype.unref = function(){
  return dll.pixie_path_unref(this)
};
exports.path = function(){
  var result = dll.pixie_new_path()
  return result
}

Path.prototype.transform = function(mat){
  dll.pixie_path_transform(this, mat)
}

Path.prototype.addPath = function(other){
  dll.pixie_path_add_path(this, other)
}

Path.prototype.closePath = function(){
  dll.pixie_path_close_path(this)
}

Path.prototype.computeBounds = function(transform = Matrix3()){
  result = dll.pixie_path_compute_bounds(this, transform)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Path.prototype.fillOverlaps = function(test, transform = Matrix3(), winding_rule = WR_NON_ZERO){
  result = dll.pixie_path_fill_overlaps(this, test, transform, winding_rule)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Path.prototype.strokeOverlaps = function(test, transform = Matrix3(), stroke_width = 1.0, line_cap = LC_BUTT, line_join = LJ_MITER, miter_limit = DEFAULT_MITER_LIMIT, dashes = SeqFloat32([])){
  result = dll.pixie_path_stroke_overlaps(this, test, transform, stroke_width, line_cap, line_join, miter_limit, dashes)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Path.prototype.moveTo = function(x, y){
  dll.pixie_path_move_to(this, x, y)
}

Path.prototype.lineTo = function(x, y){
  dll.pixie_path_line_to(this, x, y)
}

Path.prototype.bezierCurveTo = function(x_1, y_1, x_2, y_2, x_3, y_3){
  dll.pixie_path_bezier_curve_to(this, x_1, y_1, x_2, y_2, x_3, y_3)
}

Path.prototype.quadraticCurveTo = function(x_1, y_1, x_2, y_2){
  dll.pixie_path_quadratic_curve_to(this, x_1, y_1, x_2, y_2)
}

Path.prototype.ellipticalArcTo = function(rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y){
  dll.pixie_path_elliptical_arc_to(this, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y)
}

Path.prototype.arc = function(x, y, r, a_0, a_1, ccw){
  dll.pixie_path_arc(this, x, y, r, a_0, a_1, ccw)
  if(checkError()) throw new PixieException(takeError());
}

Path.prototype.arcTo = function(x_1, y_1, x_2, y_2, r){
  dll.pixie_path_arc_to(this, x_1, y_1, x_2, y_2, r)
  if(checkError()) throw new PixieException(takeError());
}

Path.prototype.rect = function(x, y, w, h, clockwise = True){
  dll.pixie_path_rect(this, x, y, w, h, clockwise)
}

Path.prototype.roundedRect = function(x, y, w, h, nw, ne, se, sw, clockwise = True){
  dll.pixie_path_rounded_rect(this, x, y, w, h, nw, ne, se, sw, clockwise)
}

Path.prototype.ellipse = function(cx, cy, rx, ry){
  dll.pixie_path_ellipse(this, cx, cy, rx, ry)
}

Path.prototype.circle = function(cx, cy, r){
  dll.pixie_path_circle(this, cx, cy, r)
}

Path.prototype.polygon = function(x, y, size, sides){
  dll.pixie_path_polygon(this, x, y, size, sides)
}

Typeface = Struct({'nimRef': 'uint64'});
Typeface.prototype.unref = function(){
  return dll.pixie_typeface_unref(this)
};
Object.defineProperty(Typeface.prototype, 'filePath', {
  get: function() {return dll.pixie_typeface_get_file_path(this)},
  set: function(v) {dll.pixie_typeface_set_file_path(this, v)}
});

Typeface.prototype.ascent = function(){
  result = dll.pixie_typeface_ascent(this)
  return result
}

Typeface.prototype.descent = function(){
  result = dll.pixie_typeface_descent(this)
  return result
}

Typeface.prototype.lineGap = function(){
  result = dll.pixie_typeface_line_gap(this)
  return result
}

Typeface.prototype.lineHeight = function(){
  result = dll.pixie_typeface_line_height(this)
  return result
}

Typeface.prototype.getGlyphPath = function(rune){
  result = dll.pixie_typeface_get_glyph_path(this, rune)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Typeface.prototype.getAdvance = function(rune){
  result = dll.pixie_typeface_get_advance(this, rune)
  return result
}

Typeface.prototype.getKerningAdjustment = function(left, right){
  result = dll.pixie_typeface_get_kerning_adjustment(this, left, right)
  return result
}

Typeface.prototype.newFont = function(){
  result = dll.pixie_typeface_new_font(this)
  return result
}

Font = Struct({'nimRef': 'uint64'});
Font.prototype.unref = function(){
  return dll.pixie_font_unref(this)
};
Object.defineProperty(Font.prototype, 'typeface', {
  get: function() {return dll.pixie_font_get_typeface(this)},
  set: function(v) {dll.pixie_font_set_typeface(this, v)}
});
Object.defineProperty(Font.prototype, 'size', {
  get: function() {return dll.pixie_font_get_size(this)},
  set: function(v) {dll.pixie_font_set_size(this, v)}
});
Object.defineProperty(Font.prototype, 'lineHeight', {
  get: function() {return dll.pixie_font_get_line_height(this)},
  set: function(v) {dll.pixie_font_set_line_height(this, v)}
});
function FontPaints(font){
  this.font = font;
}
FontPaints.prototype.length = function(){
  return dll.pixie_font_paints_len(this.font)
};
FontPaints.prototype.get = function(index){
  return dll.pixie_font_paints_get(this.font, index)
};
FontPaints.prototype.set = function(index, value){
  dll.pixie_font_paints_set(this.font, index, value)
};
FontPaints.prototype.delete = function(index){
  dll.pixie_font_paints_delete(this.font, index)
};
FontPaints.prototype.add = function(value){
  dll.pixie_font_paints_add(this.font, value)
};
FontPaints.prototype.clear = function(){
  dll.pixie_font_paints_clear(this.font)
};
Object.defineProperty(Font.prototype, 'paints', {
  get: function() {return new FontPaints(this)},
});
Object.defineProperty(Font.prototype, 'textCase', {
  get: function() {return dll.pixie_font_get_text_case(this)},
  set: function(v) {dll.pixie_font_set_text_case(this, v)}
});
Object.defineProperty(Font.prototype, 'underline', {
  get: function() {return dll.pixie_font_get_underline(this)},
  set: function(v) {dll.pixie_font_set_underline(this, v)}
});
Object.defineProperty(Font.prototype, 'strikethrough', {
  get: function() {return dll.pixie_font_get_strikethrough(this)},
  set: function(v) {dll.pixie_font_set_strikethrough(this, v)}
});
Object.defineProperty(Font.prototype, 'noKerningAdjustments', {
  get: function() {return dll.pixie_font_get_no_kerning_adjustments(this)},
  set: function(v) {dll.pixie_font_set_no_kerning_adjustments(this, v)}
});

Font.prototype.scale = function(){
  result = dll.pixie_font_scale(this)
  return result
}

Font.prototype.defaultLineHeight = function(){
  result = dll.pixie_font_default_line_height(this)
  return result
}

Font.prototype.typeset = function(text, bounds = Vector2(0, 0), h_align = HA_LEFT, v_align = VA_TOP, wrap = True){
  result = dll.pixie_font_typeset(this, text, bounds, h_align, v_align, wrap)
  return result
}

Font.prototype.computeBounds = function(text){
  result = dll.pixie_font_compute_bounds(this, text)
  return result
}

Span = Struct({'nimRef': 'uint64'});
Span.prototype.unref = function(){
  return dll.pixie_span_unref(this)
};
exports.span = function(text, font){
  var result = dll.pixie_new_span(text, font)
  return result
}
Object.defineProperty(Span.prototype, 'text', {
  get: function() {return dll.pixie_span_get_text(this)},
  set: function(v) {dll.pixie_span_set_text(this, v)}
});
Object.defineProperty(Span.prototype, 'font', {
  get: function() {return dll.pixie_span_get_font(this)},
  set: function(v) {dll.pixie_span_set_font(this, v)}
});

Arrangement = Struct({'nimRef': 'uint64'});
Arrangement.prototype.unref = function(){
  return dll.pixie_arrangement_unref(this)
};

Arrangement.prototype.computeBounds = function(){
  result = dll.pixie_arrangement_compute_bounds(this)
  return result
}

Context = Struct({'nimRef': 'uint64'});
Context.prototype.unref = function(){
  return dll.pixie_context_unref(this)
};
exports.context = function(width, height){
  var result = dll.pixie_new_context(width, height)
  if(checkError()) throw new PixieException(takeError());
  return result
}
Object.defineProperty(Context.prototype, 'image', {
  get: function() {return dll.pixie_context_get_image(this)},
  set: function(v) {dll.pixie_context_set_image(this, v)}
});
Object.defineProperty(Context.prototype, 'fillStyle', {
  get: function() {return dll.pixie_context_get_fill_style(this)},
  set: function(v) {dll.pixie_context_set_fill_style(this, v)}
});
Object.defineProperty(Context.prototype, 'strokeStyle', {
  get: function() {return dll.pixie_context_get_stroke_style(this)},
  set: function(v) {dll.pixie_context_set_stroke_style(this, v)}
});
Object.defineProperty(Context.prototype, 'globalAlpha', {
  get: function() {return dll.pixie_context_get_global_alpha(this)},
  set: function(v) {dll.pixie_context_set_global_alpha(this, v)}
});
Object.defineProperty(Context.prototype, 'lineWidth', {
  get: function() {return dll.pixie_context_get_line_width(this)},
  set: function(v) {dll.pixie_context_set_line_width(this, v)}
});
Object.defineProperty(Context.prototype, 'miterLimit', {
  get: function() {return dll.pixie_context_get_miter_limit(this)},
  set: function(v) {dll.pixie_context_set_miter_limit(this, v)}
});
Object.defineProperty(Context.prototype, 'lineCap', {
  get: function() {return dll.pixie_context_get_line_cap(this)},
  set: function(v) {dll.pixie_context_set_line_cap(this, v)}
});
Object.defineProperty(Context.prototype, 'lineJoin', {
  get: function() {return dll.pixie_context_get_line_join(this)},
  set: function(v) {dll.pixie_context_set_line_join(this, v)}
});
Object.defineProperty(Context.prototype, 'font', {
  get: function() {return dll.pixie_context_get_font(this)},
  set: function(v) {dll.pixie_context_set_font(this, v)}
});
Object.defineProperty(Context.prototype, 'fontSize', {
  get: function() {return dll.pixie_context_get_font_size(this)},
  set: function(v) {dll.pixie_context_set_font_size(this, v)}
});
Object.defineProperty(Context.prototype, 'textAlign', {
  get: function() {return dll.pixie_context_get_text_align(this)},
  set: function(v) {dll.pixie_context_set_text_align(this, v)}
});

Context.prototype.save = function(){
  dll.pixie_context_save(this)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.saveLayer = function(){
  dll.pixie_context_save_layer(this)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.restore = function(){
  dll.pixie_context_restore(this)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.beginPath = function(){
  dll.pixie_context_begin_path(this)
}

Context.prototype.closePath = function(){
  dll.pixie_context_close_path(this)
}

Context.prototype.fill = function(winding_rule = WR_NON_ZERO){
  dll.pixie_context_fill(this, winding_rule)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.path_fill = function(path, winding_rule = WR_NON_ZERO){
  dll.pixie_context_path_fill(this, path, winding_rule)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.clip = function(winding_rule = WR_NON_ZERO){
  dll.pixie_context_clip(this, winding_rule)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.path_clip = function(path, winding_rule = WR_NON_ZERO){
  dll.pixie_context_path_clip(this, path, winding_rule)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.stroke = function(){
  dll.pixie_context_stroke(this)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.path_stroke = function(path){
  dll.pixie_context_path_stroke(this, path)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.measureText = function(text){
  result = dll.pixie_context_measure_text(this, text)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Context.prototype.getTransform = function(){
  result = dll.pixie_context_get_transform(this)
  return result
}

Context.prototype.setTransform = function(transform){
  dll.pixie_context_set_transform(this, transform)
}

Context.prototype.transform = function(transform){
  dll.pixie_context_transform(this, transform)
}

Context.prototype.resetTransform = function(){
  dll.pixie_context_reset_transform(this)
}

Context.prototype.drawImage1 = function(image, dx, dy){
  dll.pixie_context_draw_image_1(this, image, dx, dy)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.drawImage2 = function(image, dx, dy, d_width, d_height){
  dll.pixie_context_draw_image_2(this, image, dx, dy, d_width, d_height)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.drawImage3 = function(image, sx, sy, s_width, s_height, dx, dy, d_width, d_height){
  dll.pixie_context_draw_image_3(this, image, sx, sy, s_width, s_height, dx, dy, d_width, d_height)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.moveTo = function(x, y){
  dll.pixie_context_move_to(this, x, y)
}

Context.prototype.lineTo = function(x, y){
  dll.pixie_context_line_to(this, x, y)
}

Context.prototype.bezierCurveTo = function(cp_1x, cp_1y, cp_2x, cp_2y, x, y){
  dll.pixie_context_bezier_curve_to(this, cp_1x, cp_1y, cp_2x, cp_2y, x, y)
}

Context.prototype.quadraticCurveTo = function(cpx, cpy, x, y){
  dll.pixie_context_quadratic_curve_to(this, cpx, cpy, x, y)
}

Context.prototype.arc = function(x, y, r, a_0, a_1, ccw = False){
  dll.pixie_context_arc(this, x, y, r, a_0, a_1, ccw)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.arcTo = function(x_1, y_1, x_2, y_2, radius){
  dll.pixie_context_arc_to(this, x_1, y_1, x_2, y_2, radius)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.rect = function(x, y, width, height){
  dll.pixie_context_rect(this, x, y, width, height)
}

Context.prototype.roundedRect = function(x, y, w, h, nw, ne, se, sw){
  dll.pixie_context_rounded_rect(this, x, y, w, h, nw, ne, se, sw)
}

Context.prototype.ellipse = function(x, y, rx, ry){
  dll.pixie_context_ellipse(this, x, y, rx, ry)
}

Context.prototype.circle = function(cx, cy, r){
  dll.pixie_context_circle(this, cx, cy, r)
}

Context.prototype.polygon = function(x, y, size, sides){
  dll.pixie_context_polygon(this, x, y, size, sides)
}

Context.prototype.clearRect = function(x, y, width, height){
  dll.pixie_context_clear_rect(this, x, y, width, height)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.fillRect = function(x, y, width, height){
  dll.pixie_context_fill_rect(this, x, y, width, height)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.strokeRect = function(x, y, width, height){
  dll.pixie_context_stroke_rect(this, x, y, width, height)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.fillText = function(text, x, y){
  dll.pixie_context_fill_text(this, text, x, y)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.strokeText = function(text, x, y){
  dll.pixie_context_stroke_text(this, text, x, y)
  if(checkError()) throw new PixieException(takeError());
}

Context.prototype.translate = function(x, y){
  dll.pixie_context_translate(this, x, y)
}

Context.prototype.scale = function(x, y){
  dll.pixie_context_scale(this, x, y)
}

Context.prototype.rotate = function(angle){
  dll.pixie_context_rotate(this, angle)
}

Context.prototype.isPointInPath = function(x, y, winding_rule = WR_NON_ZERO){
  result = dll.pixie_context_is_point_in_path(this, x, y, winding_rule)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Context.prototype.path_isPointInPath = function(path, x, y, winding_rule = WR_NON_ZERO){
  result = dll.pixie_context_path_is_point_in_path(this, path, x, y, winding_rule)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Context.prototype.isPointInStroke = function(x, y){
  result = dll.pixie_context_is_point_in_stroke(this, x, y)
  if(checkError()) throw new PixieException(takeError());
  return result
}

Context.prototype.path_isPointInStroke = function(path, x, y){
  result = dll.pixie_context_path_is_point_in_stroke(this, path, x, y)
  if(checkError()) throw new PixieException(takeError());
  return result
}

function readImage(file_path){
  result = dll.pixie_read_image(file_path)
  if(checkError()) throw new PixieException(takeError());
  return result
}

function readMask(file_path){
  result = dll.pixie_read_mask(file_path)
  if(checkError()) throw new PixieException(takeError());
  return result
}

function readTypeface(file_path){
  result = dll.pixie_read_typeface(file_path)
  if(checkError()) throw new PixieException(takeError());
  return result
}

function readFont(file_path){
  result = dll.pixie_read_font(file_path)
  if(checkError()) throw new PixieException(takeError());
  return result
}

function parsePath(path){
  result = dll.pixie_parse_path(path)
  if(checkError()) throw new PixieException(takeError());
  return result
}

function miterLimitToAngle(limit){
  result = dll.pixie_miter_limit_to_angle(limit)
  return result
}

function angleToMiterLimit(angle){
  result = dll.pixie_angle_to_miter_limit(angle)
  return result
}


var dllPath = ""
if(process.platform == "win32") {
  dllPath = 'pixie.dll'
} else if (process.platform == "darwin") {
  dllPath = __dirname + '/libpixie.dylib'
} else {
  dllPath = __dirname + '/libpixie.so'
}

dll = ffi.Library(dllPath, {
  'pixie_check_error': ['bool', []],
  'pixie_take_error': ['string', []],
  'pixie_matrix_3': [Matrix3, []],
  'pixie_seq_float_32_unref': ['void', [SeqFloat32]],
  'pixie_new_seq_float_32': [SeqFloat32, []],
  'pixie_seq_float_32_len': ['uint64', [SeqFloat32]],
  'pixie_seq_float_32_get': ['float', [SeqFloat32, 'uint64']],
  'pixie_seq_float_32_set': ['void', [SeqFloat32, 'uint64', 'float']],
  'pixie_seq_float_32_delete': ['void', [SeqFloat32, 'uint64']],
  'pixie_seq_float_32_add': ['void', [SeqFloat32, 'float']],
  'pixie_seq_float_32_clear': ['void', [SeqFloat32]],
  'pixie_seq_span_unref': ['void', [SeqSpan]],
  'pixie_new_seq_span': [SeqSpan, []],
  'pixie_seq_span_len': ['uint64', [SeqSpan]],
  'pixie_seq_span_get': [Span, [SeqSpan, 'uint64']],
  'pixie_seq_span_set': ['void', [SeqSpan, 'uint64', Span]],
  'pixie_seq_span_delete': ['void', [SeqSpan, 'uint64']],
  'pixie_seq_span_add': ['void', [SeqSpan, Span]],
  'pixie_seq_span_clear': ['void', [SeqSpan]],
  'pixie_seq_span_typeset': [Arrangement, [SeqSpan, Vector2, HorizontalAlignment, VerticalAlignment, 'bool']],
  'pixie_seq_span_compute_bounds': [Vector2, [SeqSpan]],
  'pixie_image_unref': ['void', [Image]],
  'pixie_new_image': [Image, ['int64', 'int64']],
  'pixie_image_get_width': ['int64', [Image]],
  'pixie_image_set_width': ['void', [Image, 'int64']],
  'pixie_image_get_height': ['int64', [Image]],
  'pixie_image_set_height': ['void', [Image, 'int64']],
  'pixie_image_write_file': ['void', [Image, 'string']],
  'pixie_image_wh': [Vector2, [Image]],
  'pixie_image_copy': [Image, [Image]],
  'pixie_image_get_color': [Color, [Image, 'int64', 'int64']],
  'pixie_image_set_color': ['void', [Image, 'int64', 'int64', Color]],
  'pixie_image_fill': ['void', [Image, Color]],
  'pixie_image_flip_horizontal': ['void', [Image]],
  'pixie_image_flip_vertical': ['void', [Image]],
  'pixie_image_sub_image': [Image, [Image, 'int64', 'int64', 'int64', 'int64']],
  'pixie_image_minify_by_2': [Image, [Image, 'int64']],
  'pixie_image_magnify_by_2': [Image, [Image, 'int64']],
  'pixie_image_apply_opacity': ['void', [Image, 'float']],
  'pixie_image_invert': ['void', [Image]],
  'pixie_image_blur': ['void', [Image, 'float', Color]],
  'pixie_image_new_mask': [Mask, [Image]],
  'pixie_image_resize': [Image, [Image, 'int64', 'int64']],
  'pixie_image_shadow': [Image, [Image, Vector2, 'float', 'float', Color]],
  'pixie_image_super_image': [Image, [Image, 'int64', 'int64', 'int64', 'int64']],
  'pixie_image_draw': ['void', [Image, Image, Matrix3, BlendMode]],
  'pixie_image_mask_draw': ['void', [Image, Mask, Matrix3, BlendMode]],
  'pixie_image_fill_gradient': ['void', [Image, Paint]],
  'pixie_image_fill_text': ['void', [Image, Font, 'string', Matrix3, Vector2, HorizontalAlignment, VerticalAlignment]],
  'pixie_image_arrangement_fill_text': ['void', [Image, Arrangement, Matrix3]],
  'pixie_image_stroke_text': ['void', [Image, Font, 'string', Matrix3, 'float', Vector2, HorizontalAlignment, VerticalAlignment, LineCap, LineJoin, 'float', SeqFloat32]],
  'pixie_image_arrangement_stroke_text': ['void', [Image, Arrangement, Matrix3, 'float', LineCap, LineJoin, 'float', SeqFloat32]],
  'pixie_image_fill_path': ['void', [Image, Path, Paint, Matrix3, WindingRule]],
  'pixie_image_stroke_path': ['void', [Image, Path, Paint, Matrix3, 'float', LineCap, LineJoin, 'float', SeqFloat32]],
  'pixie_image_new_context': [Context, [Image]],
  'pixie_mask_unref': ['void', [Mask]],
  'pixie_new_mask': [Mask, ['int64', 'int64']],
  'pixie_mask_get_width': ['int64', [Mask]],
  'pixie_mask_set_width': ['void', [Mask, 'int64']],
  'pixie_mask_get_height': ['int64', [Mask]],
  'pixie_mask_set_height': ['void', [Mask, 'int64']],
  'pixie_mask_write_file': ['void', [Mask, 'string']],
  'pixie_mask_wh': [Vector2, [Mask]],
  'pixie_mask_copy': [Mask, [Mask]],
  'pixie_mask_get_value': ['uint8', [Mask, 'int64', 'int64']],
  'pixie_mask_set_value': ['void', [Mask, 'int64', 'int64', 'uint8']],
  'pixie_mask_fill': ['void', [Mask, 'uint8']],
  'pixie_mask_minify_by_2': [Mask, [Mask, 'int64']],
  'pixie_mask_spread': ['void', [Mask, 'float']],
  'pixie_mask_ceil': ['void', [Mask]],
  'pixie_mask_new_image': [Image, [Mask]],
  'pixie_mask_apply_opacity': ['void', [Mask, 'float']],
  'pixie_mask_invert': ['void', [Mask]],
  'pixie_mask_blur': ['void', [Mask, 'float', 'uint8']],
  'pixie_mask_draw': ['void', [Mask, Mask, Matrix3, BlendMode]],
  'pixie_mask_image_draw': ['void', [Mask, Image, Matrix3, BlendMode]],
  'pixie_mask_fill_text': ['void', [Mask, Font, 'string', Matrix3, Vector2, HorizontalAlignment, VerticalAlignment]],
  'pixie_mask_arrangement_fill_text': ['void', [Mask, Arrangement, Matrix3]],
  'pixie_mask_stroke_text': ['void', [Mask, Font, 'string', Matrix3, 'float', Vector2, HorizontalAlignment, VerticalAlignment, LineCap, LineJoin, 'float', SeqFloat32]],
  'pixie_mask_arrangement_stroke_text': ['void', [Mask, Arrangement, Matrix3, 'float', LineCap, LineJoin, 'float', SeqFloat32]],
  'pixie_mask_fill_path': ['void', [Mask, Path, Matrix3, WindingRule, BlendMode]],
  'pixie_mask_stroke_path': ['void', [Mask, Path, Matrix3, 'float', LineCap, LineJoin, 'float', SeqFloat32, BlendMode]],
  'pixie_paint_unref': ['void', [Paint]],
  'pixie_new_paint': [Paint, [PaintKind]],
  'pixie_paint_get_kind': [PaintKind, [Paint]],
  'pixie_paint_set_kind': ['void', [Paint, PaintKind]],
  'pixie_paint_get_blend_mode': [BlendMode, [Paint]],
  'pixie_paint_set_blend_mode': ['void', [Paint, BlendMode]],
  'pixie_paint_get_opacity': ['float', [Paint]],
  'pixie_paint_set_opacity': ['void', [Paint, 'float']],
  'pixie_paint_get_color': [Color, [Paint]],
  'pixie_paint_set_color': ['void', [Paint, Color]],
  'pixie_paint_get_image': [Image, [Paint]],
  'pixie_paint_set_image': ['void', [Paint, Image]],
  'pixie_paint_get_image_mat': [Matrix3, [Paint]],
  'pixie_paint_set_image_mat': ['void', [Paint, Matrix3]],
  'pixie_paint_gradient_handle_positions_len': ['uint64', [Paint]],
  'pixie_paint_gradient_handle_positions_get': [Vector2, [Paint, 'uint64']],
  'pixie_paint_gradient_handle_positions_set': ['void', [Paint, 'uint64', Vector2]],
  'pixie_paint_gradient_handle_positions_delete': ['void', [Paint, 'uint64']],
  'pixie_paint_gradient_handle_positions_add': ['void', [Paint, Vector2]],
  'pixie_paint_gradient_handle_positions_clear': ['void', [Paint]],
  'pixie_paint_gradient_stops_len': ['uint64', [Paint]],
  'pixie_paint_gradient_stops_get': [ColorStop, [Paint, 'uint64']],
  'pixie_paint_gradient_stops_set': ['void', [Paint, 'uint64', ColorStop]],
  'pixie_paint_gradient_stops_delete': ['void', [Paint, 'uint64']],
  'pixie_paint_gradient_stops_add': ['void', [Paint, ColorStop]],
  'pixie_paint_gradient_stops_clear': ['void', [Paint]],
  'pixie_paint_new_paint': [Paint, [Paint]],
  'pixie_path_unref': ['void', [Path]],
  'pixie_new_path': [Path, []],
  'pixie_path_transform': ['void', [Path, Matrix3]],
  'pixie_path_add_path': ['void', [Path, Path]],
  'pixie_path_close_path': ['void', [Path]],
  'pixie_path_compute_bounds': [Rect, [Path, Matrix3]],
  'pixie_path_fill_overlaps': ['bool', [Path, Vector2, Matrix3, WindingRule]],
  'pixie_path_stroke_overlaps': ['bool', [Path, Vector2, Matrix3, 'float', LineCap, LineJoin, 'float', SeqFloat32]],
  'pixie_path_move_to': ['void', [Path, 'float', 'float']],
  'pixie_path_line_to': ['void', [Path, 'float', 'float']],
  'pixie_path_bezier_curve_to': ['void', [Path, 'float', 'float', 'float', 'float', 'float', 'float']],
  'pixie_path_quadratic_curve_to': ['void', [Path, 'float', 'float', 'float', 'float']],
  'pixie_path_elliptical_arc_to': ['void', [Path, 'float', 'float', 'float', 'bool', 'bool', 'float', 'float']],
  'pixie_path_arc': ['void', [Path, 'float', 'float', 'float', 'float', 'float', 'bool']],
  'pixie_path_arc_to': ['void', [Path, 'float', 'float', 'float', 'float', 'float']],
  'pixie_path_rect': ['void', [Path, 'float', 'float', 'float', 'float', 'bool']],
  'pixie_path_rounded_rect': ['void', [Path, 'float', 'float', 'float', 'float', 'float', 'float', 'float', 'float', 'bool']],
  'pixie_path_ellipse': ['void', [Path, 'float', 'float', 'float', 'float']],
  'pixie_path_circle': ['void', [Path, 'float', 'float', 'float']],
  'pixie_path_polygon': ['void', [Path, 'float', 'float', 'float', 'int64']],
  'pixie_typeface_unref': ['void', [Typeface]],
  'pixie_typeface_get_file_path': ['string', [Typeface]],
  'pixie_typeface_set_file_path': ['void', [Typeface, 'string']],
  'pixie_typeface_ascent': ['float', [Typeface]],
  'pixie_typeface_descent': ['float', [Typeface]],
  'pixie_typeface_line_gap': ['float', [Typeface]],
  'pixie_typeface_line_height': ['float', [Typeface]],
  'pixie_typeface_get_glyph_path': [Path, [Typeface, 'int32']],
  'pixie_typeface_get_advance': ['float', [Typeface, 'int32']],
  'pixie_typeface_get_kerning_adjustment': ['float', [Typeface, 'int32', 'int32']],
  'pixie_typeface_new_font': [Font, [Typeface]],
  'pixie_font_unref': ['void', [Font]],
  'pixie_font_get_typeface': [Typeface, [Font]],
  'pixie_font_set_typeface': ['void', [Font, Typeface]],
  'pixie_font_get_size': ['float', [Font]],
  'pixie_font_set_size': ['void', [Font, 'float']],
  'pixie_font_get_line_height': ['float', [Font]],
  'pixie_font_set_line_height': ['void', [Font, 'float']],
  'pixie_font_paints_len': ['uint64', [Font]],
  'pixie_font_paints_get': [Paint, [Font, 'uint64']],
  'pixie_font_paints_set': ['void', [Font, 'uint64', Paint]],
  'pixie_font_paints_delete': ['void', [Font, 'uint64']],
  'pixie_font_paints_add': ['void', [Font, Paint]],
  'pixie_font_paints_clear': ['void', [Font]],
  'pixie_font_get_text_case': [TextCase, [Font]],
  'pixie_font_set_text_case': ['void', [Font, TextCase]],
  'pixie_font_get_underline': ['bool', [Font]],
  'pixie_font_set_underline': ['void', [Font, 'bool']],
  'pixie_font_get_strikethrough': ['bool', [Font]],
  'pixie_font_set_strikethrough': ['void', [Font, 'bool']],
  'pixie_font_get_no_kerning_adjustments': ['bool', [Font]],
  'pixie_font_set_no_kerning_adjustments': ['void', [Font, 'bool']],
  'pixie_font_scale': ['float', [Font]],
  'pixie_font_default_line_height': ['float', [Font]],
  'pixie_font_typeset': [Arrangement, [Font, 'string', Vector2, HorizontalAlignment, VerticalAlignment, 'bool']],
  'pixie_font_compute_bounds': [Vector2, [Font, 'string']],
  'pixie_span_unref': ['void', [Span]],
  'pixie_new_span': [Span, ['string', Font]],
  'pixie_span_get_text': ['string', [Span]],
  'pixie_span_set_text': ['void', [Span, 'string']],
  'pixie_span_get_font': [Font, [Span]],
  'pixie_span_set_font': ['void', [Span, Font]],
  'pixie_arrangement_unref': ['void', [Arrangement]],
  'pixie_arrangement_compute_bounds': [Vector2, [Arrangement]],
  'pixie_context_unref': ['void', [Context]],
  'pixie_new_context': [Context, ['int64', 'int64']],
  'pixie_context_get_image': [Image, [Context]],
  'pixie_context_set_image': ['void', [Context, Image]],
  'pixie_context_get_fill_style': [Paint, [Context]],
  'pixie_context_set_fill_style': ['void', [Context, Paint]],
  'pixie_context_get_stroke_style': [Paint, [Context]],
  'pixie_context_set_stroke_style': ['void', [Context, Paint]],
  'pixie_context_get_global_alpha': ['float', [Context]],
  'pixie_context_set_global_alpha': ['void', [Context, 'float']],
  'pixie_context_get_line_width': ['float', [Context]],
  'pixie_context_set_line_width': ['void', [Context, 'float']],
  'pixie_context_get_miter_limit': ['float', [Context]],
  'pixie_context_set_miter_limit': ['void', [Context, 'float']],
  'pixie_context_get_line_cap': [LineCap, [Context]],
  'pixie_context_set_line_cap': ['void', [Context, LineCap]],
  'pixie_context_get_line_join': [LineJoin, [Context]],
  'pixie_context_set_line_join': ['void', [Context, LineJoin]],
  'pixie_context_get_font': ['string', [Context]],
  'pixie_context_set_font': ['void', [Context, 'string']],
  'pixie_context_get_font_size': ['float', [Context]],
  'pixie_context_set_font_size': ['void', [Context, 'float']],
  'pixie_context_get_text_align': [HorizontalAlignment, [Context]],
  'pixie_context_set_text_align': ['void', [Context, HorizontalAlignment]],
  'pixie_context_save': ['void', [Context]],
  'pixie_context_save_layer': ['void', [Context]],
  'pixie_context_restore': ['void', [Context]],
  'pixie_context_begin_path': ['void', [Context]],
  'pixie_context_close_path': ['void', [Context]],
  'pixie_context_fill': ['void', [Context, WindingRule]],
  'pixie_context_path_fill': ['void', [Context, Path, WindingRule]],
  'pixie_context_clip': ['void', [Context, WindingRule]],
  'pixie_context_path_clip': ['void', [Context, Path, WindingRule]],
  'pixie_context_stroke': ['void', [Context]],
  'pixie_context_path_stroke': ['void', [Context, Path]],
  'pixie_context_measure_text': [TextMetrics, [Context, 'string']],
  'pixie_context_get_transform': [Matrix3, [Context]],
  'pixie_context_set_transform': ['void', [Context, Matrix3]],
  'pixie_context_transform': ['void', [Context, Matrix3]],
  'pixie_context_reset_transform': ['void', [Context]],
  'pixie_context_draw_image_1': ['void', [Context, Image, 'float', 'float']],
  'pixie_context_draw_image_2': ['void', [Context, Image, 'float', 'float', 'float', 'float']],
  'pixie_context_draw_image_3': ['void', [Context, Image, 'float', 'float', 'float', 'float', 'float', 'float', 'float', 'float']],
  'pixie_context_move_to': ['void', [Context, 'float', 'float']],
  'pixie_context_line_to': ['void', [Context, 'float', 'float']],
  'pixie_context_bezier_curve_to': ['void', [Context, 'float', 'float', 'float', 'float', 'float', 'float']],
  'pixie_context_quadratic_curve_to': ['void', [Context, 'float', 'float', 'float', 'float']],
  'pixie_context_arc': ['void', [Context, 'float', 'float', 'float', 'float', 'float', 'bool']],
  'pixie_context_arc_to': ['void', [Context, 'float', 'float', 'float', 'float', 'float']],
  'pixie_context_rect': ['void', [Context, 'float', 'float', 'float', 'float']],
  'pixie_context_rounded_rect': ['void', [Context, 'float', 'float', 'float', 'float', 'float', 'float', 'float', 'float']],
  'pixie_context_ellipse': ['void', [Context, 'float', 'float', 'float', 'float']],
  'pixie_context_circle': ['void', [Context, 'float', 'float', 'float']],
  'pixie_context_polygon': ['void', [Context, 'float', 'float', 'float', 'int64']],
  'pixie_context_clear_rect': ['void', [Context, 'float', 'float', 'float', 'float']],
  'pixie_context_fill_rect': ['void', [Context, 'float', 'float', 'float', 'float']],
  'pixie_context_stroke_rect': ['void', [Context, 'float', 'float', 'float', 'float']],
  'pixie_context_fill_text': ['void', [Context, 'string', 'float', 'float']],
  'pixie_context_stroke_text': ['void', [Context, 'string', 'float', 'float']],
  'pixie_context_translate': ['void', [Context, 'float', 'float']],
  'pixie_context_scale': ['void', [Context, 'float', 'float']],
  'pixie_context_rotate': ['void', [Context, 'float']],
  'pixie_context_is_point_in_path': ['bool', [Context, 'float', 'float', WindingRule]],
  'pixie_context_path_is_point_in_path': ['bool', [Context, Path, 'float', 'float', WindingRule]],
  'pixie_context_is_point_in_stroke': ['bool', [Context, 'float', 'float']],
  'pixie_context_path_is_point_in_stroke': ['bool', [Context, Path, 'float', 'float']],
  'pixie_read_image': [Image, ['string']],
  'pixie_read_mask': [Mask, ['string']],
  'pixie_read_typeface': [Typeface, ['string']],
  'pixie_read_font': [Font, ['string']],
  'pixie_parse_path': [Path, ['string']],
  'pixie_miter_limit_to_angle': ['float', ['float']],
  'pixie_angle_to_miter_limit': ['float', ['float']],
});

exports.DEFAULT_MITER_LIMIT = 4.0

exports.AUTO_LINE_HEIGHT = -1.0

exports.FileFormat = FileFormat
exports.FF_PNG = 0
exports.FF_BMP = 1
exports.FF_JPG = 2
exports.FF_GIF = 3
exports.BlendMode = BlendMode
exports.BM_NORMAL = 0
exports.BM_DARKEN = 1
exports.BM_MULTIPLY = 2
exports.BM_COLOR_BURN = 3
exports.BM_LIGHTEN = 4
exports.BM_SCREEN = 5
exports.BM_COLOR_DODGE = 6
exports.BM_OVERLAY = 7
exports.BM_SOFT_LIGHT = 8
exports.BM_HARD_LIGHT = 9
exports.BM_DIFFERENCE = 10
exports.BM_EXCLUSION = 11
exports.BM_HUE = 12
exports.BM_SATURATION = 13
exports.BM_COLOR = 14
exports.BM_LUMINOSITY = 15
exports.BM_MASK = 16
exports.BM_OVERWRITE = 17
exports.BM_SUBTRACT_MASK = 18
exports.BM_EXCLUDE_MASK = 19
exports.PaintKind = PaintKind
exports.PK_SOLID = 0
exports.PK_IMAGE = 1
exports.PK_IMAGE_TILED = 2
exports.PK_GRADIENT_LINEAR = 3
exports.PK_GRADIENT_RADIAL = 4
exports.PK_GRADIENT_ANGULAR = 5
exports.WindingRule = WindingRule
exports.WR_NON_ZERO = 0
exports.WR_EVEN_ODD = 1
exports.LineCap = LineCap
exports.LC_BUTT = 0
exports.LC_ROUND = 1
exports.LC_SQUARE = 2
exports.LineJoin = LineJoin
exports.LJ_MITER = 0
exports.LJ_ROUND = 1
exports.LJ_BEVEL = 2
exports.HorizontalAlignment = HorizontalAlignment
exports.HA_LEFT = 0
exports.HA_CENTER = 1
exports.HA_RIGHT = 2
exports.VerticalAlignment = VerticalAlignment
exports.VA_TOP = 0
exports.VA_MIDDLE = 1
exports.VA_BOTTOM = 2
exports.TextCase = TextCase
exports.TC_NORMAL = 0
exports.TC_UPPER = 1
exports.TC_LOWER = 2
exports.TC_TITLE = 3
exports.checkError = checkError
exports.takeError = takeError
exports.Vector2 = Vector2;
exports.vector2 = vector2;
exports.Matrix3 = Matrix3;
exports.matrix3 = matrix3;
exports.Rect = Rect;
exports.rect = rect;
exports.Color = Color;
exports.color = color;
exports.ColorStop = ColorStop;
exports.colorStop = colorStop;
exports.TextMetrics = TextMetrics;
exports.textMetrics = textMetrics;
exports.SeqFloat32 = SeqFloat32
exports.SeqSpan = SeqSpan
exports.Image = Image
exports.Mask = Mask
exports.Paint = Paint
exports.Path = Path
exports.Typeface = Typeface
exports.Font = Font
exports.Span = Span
exports.Arrangement = Arrangement
exports.Context = Context
exports.readImage = readImage
exports.readMask = readMask
exports.readTypeface = readTypeface
exports.readFont = readFont
exports.parsePath = parsePath
exports.miterLimitToAngle = miterLimitToAngle
exports.angleToMiterLimit = angleToMiterLimit
