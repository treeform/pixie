import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

let font = readFont("tests/fonts/Ubuntu-Regular_1.ttf")

var style1 = font
style1.size = 12
style1.paint.color = rgba(200, 200, 200, 255)

var style2 = font
style2.size = 36
style2.paint.color = rgba(0, 0, 0, 255)

var style3 = font
style3.size = 13
style3.paint.color = rgba(0, 127, 244, 255)

var style4 = font
style4.size = 14
style4.paint.color = rgba(80, 80, 80, 255)

let spans = @[
  newSpan("verb [with object] ", style1),
  newSpan("strallow\n", style2),
  newSpan("\nstral·low\n", style3),
  newSpan("\n1. free (something) from restrictive restrictions \"the regulations are intended to strallow changes in public policy\" ", style4)
]

image.fillText(typeset(spans, bounds = vec2(180, 180)), vec2(10, 10))
image.writeFile("examples/text_spans.png")
