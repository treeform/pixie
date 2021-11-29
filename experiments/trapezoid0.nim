
import algorithm, bumpy, chroma, pixie, pixie/images, pixie/paths, print,
    sequtils, vmath

printColors = false

proc intersectsInner*(a, b: Segment, at: var Vec2): bool {.inline.} =
  ## Checks if the a segment intersects b segment.
  ## If it returns true, at will have point of intersection
  let
    s1 = a.to - a.at
    s2 = b.to - b.at
    denominator = (-s2.x * s1.y + s1.x * s2.y)
    s = (-s1.y * (a.at.x - b.at.x) + s1.x * (a.at.y - b.at.y)) / denominator
    t = (s2.x * (a.at.y - b.at.y) - s2.y * (a.at.x - b.at.x)) / denominator

  if s > 0 and s < 1 and t >= 0 and t <= 1:
    at = a.at + (t * s1)
    return true

type Trapezoid = object
  nw, ne, se, sw: Vec2

proc roundBy*(v: Vec2, n: float32): Vec2 {.inline.} =
  result.x = sign(v.x) * round(abs(v.x) / n) * n
  result.y = sign(v.y) * round(abs(v.y) / n) * n

proc pathToTrapezoids(p: Path): seq[Trapezoid] =

  var polygons = p.commandsToShapes()

  const q = 1/256.0

  # Creates segment q, quantize and remove verticals.
  var segments1: seq[Segment]
  for shape in polygons:
    for s in shape.segments:
      var s = s
      s.at = s.at.roundBy(q)
      s.to = s.to.roundBy(q)
      if s.at.y != s.to.y:
        segments1.add(s)
  #print segments1

  # Handle segments overlapping each other:
  # var segments1: seq[Segment]
  # while segments0.len > 0:
  #   var a = segments0.pop()
  #   var collision = false
  #   for b in segments0:
  #     if a != b:
  #       var at: Vec2
  #       if a.intersectsInner(b, at):
  #         print "seg2seg intersects!", a, b, at
  #         quit()
  #   if not collision:
  #     segments1.add(a)

  # There is probably a clever way to insert-sort them.
  var yScanLines: seq[float32]
  for s in segments1:
    if s.at.y notin yScanLines:
      yScanLines.add s.at.y
    if s.to.y notin yScanLines:
      yScanLines.add s.to.y
  yScanLines.sort()

  var segments: seq[Segment]
  while segments1.len > 0:
    #print segments1.len, segments.len
    var s = segments1.pop()
    var collision = false
    for y in yScanLines:
      var at: Vec2
      if intersects(line(vec2(0, y), vec2(1, y)), s, at):
        at = at.roundBy(q)
        at.y = y
        if s.at.y != at.y and s.to.y != at.y:
          #print "seg2yline intersects!", a, y, at
          collision = true
          var s1 = segment(s.at, at)
          var s2 = segment(at, s.to)
          #print s.length, "->", s1.length, s2.length
          segments1.add(s1)
          segments1.add(s2)
          break

    if not collision:
      segments.add(s)

  #print segments

  # sort at/to in segments
  for s in segments.mitems:
    if s.at.y > s.to.y:
      swap(s.at, s.to)

  #print segments
  #print yScanLines

  for yScanLine in yScanLines[0..^2]:

    var scanSegments: seq[Segment]
    for s in segments:
      if s.at.y == yScanLine:
        scanSegments.add(s)
    scanSegments.sort(proc(a, b: Segment): int =
      cmp(a.at.x, b.at.x))

    if scanSegments.len mod 2 != 0:
      print "error???"
      print yScanLine
      print scanSegments
      quit()

    # if scanSegments.len == 0:
    #   print "error???"
    #   print yScanLine
    #   print scanSegments
    #   quit()

    # TODO: winding rules will go here

    for i in 0 ..< scanSegments.len div 2:
      let
        a = scanSegments[i*2+0]
        b = scanSegments[i*2+1]

      assert a.at.y == b.at.y
      assert a.to.y == b.to.y
      #assert a.at.x < b.at.x
      #assert a.to.x < b.to.x

      result.add(
        Trapezoid(
          nw: a.at,
          ne: b.at,
          se: b.to, # + vec2(0,0.7),
        sw: a.to # + vec2(0,0.7)
      )
      )

proc trapFill(image: Image, t: Trapezoid, color: ColorRGBA) =
  # assert t.nw.y == t.ne.y
  # assert t.sw.y == t.se.y

  let
    height = t.sw.y - t.nw.y
    minY = clamp(t.nw.y, 0, image.height.float)
    maxY = clamp(t.sw.y, 0, image.height.float)
  for y in minY.int ..< maxY.int:
    var yRate, minX, maxX: float32

    yRate = clamp((y.float - t.nw.y) / height, 0, 1)
    minX = clamp(lerp(t.nw.x, t.sw.x, yRate).round, 0, image.width.float)
    maxX = clamp(lerp(t.ne.x, t.se.x, yRate).round, 0, image.width.float)

    for x in minX.int ..< maxX.int:
      image.setRgbaUnsafe(x, y, color)

proc drawTrapezoids(image: Image, trapezoids: seq[Trapezoid]) =

  for trapezoid in trapezoids:
    image.trapFill(trapezoid, rgba(0, 0, 0, 255))

  # for trapezoid in trapezoids:
  #   var p = newPath()
  #   p.moveTo(trapezoid.nw)
  #   p.lineTo(trapezoid.ne)
  #   p.lineTo(trapezoid.se)
  #   p.lineTo(trapezoid.sw)
  #   p.closePath()
  #   image.fillPath(p, rgba(0, 0, 0, 255))
  #   image.strokePath(p, rgba(255, 0, 0, 255))

block:
  # Rect
  print "rect"
  var image = newImage(200, 200)
  image.fill(rgba(255, 255, 255, 255))

  var p: Path
  p.moveTo(50, 50)
  p.lineTo(50, 150)
  p.lineTo(150, 150)
  p.lineTo(150, 50)
  p.closePath()

  var trapezoids = p.pathToTrapezoids()
  image.drawTrapezoids(trapezoids)

  image.writeFile("experiments/trapezoids/rect.png")

block:
  # Rhombus
  print "rhombus"
  var image = newImage(200, 200)
  image.fill(rgba(255, 255, 255, 255))

  var p: Path
  p.moveTo(100, 50)
  p.lineTo(150, 100)
  p.lineTo(100, 150)
  p.lineTo(50, 100)
  p.closePath()

  var trapezoids = p.pathToTrapezoids()
  image.drawTrapezoids(trapezoids)

  image.writeFile("experiments/trapezoids/rhombus.png")

block:
  # heart
  print "heart"
  var image = newImage(400, 400)
  image.fill(rgba(255, 255, 255, 255))

  var p = parsePath("""
    M 40 120 A 80 80 90 0 1 200 120 A 80 80 90 0 1 360 120
    Q 360 240 200 360 Q 40 240 40 120 z
  """)

  var trapezoids = p.pathToTrapezoids()
  image.drawTrapezoids(trapezoids)

  image.writeFile("experiments/trapezoids/heart.png")

block:
  # l
  print "l"
  var image = newImage(500, 800)
  image.fill(rgba(255, 255, 255, 255))

  var p = parsePath("""
    M 236 20 Q 150 22 114 57 T 78 166 V 790 L 171 806 V 181 Q 171 158 175 143 T 188 119 T 212 105.5 T 249 98 Z
  """)

  #image.strokePath(p, rgba(0, 0, 0, 255))

  var trapezoids = p.pathToTrapezoids()
  image.drawTrapezoids(trapezoids)

  image.writeFile("experiments/trapezoids/l.png")

block:
  # g
  print "g"
  var image = newImage(500, 800)
  image.fill(rgba(255, 255, 255, 255))

  var p = parsePath("""
    M 406 538 Q 394 546 359.5 558.5 T 279 571 Q 232 571 190.5 556 T 118 509.5 T 69 431 T 51 319 Q 51 262 68 214.5 T 117.5 132.5 T 197 78.5 T 303 59 Q 368 59 416.5 68.5 T 498 86 V 550 Q 498 670 436 724 T 248 778 Q 199 778 155.5 770 T 80 751 L 97 670 Q 125 681 165.5 689.5 T 250 698 Q 333 698 369.5 665 T 406 560 V 538 Z M 405 152 Q 391 148 367.5 144.5 T 304 141 Q 229 141 188.5 190 T 148 320 Q 148 365 159.5 397 T 190.5 450 T 235.5 481 T 288 491 Q 325 491 356 480.5 T 405 456 V 152 Z
  """)

  #image.strokePath(p, rgba(0, 0, 0, 255))

  var trapezoids = p.pathToTrapezoids()
  image.drawTrapezoids(trapezoids)

  image.writeFile("experiments/trapezoids/g.png")
