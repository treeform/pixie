<img src="docs/banner.png">

# Pixie - A full-featured 2D graphics library for Nim

⚠️ WARNING: This library is still in heavy development. ⚠️

Pixie is a 2D graphics library similar to [Cairo](https://www.cairographics.org/) and [Skia](https://skia.org) written (almost) entirely in Nim.

This library is being actively developed and is not yet ready for use. Since you've managed to stumble onto it, give it a star and check back soon!

`nimble install pixie`

Features:
* Drawing paths, shapes and curves, with even-odd and non-zero windings.
* Pixel perfect AA quality.
* Supported file formats: PNG, BMP, JPG, SVG + more in development.
* Strokes with joins and caps.
* Shadows, glows and blurs.
* Complex masking: Subtract, Intersect, Exclude.
* Complex blends: Darken, Multiply, Color Dodge, Hue, Luminosity... etc.

API reference: https://treeform.github.io/pixie/pixie.html

### File formats

Format        | Read          | Write         |
------------- | ------------- | ------------- |
PNG           | ✅           | ✅            |
JPEG          | ✅           |               |
BMP           | ✅           |               |
SVG           | ✅           |               |


### Joins and caps:

Supported Saps:
  * Butt
  * Round
  * Square

Supported Joints:
  * Miter (with miter limit angle)
  * Bevel
  * Round

### Blending & Masking.

Supported Blend Modes:
  * Normal
  * Darken
  * Multiply
  * ColorBurn
  * Lighten
  * Screen
  * Color Dodge
  * Overlay
  * Soft Light
  * Hard Light
  * Difference
  * Exclusion
  * Hue
  * Saturation
  * Color
  * Luminosity

Supported Mask Modes:
  * Mask
  * Overwrite
  * Subtract Mask
  * Intersect Mask
  * Exclude Mask

### SVG style paths:

Format        | Supported     | Description           |
------------- | ------------- | --------------------- |
M,m           | ✅            | move to               |
L,l           | ✅            | line to               |
h,h           | ✅            | horizontal line to    |
V,v           | ✅            | vertical line to      |
C,c,S,s       | ✅            | cublic to             |
Q,q,T,t       | ✅            | quadratic to          |
A,a           | ✅            | arc to                |
z             | ✅            | close path            |


## Testing

`nimble test`

## Examples

### Square
[examples/square.nim](examples/square.nim)
```nim
let
  pos = vec2(50, 50)
  wh = vec2(100, 100)

image.fillRect(rect(pos, wh), rgba(255, 0, 0, 255))
```
![example output](examples/square.png)

### Line
[examples/line.nim](examples/line.nim)
```nim
let
  start = vec2(25, 25)
  stop = vec2(175, 175)
  color = parseHtmlColor("#FF5C00").rgba

image.strokeSegment(segment(start, stop), color, strokeWidth = 10)
```
![example output](examples/line.png)

### Rounded rectangle
[examples/rounded_rectangle.nim](examples/rounded_rectangle.nim)
```nim
let
  pos = vec2(50, 50)
  wh = vec2(100, 100)
  r = 25.0

image.fillRoundedRect(rect(pos, wh), r, rgba(0, 255, 0, 255))
```
![example output](examples/rounded_rectangle.png)

### Heart
[examples/heart.nim](examples/heart.nim)
```nim
image.fillPath(
  """
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """,
  parseHtmlColor("#FC427B").rgba
)
```
![example output](examples/heart.png)

### Masking
[examples/masking.nim](examples/masking.nim)
```nim
lines.strokeSegment(
  segment(vec2(25, 25), vec2(175, 175)), color, strokeWidth = 30)
lines.strokeSegment(
  segment(vec2(25, 175), vec2(175, 25)), color, strokeWidth = 30)

mask.fillPath(
  """
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """
)
lines.draw(mask)
image.draw(lines)
```
![example output](examples/masking.png)

### Gradient
[examples/gradient.nim](examples/gradient.nim)
```nim
image.fillPath(
  """
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """,
  Paint(
    kind:pkGradientRadial,
    gradientHandlePositions: @[
      vec2(100, 100),
      vec2(200, 100),
      vec2(100, 200)
    ],
    gradientStops: @[
      ColorStop(color:rgba(255, 0, 0, 255).color, position: 0),
      ColorStop(color:rgba(255, 0, 0, 40).color, position: 1.0),
    ]
  )
)
```
![example output](examples/gradient.png)

### Image tiled
[examples/image_tiled.nim](examples/image_tiled.nim)
```nim
var path: Path
path.polygon(
  vec2(100, 100),
  70,
  sides = 8
)
image.fillPath(
  path,
  Paint(
    kind:pkImageTiled,
    image: readImage("tests/images/png/baboon.png"),
    imageMat:scale(vec2(0.08, 0.08))
  )
)
```
![example output](examples/image_tiled.png)

### Shadow
[examples/shadow.nim](examples/shadow.nim)
```nim
let polygonImage = newImage(200, 200)
polygonImage.fillPolygon(
  vec2(100, 100),
  70,
  sides = 8,
  rgba(255, 255, 255, 255)
)

let shadow = polygonImage.shadow(
  offset = vec2(2, 2),
  spread = 2,
  blur = 10,
  color = rgba(0, 0, 0, 200)
)

image.draw(shadow)
image.draw(polygonImage)
```
![example output](examples/shadow.png)

### Blur
[examples/blur.nim](examples/blur.nim)
```nim
let mask = newMask(200, 200)
mask.fillPolygon(vec2(100, 100), 70, sides = 6)

blur.blur(20)
blur.draw(mask, blendMode = bmMask)

image.draw(trees)
image.draw(blur)
```
![example output](examples/blur.png)

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
