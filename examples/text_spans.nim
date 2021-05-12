import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")

proc style(font: Font, size: float32, color: ColorRGBA): Font =
  result = font
  result.size = size
  result.paint.color = color

let spans = @[
  newSpan("verb [with object] ", font.style(12, rgba(200, 200, 200, 255))),
  newSpan("strallow\n", font.style(36, rgba(0, 0, 0, 255))),
  newSpan("\nstral·low\n", font.style(13, rgba(0, 127, 244, 255))),
  newSpan("\n1. free (something) from restrictive restrictions \"the regulations are intended to strallow changes in public policy\" ",
      font.style(14, rgba(80, 80, 80, 255)))
]

image.fillText(typeset(spans, bounds = vec2(180, 180)), vec2(10, 10))
image.writeFile("examples/text_spans.png")
