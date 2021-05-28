import cligen, os, pixie, pixie/fileformats/svg, strformat

# Clone https://github.com/twitter/twemoji
# Check out commit 59cb0eacce837d0f5de30223bd8f530e447f547a

# Clone https://github.com/hfg-gmuend/openmoji
# Check out commit c1f14ae0be29b20c7eed215d1e03df23b1c9a5d5

type EmojiSet = object
  name: string
  path: string

const
  emojiSets = [
    EmojiSet(name: "twemoji", path: "../twemoji/assets/svg/*"),
    EmojiSet(name: "openmoji", path: "../openmoji/color/svg/*")
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
      image = decodeSvg(readFile(filePath), width, height)
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
      let (_, icon) = images[i * columns + j]
      rendered.draw(
        icon,
        vec2(((width + 4) * j + 2).float32, ((height + 4) * i + 2).float32),
        bmOverwrite
      )

  rendered.writeFile(&"tests/images/svg/{emojiSet.name}.png")

proc main(index = -1) =
  if index >= 0:
    renderEmojiSet(index)
  else:
    for i in 0 ..< emojiSets.len:
      renderEmojiSet(i)

dispatch(main)
