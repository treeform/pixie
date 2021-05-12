import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
font.size = 20

let text = "Typesetting is the arrangement and composition of text in graphic design and publishing in both digital and traditional medias."

image.fillText(font.typeset(text, bounds = vec2(180, 180)), vec2(10, 10))
image.writeFile("examples/text.png")
