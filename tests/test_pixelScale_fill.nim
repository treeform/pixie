import pixie

let image = newImage(200, 200)
image.fill(rgba(255, 255, 255, 255))

var p = parsePath("M1 0.5C1 0.776142 0.776142 1 0.5 1C0.223858 1 0 0.776142 0 0.5C0 0.223858 0.223858 0 0.5 0C0.776142 0 1 0.223858 1 0.5Z")
image.fillPath(p, rgba(255, 0, 0, 255), scale(vec2(200, 200)))

image.strokePath(p, rgba(0, 255, 0, 255), scale(vec2(200, 200)), strokeWidth=0.01)

image.writeFile("tests/images/paths/pixelScale.png")
