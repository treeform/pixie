
import algorithm, bumpy, chroma, pixie/images, print,
    sequtils, vmath, benchy

import pixie, pixie/paths {.all.}


printColors = false

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

  if s > 0 and s < 1 and t >= 0 and t <= 1:
    at = a.at + (t * s1)
    return true

type

  Trapezoid = object
    nw, ne, se, sw: Vec2

proc roundBy*(v: Vec2, n: float32): Vec2 {.inline.} =
  result.x = sign(v.x) * round(abs(v.x) / n) * n
  result.y = sign(v.y) * round(abs(v.y) / n) * n

proc fillPath2(mask: Mask, p: Path) =

  var polygons = p.commandsToShapes()

  const q = 1/256.0

  # Creates segment q, quantize and remove horizontal lines.
  var segments1: seq[Segment]
  for shape in polygons:
    for s in shape.segments:
      var s = s
      s.at = s.at.roundBy(q)
      s.to = s.to.roundBy(q)
      if s.at.y != s.to.y:
        if s.at.y > s.to.y:
          # make sure segments always are at.y higher
          swap(s.at, s.to)
        segments1.add(s)
  segments1.sort(proc(a, b: Segment): int = cmp(a.at.y, b.at.y))

  # Dumb way to compute cutLines
  # var cutLines: seq[float32]
  # for s in segments1:
  #   if s.at.y notin cutLines:
  #     cutLines.add s.at.y
  #   if s.to.y notin cutLines:
  #     cutLines.add s.to.y
  # cutLines.sort()

  # Compute cutLines
  var
    cutLines: seq[float32]
    last = segments1[0].at.y
    bottom = segments1[0].to.y
  cutLines.add(last)
  for s in segments1:
    if s.at.y != last:
      last = s.at.y
      cutLines.add(last)
    if bottom < s.to.y:
      bottom = s.to.y
  cutLines.add(bottom)
  #print cutLines

  var
    sweeps = newSeq[seq[Segment]](cutLines.len - 1) # dont add bottom cutLine
    lastSeg = 0

  for i, sweep in sweeps.mpairs:
    #print "sweep", i, cutLines[i]
    while segments1[lastSeg].at.y == cutLines[i]:
      let s = segments1[lastSeg]
      #print s
      if s.to.y != cutLines[i + 1]:
        #print "needs cut?"
        quit()
      sweep.add(segments1[lastSeg])
      inc lastSeg
      if lastSeg >= segments1.len:
        # Sort the last sweep by X
        break
    # Sort the sweep by X
    sweep.sort(proc(a, b: Segment): int = cmp(a.at.x, b.at.x))

  proc fillCoverage(y: int, currCutLine: int, sweep: seq[Segment]) =


    # var i = 0
    # let
    #   sweepHeight = cutLines[currCutLine + 1] - cutLines[currCutLine]
    #   yFracTop = (y.float - cutLines[currCutLine]) / sweepHeight
    #   yFracBottom = (y.float + 1 - cutLines[currCutLine]) / sweepHeight
    # #print "cover", y, sweepHeight, yFrac
    # while i < sweep.len:
    #   #print "fill", sweep[i].at.x, "..", sweep[i+1].at.x
    #   let
    #     minXf1 = mix(sweep[i+0].at.x, sweep[i+0].to.x, yFracTop)
    #     maxXf1 = mix(sweep[i+1].at.x, sweep[i+1].to.x, yFracTop)

    #     minXf2 = mix(sweep[i+0].at.x, sweep[i+0].to.x, yFracBottom)
    #     maxXf2 = mix(sweep[i+1].at.x, sweep[i+1].to.x, yFracBottom)

    #     minXi1 = minXf1.floor.int
    #     maxXi1 = maxXf1.floor.int

    #     minXi2 = minXf2.floor.int
    #     maxXi2 = maxXf2.floor.int

    #   for x in min(minXi1, minXi2) .. max(maxXi1, maxXi2):
    #     var a = 1.0f
    #     # if x < max(minXi1, minXi2):
    #     #   a = 0.1
    #     # elif x > min(maxXi1, maxXi2):
    #     #   a = 0.1
    #     # else:
    #     #   a = 0.5
    #     let backdrop = mask.getValueUnsafe(x, y)
    #     mask.setValueUnsafe(x, y, backdrop + (a * 255).uint8)
    #   i += 2

    # x10 slower
    # for x in 0 ..< mask.width:
    #   for i, seg in sweep:
    #     var area = pixelCover(seg.at - vec2(x.float32, y.float32), seg.to - vec2(x.float32, y.float32))
    #     if i mod 2 == 1:
    #       area = -area
    #     let backdrop = mask.getValueUnsafe(x, y)
    #     mask.setValueUnsafe(x, y, backdrop + (area * 255).uint8)

    let quality = 5
    for m in 0 ..< quality:
      let
        sweepHeight = cutLines[currCutLine + 1] - cutLines[currCutLine]
        yFrac = (y.float32 + (m.float32 / quality.float32) - cutLines[currCutLine]) / sweepHeight
      if yFrac < 0.0 or yFrac >= 1.0:
        continue
      var i = 0
      while i < sweep.len:
        let
          minXf1 = mix(sweep[i+0].at.x, sweep[i+0].to.x, yFrac)
          maxXf1 = mix(sweep[i+1].at.x, sweep[i+1].to.x, yFrac)
          minXi1 = minXf1.int
          maxXi1 = maxXf1.int
        for x in minXi1 ..< maxXi1:
          let backdrop = mask.getValueUnsafe(x, y)
          mask.setValueUnsafe(x, y, backdrop + (255 div quality).uint8)
          # if x == 100 and y == 165:
          #   print backdrop, 255 div quality
          #   print mask.getValueUnsafe(x, y)
        i += 2

    # let
    #   sweepHeight = cutLines[currCutLine + 1] - cutLines[currCutLine]
    #   yFrac = (y.float32 - cutLines[currCutLine]) / sweepHeight
    # var i = 0
    # while i < sweep.len:
    #   let
    #     minXf1 = mix(sweep[i+0].at.x, sweep[i+0].to.x, yFrac)
    #     maxXf1 = mix(sweep[i+1].at.x, sweep[i+1].to.x, yFrac)
    #     minXi1 = minXf1.floor.int
    #     maxXi1 = maxXf1.floor.int
    #   for x in minXi1 .. maxXi1:
    #     mask.setValueUnsafe(x, y, 255)
    #   i += 2

  var
    currCutLine = 0
  for scanLine in cutLines[0].int ..< cutLines[^1].ceil.int:
    print scanLine, "..<", scanLine + 1
    print "  ", currCutLine, cutLines[currCutLine], "..<", cutLines[currCutLine + 1]
    fillCoverage(scanLine, currCutLine, sweeps[currCutLine])
    while cutLines[currCutLine + 1] < scanLine.float + 1.0:
      inc currCutLine
      print "  ", currCutLine, cutLines[currCutLine], "..<", cutLines[currCutLine + 1]
      fillCoverage(scanLine, currCutLine, sweeps[currCutLine])

  # print sweeps[^1]
  # print cutLines




  # var segments: seq[Segment]
  # while segments1.len > 0:
  #   #print segments1.len, segments.len
  #   var s = segments1.pop()
  #   var collision = false
  #   for y in cutLines:
  #     let scanLine = line(vec2(0, y), vec2(1, y))
  #     var at: Vec2
  #     if intersects(scanLine, s, at):
  #       at = at.roundBy(q)
  #       at.y = y
  #       if s.at.y != at.y and s.to.y != at.y:
  #         #print "seg2yline intersects!", a, y, at
  #         collision = true
  #         var s1 = segment(s.at, at)
  #         var s2 = segment(at, s.to)
  #         #print s.length, "->", s1.length, s2.length
  #         segments1.add(s1)
  #         segments1.add(s2)
  #         break

  #   if not collision:
  #     # means its touching, not intersecting
  #     segments.add(s)

  # # sort at/to in segments
  # # for s in segments.mitems:
  # #   if s.at.y > s.to.y:
  # #     swap(s.at, s.to)


  # #let blender = blendMode.blender()

  # for yScanLine in cutLines[0..^2]:

  #   var scanSegments: seq[Segment]
  #   for s in segments:
  #     if s.at.y == yScanLine:
  #       scanSegments.add(s)
  #   scanSegments.sort(proc(a, b: Segment): int =
  #     cmp(a.at.x, b.at.x))

  #   # if scanSegments.len mod 2 != 0:
  #   #   print "error???"
  #   #   print yScanLine
  #   #   print scanSegments
  #   #   quit()

  #   # TODO: winding rules will go here

  #   var trapezoids: seq[Trapezoid]
  #   for i in 0 ..< scanSegments.len div 2:
  #     let
  #       a = scanSegments[i*2+0]
  #       b = scanSegments[i*2+1]

  #     assert a.at.y == b.at.y
  #     assert a.to.y == b.to.y
  #     #assert a.at.x < b.at.x
  #     #assert a.to.x < b.to.x

  #     trapezoids.add(Trapezoid(
  #       nw: a.at,
  #       ne: b.at,
  #       se: b.to, # + vec2(0,0.7),
  #       sw: a.to # + vec2(0,0.7)
  #     ))

  #   var i = 0
  #   while i < trapezoids.len:

  #     let t = trapezoids[i]
  #     # print t
  #     let
  #       nw = t.nw
  #       ne = t.ne
  #       se = t.se
  #       sw = t.sw

  #     let
  #       height = sw.y - nw.y
  #       minYf = nw.y
  #       maxYf = sw.y
  #       minYi = minYf.floor.int
  #       maxYi = maxYf.floor.int

  #     # print t

  #     for y in minYi .. maxYi:
  #       let
  #         yFrac = (y.float - nw.y) / height
  #         minXf = mix(nw.x, sw.x, yFrac)
  #         maxXf = mix(ne.x, se.x, yFrac)
  #         minXi = minXf.floor.int
  #         maxXi = maxXf.floor.int
  #       #print yFrac
  #       # if not(minY.int == 58 or maxY.int == 58) or minX > 100:
  #       #   continue

  #       var ay: float32
  #       if y == minYi and y == maxYi:
  #         ay = maxYf - minYf
  #         # print "middle", maxYf, minYf, a
  #         #print "double", y, a, minY, maxY, round(a * 255)
  #       elif y == minYi:
  #         ay = (1 - (minYf - float32(minYi)))
  #         # print "min y", minYf, minYi, a
  #         #print "s", y, a, minY, round(a * 255)
  #       elif y == maxYi:
  #         ay = (maxYf - float32(maxYi))
  #         #print "max y", maxYf, maxYi, a
  #         # print "e", y, a, maxY, round(a * 255)
  #       else:
  #         ay = 1.0

  #       for x in minXi .. maxXi:
  #         var ax: float32
  #         # if x == minXi:
  #         #   a2 = (1 - (minXf - float32(minXi)))
  #         #   #a2 = 1.0
  #         # elif x == maxXi:
  #         #   a2 = (maxXf - float32(maxXi))
  #         #   #a2 = 1.0
  #         # else:
  #         #   a2 = 1.0

  #         if x.float32 < max(nw.x, sw.x):
  #           ax = 0.5
  #         elif x.float32 > min(ne.x, se.x):
  #           ax = 0.25
  #         else:
  #           ax = 1.0

  #         let backdrop = mask.getValueUnsafe(x, y)
  #         mask.setValueUnsafe(x, y, backdrop + floor(255 * ay * ax).uint8)
  #         # if x == 100 and y == 172:
  #         #   print backdrop, round(255 * a * a2).uint8
  #         #   print mask.getValueUnsafe(x, y)

  #     inc i

block:
  # Rect
  print "rect"
  #var image = newImage(200, 200)

  # var p = Path()
  # p.moveTo(50.25, 50.25)
  # p.lineTo(50.25, 150.25)
  # p.lineTo(150.25, 150.25)
  # p.lineTo(150.25, 50.25)
  # p.closePath()

  var p = parsePath("""
    M 20 60
    A 40 40 90 0 1 100 60
    A 40 40 90 0 1 180 60
    Q 180 120 100 180
    Q 20 120 20 60
    z
  """)

  # image.fill(rgba(255, 255, 255, 255))
  #image.fillPath2(p, color(0, 0, 0, 1))

  var mask = newMask(200, 200)
  timeIt "rect trapezoids", 1:
    #for i in 0 ..< 100:
      mask.fill(0)
      mask.fillPath2(p)
      #image.fillPath2(p, color(0, 0, 0, 1))
  mask.writeFile("experiments/trapezoids/rect_trapesoid.png")

  var mask2 = newMask(200, 200)
  timeIt "rect normal", 1:
    #for i in 0 ..< 100:
      mask2.fill(0)
      mask2.fillPath(p)
  mask2.writeFile("experiments/trapezoids/rect_scanline.png")

  let (score, image) = diff(mask.newImage, mask2.newImage)
  print score
  image.writeFile("experiments/trapezoids/rect_diff.png")



# block:
#   # Rhombus
#   print "rhombus"
#   var image = newImage(200, 200)
#   image.fill(rgba(255, 255, 255, 255))

#   var p = Path()
#   p.moveTo(100, 50)
#   p.lineTo(150, 100)
#   p.lineTo(100, 150)
#   p.lineTo(50, 100)
#   p.closePath()

#   image.fillPath2(p, color(0, 0, 0, 1))

#   image.writeFile("experiments/trapezoids/rhombus.png")

# block:
#   # heart
#   print "heart"
#   var image = newImage(400, 400)
#   image.fill(rgba(0, 0, 0, 0))

#   var p = parsePath("""
#     M 40 120 A 80 80 90 0 1 200 120 A 80 80 90 0 1 360 120
#     Q 360 240 200 360 Q 40 240 40 120 z
#   """)

#   var mask = newMask(image)
#   mask.fillPath2(p)

#   image.draw(mask, blendMode = OverwriteBlend)

#   image.writeFile("experiments/trapezoids/heart.png")

# block:
#   # l
#   print "l"
#   var image = newImage(500, 800)
#   image.fill(rgba(255, 255, 255, 255))

#   var p = parsePath("""
#     M 236 20 Q 150 22 114 57 T 78 166 V 790 L 171 806 V 181 Q 171 158 175 143 T 188 119 T 212 105.5 T 249 98 Z
#   """)

#   image.fillPath2(p, color(0, 0, 0, 1))

#   image.writeFile("experiments/trapezoids/l.png")

# block:
#   # g
#   print "g"
#   var image = newImage(500, 800)
#   image.fill(rgba(255, 255, 255, 255))

#   var p = parsePath("""
#     M 406 538 Q 394 546 359.5 558.5 T 279 571 Q 232 571 190.5 556 T 118 509.5 T 69 431 T 51 319 Q 51 262 68 214.5 T 117.5 132.5 T 197 78.5 T 303 59 Q 368 59 416.5 68.5 T 498 86 V 550 Q 498 670 436 724 T 248 778 Q 199 778 155.5 770 T 80 751 L 97 670 Q 125 681 165.5 689.5 T 250 698 Q 333 698 369.5 665 T 406 560 V 538 Z M 405 152 Q 391 148 367.5 144.5 T 304 141 Q 229 141 188.5 190 T 148 320 Q 148 365 159.5 397 T 190.5 450 T 235.5 481 T 288 491 Q 325 491 356 480.5 T 405 456 V 152 Z
#   """)

#   image.fillPath2(p, color(0, 0, 0, 1))

#   image.writeFile("experiments/trapezoids/g.png")
