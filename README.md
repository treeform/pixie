# Pixie - A full-featured 2D graphics library for Nim

⚠️ WARNING: This library is still in heavy development. ⚠️

Pixie is a 2D graphics library similar to [Cairo](https://www.cairographics.org/) and [Skia](https://skia.org) written (almost) entirely in Nim.

Features include:
* Drawing paths, shapes and curves
* Complex masking
* Shadows, glows and effects
* Loading image file formats (PNG, BMP, JPG, SVG + more in development)

This library is being actively developed and is not yet ready for use. Since you've managed to stumble onto it, give it a star and check back soon!

## Testing

`nimble test`

## Examples

### examples/blur.nim
```nim
var trees = readImage("examples/data/trees.png")
var blur = trees.copy()
blur.blur(10)
var p = newPath()
let
  size = 80.0
  x = 100.0
  y = 100.0
p.moveTo(x + size * cos(0.0), y + size * sin(0.0))
for side in 0 ..< 7:
  p.lineTo(
    x + size * cos(side.float32 * 2.0 * PI / 6.0),
    y + size * sin(side.float32 * 2.0 * PI / 6.0)
  )
p.closePath()

var mask = newImage(200, 200)
mask.fillPath(p, rgba(255, 0, 0, 255))
mask.sharpOpacity()
blur.draw(mask, blendMode = bmMask)
image.draw(trees)
image.draw(blur)
```
![example output](examples/blur.png)

### examples/rounded_rectangle.nim
```nim
var path = newPath()
let
  x = 50.0
  y = 50.0
  w = 100.0
  h = 100.0
  nw = 25.0
  ne = 25.0
  se = 25.0
  sw = 25.0
path.moveTo(x+nw, y)
path.arcTo(x+w, y,   x+w, y+h, ne)
path.arcTo(x+w, y+h, x,   y+h, se)
path.arcTo(x,   y+h, x,   y,   sw)
path.arcTo(x,   y,   x+w, y,   nw)
path.closePath()
path.closePath()
image.fillPath(path, rgba(255, 0, 0, 255))
```
![example output](examples/rounded_rectangle.png)

### examples/square.nim
```nim
var p = newPath()
p.moveTo(50, 50)
p.lineTo(50, 150)
p.lineTo(150, 150)
p.lineTo(150, 50)
p.closePath()
image.fillPath(p, rgba(255, 0, 0, 255))
#image.strokePath(p, rgba(0, 0, 0, 255), strokeWidth = 5.0)
```
![example output](examples/square.png)
