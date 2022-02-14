
import algorithm, bumpy, chroma, pixie/images, print,
    vmath, benchy, fidget2/perf

import pixie, pixie/paths {.all.}

when defined(release):
  {.push checks: off.}

proc pixelCover(a0, b0: Vec2): float32 =
  ## Returns the amount of area a given segment sweeps to the right
  ## in a [0,0 to 1,1] box.
  var
    a = a0
    b = b0
    aI: Vec2
    bI: Vec2
    area: float32 = 0.0

  # # Sort A on top.
  # if a.y > b.y:
  #   let tmp = a
  #   a = b
  #   b = tmp

  # if (b.y < 0 or a.y > 1) or # Above or bellow, no effect.
  #   (a.x >= 1 and b.x >= 1) or # To the right, no effect.
  #   (a.y == b.y): # Horizontal line, no effect.
  #   return 0

  if (a.x < 0 and b.x < 0) or # Both to the left.
    (a.x == b.x): # Vertical line
    # Area of the rectangle:
    return (1 - clamp(a.x, 0, 1)) * (min(b.y, 1) - max(a.y, 0))

  else:
    # y = mm*x + bb
    let
      mm: float32 = (b.y - a.y) / (b.x - a.x)
      bb: float32 = a.y - mm * a.x

    if a.x >= 0 and a.x <= 1 and a.y >= 0 and a.y <= 1:
      # A is in pixel bounds.
      aI = a
    else:
      aI = vec2((0 - bb) / mm, 0)
      if aI.x < 0:
        let y = mm * 0 + bb
        # Area of the extra rectangle.
        area += (min(bb, 1) - max(a.y, 0)).clamp(0, 1)
        aI = vec2(0, y.clamp(0, 1))
      elif aI.x > 1:
        let y = mm * 1 + bb
        aI = vec2(1, y.clamp(0, 1))

    if b.x >= 0 and b.x <= 1 and b.y >= 0 and b.y <= 1:
      # B is in pixel bounds.
      bI = b
    else:
      bI = vec2((1 - bb) / mm, 1)
      if bI.x < 0:
        let y = mm * 0 + bb
        # Area of the extra rectangle.
        area += (min(b.y, 1) - max(bb, 0)).clamp(0, 1)
        bI = vec2(0, y.clamp(0, 1))
      elif bI.x > 1:
        let y = mm * 1 + bb
        bI = vec2(1, y.clamp(0, 1))

  area += ((1 - aI.x) + (1 - bI.x)) / 2 * (bI.y - aI.y)
  return area

proc intersectsInner*(a, b: Segment, at: var Vec2): bool {.inline.} =
  ## Checks if the a segment intersects b segment.
  ## If it returns true, at will have point of intersection
  let
    s1 = a.to - a.at
    s2 = b.to - b.at
    denominator = (-s2.x * s1.y + s1.x * s2.y)
    s = (-s1.y * (a.at.x - b.at.x) + s1.x * (a.at.y - b.at.y)) / denominator
    t = (s2.x * (a.at.y - b.at.y) - s2.y * (a.at.x - b.at.x)) / denominator

  if s > 0 and s < 1 and t > 0 and t < 1:
    #print s, t
    at = a.at + (t * s1)
    return true

type

  Trapezoid = object
    nw, ne, se, sw: Vec2

  Line = object
    #m, x, b: float32
    atx, tox: float32
    winding: int16

proc toLine(s: (Segment, int16)): Line =
  var line = Line()
  # y = mx + b
  line.atx = s[0].at.x
  line.tox = s[0].to.x
  line.winding = s[1]
  # line.m = (s.at.y - s.to.y) / (s.at.x - s.to.x)
  # line.b = s.at.y - line.m * s.at.x
  return line

proc roundBy*(v: Vec2, n: float32): Vec2 {.inline.} =
  result.x = sign(v.x) * round(abs(v.x) / n) * n
  result.y = sign(v.y) * round(abs(v.y) / n) * n


proc computeBounds(polygons: seq[seq[Vec2]]): Rect =
  ## Compute the bounds of the segments.
  var
    xMin = float32.high
    xMax = float32.low
    yMin = float32.high
    yMax = float32.low
  for segments in polygons:
    for v in segments:
      xMin = min(xMin, v.x)
      xMax = max(xMax, v.x)
      yMin = min(yMin, v.y)
      yMax = max(yMax, v.y)

  if xMin.isNaN() or xMax.isNaN() or yMin.isNaN() or yMax.isNaN():
    discard
  else:
    result.x = xMin
    result.y = yMin
    result.w = xMax - xMin
    result.h = yMax - yMin

proc binaryInsert(arr: var seq[float32], v: float32) =
  if arr.len == 0:
    arr.add(v)
    return
  var
    L = 0
    R = arr.len - 1
  while L < R:
    let m = (L + R) div 2
    if arr[m] ~= v:
      return
    elif arr[m] < v:
      L = m + 1
    else: # arr[m] > v:
      R = m - 1
  if arr[L] ~= v:
    return
  elif arr[L] > v:
    #print "insert", v, arr, L, R
    arr.insert(v, L)
  else:
    #print "insert", v, arr, L, R
    arr.insert(v, L + 1)


proc fillPath2(image: Image, p: Path, color: Color, windingRule = NonZero, blendMode = NormalBlend) =
  const q = 1/256.0
  let rgbx = color.rgbx
  var segments = p.commandsToShapes(true, 1.0).shapesToSegments()
  let
    bounds = computeBounds(segments).snapToPixels()
    startX = max(0, bounds.x.int)

  # Create sorted segments and quantize.
  segments.sort(proc(a, b: (Segment, int16)): int = cmp(a[0].at.y, b[0].at.y))

  # Compute cut lines
  var cutLines: seq[float32]
  for s in segments:
    cutLines.binaryInsert(s[0].at.y)
    cutLines.binaryInsert(s[0].to.y)

  var
    sweeps = newSeq[seq[Line]](cutLines.len - 1) # dont add bottom cutLine
    lastSeg = 0
    i = 0
  while i < sweeps.len:

    #for i, sweep in sweeps.mpairs:
    #print "sweep", i, cutLines[i]

    if lastSeg < segments.len:

      while segments[lastSeg][0].at.y == cutLines[i]:
        let s = segments[lastSeg]

        if s[0].at.y != s[0].to.y:

          #print s
          if s[0].to.y != cutLines[i + 1]:
            #print "needs cut?", s

            #quit("need to cut lines")
            var at: Vec2
            var seg = s[0]
            for j in i ..< sweeps.len:
              let y = cutLines[j + 1]
              if intersects(line(vec2(0, y), vec2(1, y)), seg, at):
                #print "cutting", j, seg
                #print "add cut", j, segment(seg.at, at)
                sweeps[j].add(toLine((segment(seg.at, at), s[1])))
                seg = segment(at, seg.to)
              else:
                if seg.at.y != seg.to.y:
                  #print "add rest", j, segment(seg.at, seg.to)
                  sweeps[j].add(toLine(s))
                # else:
                #   print "micro?"
                break
          else:
            #print "add", s
            sweeps[i].add(toLine(s))

        inc lastSeg

        if lastSeg >= segments.len:
          break
    inc i

  i = 0
  while i < sweeps.len:
    for t in 0 ..< 10:
      # keep cutting sweep
      var needsCut = false
      var cutterLine: float32 = 0
      block doubleFor:
        for a in sweeps[i]:
          let aSeg = segment(vec2(a.atx, cutLines[i]), vec2(a.tox, cutLines[i+1]))
          for b in sweeps[i]:
            let bSeg = segment(vec2(b.atx, cutLines[i]), vec2(b.tox, cutLines[i+1]))
            var at: Vec2
            if intersectsInner(aSeg, bSeg, at):
              needsCut = true
              cutterLine = at.y
              break doubleFor
      if needsCut:
        var
          thisSweep = sweeps[i]
        sweeps[i].setLen(0)
        sweeps.insert(newSeq[Line](), i + 1)
        for a in thisSweep:
          let seg = segment(vec2(a.atx, cutLines[i]), vec2(a.tox, cutLines[i+1]))
          var at: Vec2
          if intersects(line(vec2(0, cutterLine), vec2(1, cutterLine)), seg, at):
            sweeps[i+0].add(toLine((segment(seg.at, at), a.winding)))
            sweeps[i+1].add(toLine((segment(at, seg.to), a.winding)))
        cutLines.binaryInsert(cutterLine)
      else:
        break
    inc i


  i = 0
  while i < sweeps.len:
    # Sort the sweep by X
    sweeps[i].sort proc(a, b: Line): int =
      result = cmp(a.atx, b.atx)
      if result == 0:
        result = cmp(a.tox, b.tox)

    # Do winding order
    var
      pen = 0
      prevFill = false
      j = 0
    # print "sweep", i, "--------------"
    while j < sweeps[i].len:
      let a = sweeps[i][j]
      # print a.winding
      if a.winding == 1:
        inc pen
      if a.winding == -1:
        dec pen
      # print j, pen, prevFill, shouldFill(windingRule, pen)
      let thisFill = shouldFill(windingRule, pen)
      if prevFill == thisFill:
        # remove this line
        # print "remove", j
        sweeps[i].delete(j)
        continue
      prevFill = thisFill
      inc j

    # print sweeps[i]

    inc i

  #print sweeps
  # for s in 0 ..< sweeps.len:
  #   let
  #     y1 = cutLines[s]
  #   echo "M -100 ", y1
  #   echo "L 300 ", y1
  #   for line in sweeps[s]:
  #     let
  #       nw = vec2(line.atx, cutLines[s])
  #       sw = vec2(line.tox, cutLines[s + 1])
  #     echo "M ", nw.x, " ", nw.y
  #     echo "L ", sw.x, " ", sw.y

  proc computeCoverage(
    coverages: var seq[uint8],
    y: int,
    startX: int,
    cutLines: seq[float32],
    currCutLine: int,
    sweep: seq[Line]
  ) =

    # if sweep.len mod 2 != 0:
    #   return

    let
      sweepHeight = cutLines[currCutLine + 1] - cutLines[currCutLine]
      yFracTop = ((y.float32 - cutLines[currCutLine]) / sweepHeight).clamp(0, 1)
      yFracBottom = ((y.float32 + 1 - cutLines[currCutLine]) / sweepHeight).clamp(0, 1)
    var i = 0
    while i < sweep.len:
      let
        nwX = mix(sweep[i+0].atx, sweep[i+0].tox, yFracTop)
        neX = mix(sweep[i+1].atx, sweep[i+1].tox, yFracTop)

        swX = mix(sweep[i+0].atx, sweep[i+0].tox, yFracBottom)
        seX = mix(sweep[i+1].atx, sweep[i+1].tox, yFracBottom)

        minWi = min(nwX, swX).int
        maxWi = max(nwX, swX).ceil.int

        minEi = min(neX, seX).int
        maxEi = max(neX, seX).ceil.int

      let
        nw = vec2(sweep[i+0].atx, cutLines[currCutLine])
        sw = vec2(sweep[i+0].tox, cutLines[currCutLine + 1])
      for x in minWi ..< maxWi:
        var area = pixelCover(nw - vec2(x.float32, y.float32), sw - vec2(x.float32, y.float32))
        coverages[x - startX] += (area * 255).uint8

      let x = maxWi
      var midArea = pixelCover(nw - vec2(x.float32, y.float32), sw - vec2(x.float32, y.float32))
      var midArea8 = (midArea * 255).uint8
      for x in maxWi ..< minEi:
        coverages[x - startX] += midArea8

      let
        ne = vec2(sweep[i+1].atx, cutLines[currCutLine])
        se = vec2(sweep[i+1].tox, cutLines[currCutLine + 1])
      for x in minEi ..< maxEi:
        var area = midArea - pixelCover(ne - vec2(x.float32, y.float32), se - vec2(x.float32, y.float32))
        coverages[x - startX] += (area * 255).uint8

      i += 2

  var
    currCutLine = 0
    coverages = newSeq[uint8](bounds.w.int)
  for scanLine in cutLines[0].int ..< cutLines[^1].ceil.int:
    zeroMem(coverages[0].addr, coverages.len)

    coverages.computeCoverage(scanLine, startX, cutLines, currCutLine, sweeps[currCutLine])
    while cutLines[currCutLine + 1] < scanLine.float + 1.0:
      inc currCutLine
      if currCutLine == sweeps.len:
        break
      coverages.computeCoverage(scanLine, startX, cutLines, currCutLine, sweeps[currCutLine])

    image.fillCoverage(
      rgbx,
      startX = startX,
      y = scanLine,
      coverages,
      blendMode
    )

when defined(release):
  {.pop.}


template test(name: string, p: Path, a: static int = 1, wr = NonZero) =
  echo name
  var image = newImage(200, 200)
  timeIt "  sweeps", a:
    for i in 0 ..< a:
      image.fill(color(0, 0, 0, 0))
      image.fillPath2(p, color(1, 0, 0, 1), windingRule = wr)
  image.writeFile("experiments/trapezoids/output_sweep.png")

  var image2 = newImage(200, 200)
  timeIt "  scanline", a:
    for i in 0 ..< a:
      image2.fill(color(0, 0, 0, 0))
      image2.fillPath(p, color(1, 0, 0, 1), windingRule = wr)
  image2.writeFile("experiments/trapezoids/output_scanline.png")

  let (score, diff) = diff(image, image2)
  if score > 0.05:
    echo "does not appear ot match"
  diff.writeFile("experiments/trapezoids/output_diff.png")


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
  test("hole", hole, 100)
  test("holeNonZero", holeEvenOdd, 100, wr=NonZero)
  test("holeEvenOdd", holeEvenOdd, 100, wr=EvenOdd)
  test("letterG", letterG, 100)
else:
  # test("rect", rect)
  # test("rhombus", rhombus)
  # test("heart", heart)
  # test("cricle", cricle)
  # test("halfAarc", halfAarc)
  # test("hourGlass", hourGlass)
  #test("hole", hole, wr=EvenOdd)
  test("holeNonZero", holeEvenOdd, wr=NonZero)
  test("holeEvenOdd", holeEvenOdd, wr=EvenOdd)
  # test("letterG", letterG)
