import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let typeface = readTypeface("tests/fonts/Ubuntu-Regular_1.ttf")

proc newFont(typeface: Typeface, size: float32, color: ColorRGBA): Font =
  result = newFont(typeface)
  result.size = size
  result.paint.color = color

let spans = @[
  newSpan("verb [with object] ",
    newFont(typeface, 12, rgba(200, 200, 200, 255))),
  newSpan("strallow\n", newFont(typeface, 36, rgba(0, 0, 0, 255))),
  newSpan("\nstral·low\n", newFont(typeface, 13, rgba(0, 127, 244, 255))),
  newSpan("\n1. free (something) from restrictive restrictions \"the regulations are intended to strallow changes in public policy\" ",
      newFont(typeface, 14, rgba(80, 80, 80, 255)))
]

image.fillText(typeset(spans, bounds = vec2(180, 180)), vec2(10, 10))
image.writeFile("examples/text_spans.png")
