import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var font = readFont("examples/data/Roboto-Regular_1.ttf")
font.size = 20

let text = "Typesetting is the arrangement and composition of text in graphic design and publishing in both digital and traditional medias."

image.fillText(font.typeset(text, vec2(180, 180)), translate(vec2(10, 10)))
image.writeFile("examples/text.png")
