import benchy, pixie

const text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis in quam in nulla bibendum luctus. Integer dui lectus, ultricies commodo enim quis, laoreet lacinia erat. Vivamus ultrices maximus risus, non aliquam quam sagittis quis. Ut nec diam vitae tortor interdum ullamcorper in aliquet velit. Ut sed lobortis mi. Nulla venenatis lectus varius justo lacinia, quis sollicitudin nunc ultrices. Donec a suscipit arcu, id egestas neque. Nullam commodo pharetra est. Nullam gravida nibh eget quam venenatis lacinia. Vestibulum et libero arcu. Sed dignissim enim eros. Nullam eleifend luctus erat sed luctus. Nunc tincidunt, mi nec tincidunt tristique, ex nulla lobortis sem, sit amet finibus purus justo non massa."

var font = readFont("tests/fonts/Roboto-Regular_1.ttf")
font.size = 16

let image = newImage(500, 300)

timeIt "typeset":
  discard font.typeset(text, bounds = vec2(image.width.float32, 0))

timeIt "fill text":
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, text, bounds = vec2(image.width.float32, 0))
