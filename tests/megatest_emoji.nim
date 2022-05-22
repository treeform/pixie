import cligen, os, pixie, pixie/fileformats/svg, strformat

# Clone https://github.com/twitter/twemoji
# Check out commit 59cb0eacce837d0f5de30223bd8f530e447f547a

# Clone https://github.com/hfg-gmuend/openmoji
# Check out commit c1f14ae0be29b20c7eed215d1e03df23b1c9a5d5

# Clone https://github.com/EmojiTwo/emojitwo
# Check out commit d79b4477eb8f9110fc3ce7bed2cc66030a77933e

# Clone https://github.com/googlefonts/noto-emoji
# Check out commit 948b1a7f1ed4ec7e27930ad8e027a740db3fe25e

type EmojiSet = object
  name: string
  path: string

const
  emojiSets = [
    EmojiSet(name: "twemoji", path: "../twemoji/assets/svg/*"),
    EmojiSet(name: "openmoji", path: "../openmoji/color/svg/*"),
    EmojiSet(name: "emojitwo", path: "../emojitwo/svg/*"),
    EmojiSet(name: "noto-emoji", path: "../noto-emoji/svg/*")
  ]
  width = 32
  height = 32

proc renderEmojiSet(index: int) =
  let emojiSet = emojiSets[index]

  var images: seq[(string, Image)]

  for filePath in walkFiles(emojiSet.path):
    let (_, name, _) = splitFile(filePath)
    var image: Image
    try:
      image = newImage(parseSvg(readFile(filePath), width, height))
    except PixieError:
      echo &"Failed decoding {name}"
      image = newImage(width, height)
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

  rendered.writeFile(&"tests/fileformats/svg/{emojiSet.name}.png")

proc main(index = -1) =
  if index >= 0:
    renderEmojiSet(index)
  else:
    for i in 0 ..< emojiSets.len:
      renderEmojiSet(i)

dispatch(main)
