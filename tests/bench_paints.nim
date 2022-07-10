import benchy, pixie

let image = newImage(1000, 1000)

timeIt "GradientLinear vertical":
  let paint = newPaint(LinearGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(50, 0),
    vec2(50, 1000),
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]
  image.fillGradient(paint)

timeIt "GradientLinear horizontal":
  let paint = newPaint(LinearGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(0, 50),
    vec2(1000, 50),
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]
  image.fillGradient(paint)

# timeIt "GradientLinear radial":
#   discard

let image100 = newImage(100, 100)

timeIt "GradientLinear angular":
  let paint = newPaint(AngularGradientPaint)
  paint.gradientHandlePositions = @[
    vec2(500, 500),
    vec2(1000, 500),
    vec2(500, 1000)
  ]
  paint.gradientStops = @[
    ColorStop(color: color(1, 0, 0, 1), position: 0),
    ColorStop(color: color(1, 0, 0, 0.15625), position: 1.0),
  ]
  image100.fillGradient(paint)
