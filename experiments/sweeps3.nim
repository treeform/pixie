
import algorithm, chroma, pixie/images, vmath, benchy

import pixie, pixie/paths {.all.}


template test(name: string, p: Path, a: static int = 1, wr = NonZero) =
  echo name
  var image = newImage(200, 200)
  timeIt "  sweeps", a:
    for i in 0 ..< a:
      image.fill(color(0, 0, 0, 0))
      image.fillPath(p, color(1, 0, 0, 1), windingRule = wr)
  image.writeFile("experiments/trapezoids/output_sweep.png")

  # var image2 = newImage(200, 200)
  # timeIt "  scanline", a:
  #   for i in 0 ..< a:
  #     image2.fill(color(0, 0, 0, 0))
  #     image2.fillPath(p, color(1, 0, 0, 1), windingRule = wr)
  # image2.writeFile("experiments/trapezoids/output_scanline.png")

  # let (score, diff) = diff(image, image2)
  # if score > 0.05:
  #   echo "does not appear ot match"
  # diff.writeFile("experiments/trapezoids/output_diff.png")


var rect = Path()
rect.moveTo(50.5, 50.5)
rect.lineTo(50.5, 150.5)
rect.lineTo(150.5, 150.5)
rect.lineTo(150.5, 50.5)
rect.closePath()

var rhombus = Path()
rhombus.moveTo(100, 50)
rhombus.lineTo(150, 100)
rhombus.lineTo(100, 150)
rhombus.lineTo(50, 100)
rhombus.closePath()

var heart = parsePath("""
  M 20 60
  A 40 40 90 0 1 100 60
  A 40 40 90 0 1 180 60
  Q 180 120 100 180
  Q 20 120 20 60
  z
""")

var cricle = Path()
cricle.arc(100, 100, 50, 0, PI * 2, true)
cricle.closePath()


# Half arc (test cut lines)
var halfAarc = parsePath("""
  M 25 25 C 85 25 85 125 25 125 z
""")

# Hour glass (test cross lines)
var hourGlass = parsePath("""
  M 20 20 L 180 20 L 20 180 L 180 180 z
""")

var hourGlass2 = parsePath("""
  M 20 20 L 180 20 L 20 180 L 180 180 z M 62 24 L 132 24 L 50 173 L 156 173 z
""")

# Hole
var hole = parsePath("""
  M 40 40 L 40 160 L 160 160 L 160 40 z
  M 120 80 L 120 120 L 80 120 L 80 80 z
""")

var holeEvenOdd = parsePath("""
  M 40 40 L 40 160 L 160 160 L 160 40 z
  M 80 80 L 80 120 L 120 120 L 120 80 z
""")

## g
var letterG = parsePath("""
  M 406 538 Q 394 546 359.5 558.5 T 279 571 Q 232 571 190.5 556 T 118 509.5 T 69 431 T 51 319 Q 51 262 68 214.5 T 117.5 132.5 T 197 78.5 T 303 59 Q 368 59 416.5 68.5 T 498 86 V 550 Q 498 670 436 724 T 248 778 Q 199 778 155.5 770 T 80 751 L 97 670 Q 125 681 165.5 689.5 T 250 698 Q 333 698 369.5 665 T 406 560 V 538 Z M 405 152 Q 391 148 367.5 144.5 T 304 141 Q 229 141 188.5 190 T 148 320 Q 148 365 159.5 397 T 190.5 450 T 235.5 481 T 288 491 Q 325 491 356 480.5 T 405 456 V 152 Z
""")
letterG.transform(scale(vec2(0.2, 0.2)))

when defined(bench):
  test("rect", rect, 100)
  test("rhombus", rhombus, 100)
  test("heart", heart, 100)
  test("cricle", cricle, 100)
  test("halfAarc", halfAarc, 100)
  test("hourGlass", hourGlass, 100)
  test("hourGlass2", hourGlass2, wr=NonZero)
  test("hourGlass2", hourGlass2, wr=EvenOdd)
  test("hole", hole, 100)
  test("holeEvenOdd", holeEvenOdd, 100, wr=NonZero)
  test("holeEvenOdd", holeEvenOdd, 100, wr=EvenOdd)
  test("letterG", letterG, 100)
else:
  # test("rect", rect)
  # test("rhombus", rhombus)
  # test("heart", heart)
  # test("cricle", cricle)
  # test("halfAarc", halfAarc)
  # test("hourGlass", hourGlass)
  test("hourGlass2", hourGlass2, wr=EvenOdd)
  # test("hole", hole, wr=EvenOdd)
  # test("holeEvenOdd", holeEvenOdd, wr=NonZero)
  # test("holeEvenOdd", holeEvenOdd, wr=EvenOdd)
  # test("letterG", letterG)
