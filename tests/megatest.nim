import os, pixie, strformat

# Clone https://github.com/twbs/icons
# Check out commit f364cb14dfc0703b9e3ef10c8b490a71dfef1e9d

const
  iconsPath = "../icons/icons/*"
  width = 32
  height = 32

var images: seq[(string, Image)]

for path in walkFiles(iconsPath):
  let
    (_, name, _) = splitFile(path)
    image = decodeSvg(readFile(path), width, height)

  images.add((name, image))

let
  columns = 10
  rows = (images.len + columns - 1) div columns
  rendered = newImage((width + 4) * columns, (height + 4) * rows)

for i in 0 ..< rows:
  for j in 0 ..< max(images.len - i * columns, 0):
    let (_, icon) = images[i * columns + j]
    rendered.draw(
      icon,
      vec2(((width + 4) * j + 2).float32, ((height + 4) * i + 2).float32),
      bmOverwrite
    )

rendered.writeFile(&"tests/images/svg/twbs-icons.png")
