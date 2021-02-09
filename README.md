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

### Blur
[examples/blur.nim](examples/blur.nim)
```nim
var p: Path
p.polygon(100, 100, 70, sides=6)
p.closePath()

let mask = newMask(200, 200)
mask.fillPath(p)

blur.blur(20)
blur.draw(mask, blendMode = bmMask)

image.draw(trees)
image.draw(blur)
```
![example output](examples/blur.png)

### Rounded rectangle
[examples/rounded_rectangle.nim](examples/rounded_rectangle.nim)
```nim
let
  x = 50.0
  y = 50.0
  w = 100.0
  h = 100.0
  r = 25.0

var path: Path
path.roundedRect(vec2(x, y), vec2(w, h), r, r, r, r)

image.fillPath(path, rgba(255, 0, 0, 255))
```
![example output](examples/rounded_rectangle.png)

### Square
[examples/square.nim](examples/square.nim)
```nim
var p: Path
p.rect(50, 50, 100, 100)

image.fillPath(p, rgba(255, 0, 0, 255))
```
![example output](examples/square.png)

### Tiger
[examples/tiger.nim](examples/tiger.nim)
```nim
let tiger = readImage("examples/data/tiger.svg")

image.draw(
  tiger,
  translate(vec2(100, 100)) *
  scale(vec2(0.2, 0.2)) *
  translate(vec2(-450, -450))
)
```
![example output](examples/tiger.png)
