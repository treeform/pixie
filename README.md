# Pixie - A full-featured 2D graphics library for Nim

⚠️ WARNING: This library is still in heavy development. ⚠️

Pixie is a 2D graphics library similar to [Cairo](https://www.cairographics.org/) and [Skia](https://skia.org) written (almost) entirely in Nim.

Features include:
* Drawing paths, shapes and curves
* Complex masking
* Shadows, glows and effects
* Loading image file formats (PNG, BMP, JPG + more in development)

This library is being actively developed and is not yet ready for use. Since you've managed to stumble onto it, give it a star and check back soon!

## Testing

`nimble test`

## Examples

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
#image.strokePath(path, rgba(0, 0, 0, 255), strokeWidth = 5.0)
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
