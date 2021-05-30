import benchy, pixie

const paragraph = "She had come to the conclusion that you could tell a lot about a person by their ears. The way they stuck out and the size of the earlobes could give you wonderful insights into the person. Of course, she couldn't scientifically prove any of this, but that didn't matter to her. Before anything else, she would size up the ears of the person she was talking to. She's asked the question so many times that she barely listened to the answers anymore. The answers were always the same. Well, not exactly the same, but the same in a general sense. A more accurate description was the answers never surprised her."

var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
font.size = 16

let image = newImage(500, 300)

timeIt "paragraph":
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(
    font,
    paragraph,
    bounds = image.wh
  )
