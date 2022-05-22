import cligen, os, pixie, pixie/fileformats/svg, strformat

# Clone https://github.com/twbs/icons
# Check out commit f364cb14dfc0703b9e3ef10c8b490a71dfef1e9d

# Clone https://github.com/icons8/flat-color-icons
# Check out commit 8eccbbbd8b2af1d2c9593e7cfba5ecb0d68ee378

# Clone https://github.com/ionic-team/ionicons
# Check out commit 0d7f507677f8d317ce6882729ffecf46e215e01a

# Clone https://github.com/tabler/tabler-icons
# Check out commit ccf2784b57e42a2b2221963f92146fd7b249b5b7

# Clone https://github.com/simple-icons/simple-icons
# Check out commit 355454cb6caa02aba70638631c557d4e06205710

type IconSet = object
  name: string
  path: string

const
  iconSets = [
    IconSet(name: "twbs-icons", path: "../icons/icons/*"),
    IconSet(name: "flat-color-icons", path: "../flat-color-icons/svg/*"),
    IconSet(name: "ionicons", path: "../ionicons/src/svg/*"),
    IconSet(name: "tabler-icons", path: "../tabler-icons/icons/*"),
    IconSet(name: "simple-icons", path: "../simple-icons/icons/*")
  ]
  width = 32
  height = 32

proc renderIconSet(index: int) =
  let iconSet = iconSets[index]

  var images: seq[(string, Image)]

  for filePath in walkFiles(iconSet.path):
    let
      (_, name, _) = splitFile(filePath)
      image = newImage(parseSvg(readFile(filePath), width, height))

    images.add((name, image))

  let
    columns = 40
    rows = (images.len + columns - 1) div columns
    rendered = newImage((width + 4) * columns, (height + 4) * rows)

  for i in 0 ..< rows:
    for j in 0 ..< max(images.len - i * columns, 0):
      let
        (_, icon) = images[i * columns + j]
        pos = vec2(((width + 4) * j + 2).float32, ((height + 4) * i + 2).float32)
      rendered.draw(
        icon,
        translate(pos),
        OverwriteBlend
      )

  rendered.writeFile(&"tests/fileformats/svg/{iconSet.name}.png")

proc main(index = -1) =
  if index >= 0:
    renderIconSet(index)
  else:
    for i in 0 ..< iconSets.len:
      renderIconSet(i)

dispatch(main)
