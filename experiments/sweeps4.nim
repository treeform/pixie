
when defined(pixieSweeps):
  import algorithm

  proc pixelCover(a0, b0: Vec2): float32 =
    ## Returns the amount of area a given segment sweeps to the right
    ## in a [0,0 to 1,1] box.
    var
      a = a0
      b = b0
      aI: Vec2
      bI: Vec2
      area: float32 = 0.0

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
      at = a.at + (t * s1)
      return true

  type

    Trapezoid = object
      nw, ne, se, sw: Vec2

    SweepLine = object
      #m, x, b: float32
      atx, tox: float32
      winding: int16

  proc toLine(s: (Segment, int16)): SweepLine =
    var line = SweepLine()
    line.atx = s[0].at.x
    line.tox = s[0].to.x
    # y = mx + b
    # line.m = (s.at.y - s.to.y) / (s.at.x - s.to.x)
    # line.b = s.at.y - line.m * s.at.x
    line.winding = s[1]
    return line

  proc intersectsYLine(
    y: float32, s: Segment, atx: var float32
  ): bool {.inline.} =
    let
      s2y = s.to.y - s.at.y
      denominator = -s2y
      numerator = s.at.y - y
      u = numerator / denominator
    if u >= 0 and u <= 1:
      let at = s.at + (u * vec2(s.to.x - s.at.x, s2y))
      atx = at.x
      return true

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
      arr.insert(v, L)
    else:
      arr.insert(v, L + 1)

  proc sortSegments(segments: var seq[(Segment, int16)], inl, inr: int) =
    ## Quicksort + insertion sort, in-place and faster than standard lib sort.

    let n = inr - inl + 1
    if n < 32: # Use insertion sort for the rest
      for i in inl + 1 .. inr:
        var
          j = i - 1
          k = i
        while j >= 0 and segments[j][0].at.y > segments[k][0].at.y:
          swap(segments[j + 1], segments[j])
          dec j
          dec k
      return
    var
      l = inl
      r = inr
    let p = segments[l + n div 2][0].at.y
    while l <= r:
      if segments[l][0].at.y < p:
        inc l
      elif segments[r][0].at.y > p:
        dec r
      else:
        swap(segments[l], segments[r])
        inc l
        dec r
    sortSegments(segments, inl, r)
    sortSegments(segments, l, inr)

  proc sortSweepLines(segments: var seq[SweepLine], inl, inr: int) =
    ## Quicksort + insertion sort, in-place and faster than standard lib sort.

    proc avg(line: SweepLine): float32 {.inline.} =
      (line.tox + line.atx) / 2.float32

    let n = inr - inl + 1
    if n < 32: # Use insertion sort for the rest
      for i in inl + 1 .. inr:
        var
          j = i - 1
          k = i
        while j >= 0 and segments[j].avg > segments[k].avg:
          swap(segments[j + 1], segments[j])
          dec j
          dec k
      return
    var
      l = inl
      r = inr
    let p = segments[l + n div 2].avg
    while l <= r:
      if segments[l].avg < p:
        inc l
      elif segments[r].avg > p:
        dec r
      else:
        swap(segments[l], segments[r])
        inc l
        dec r
    sortSweepLines(segments, inl, r)
    sortSweepLines(segments, l, inr)

  proc fillShapes(
    image: Image,
    shapes: seq[seq[Vec2]],
    color: SomeColor,
    windingRule: WindingRule,
    blendMode: BlendMode
  ) =

    let rgbx = color.rgbx
    var segments = shapes.shapesToSegments()
    let
      bounds = computeBounds(segments).snapToPixels()
      startX = max(0, bounds.x.int)

    if segments.len == 0 or bounds.w.int == 0 or bounds.h.int == 0:
      return

    # const q = 1/10
    # for i in 0 ..< segments.len:
    #   segments[i][0].at.x = quantize(segments[i][0].at.x, q)
    #   segments[i][0].at.y = quantize(segments[i][0].at.y, q)
    #   segments[i][0].to.x = quantize(segments[i][0].to.x, q)
    #   segments[i][0].to.y = quantize(segments[i][0].to.y, q)

    # Create sorted segments.
    segments.sortSegments(0, segments.high)

    # Compute cut lines
    var cutLines: seq[float32]
    for s in segments:
      cutLines.binaryInsert(s[0].at.y)
      cutLines.binaryInsert(s[0].to.y)

    var
      # Dont add bottom cutLine.
      sweeps = newSeq[seq[SweepLine]](cutLines.len - 1)
      lastSeg = 0
      i = 0
    while i < sweeps.len:

      if lastSeg < segments.len:

        while segments[lastSeg][0].at.y == cutLines[i]:
          let s = segments[lastSeg]

          if s[0].to.y != cutLines[i + 1]:
            var atx: float32
            var seg = s[0]
            for j in i ..< sweeps.len:
              let y = cutLines[j + 1]
              if intersectsYLine(y, seg, atx):
                sweeps[j].add(toLine((segment(seg.at, vec2(atx, y)), s[1])))
                seg = segment(vec2(atx, y), seg.to)
              else:
                if seg.at.y != seg.to.y:
                  sweeps[j].add(toLine(s))
                break
          else:
            sweeps[i].add(toLine(s))

          inc lastSeg
          if lastSeg >= segments.len:
            break
      inc i

    # i = 0
    # while i < sweeps.len:
    #   # TODO: Maybe finds all cuts first, add them to array, cut all lines at once.
    #   var crossCuts: seq[float32]

    #   # echo i, " cut?"

    #   for aIndex in 0 ..< sweeps[i].len:
    #     let a = sweeps[i][aIndex]
    #     # echo i, ":", sweeps.len, ":", cutLines.len
    #     let aSeg = segment(vec2(a.atx, cutLines[i]), vec2(a.tox, cutLines[i+1]))
    #     for bIndex in aIndex + 1 ..< sweeps[i].len:
    #       let b = sweeps[i][bIndex]
    #       let bSeg = segment(vec2(b.atx, cutLines[i]), vec2(b.tox, cutLines[i+1]))
    #       var at: Vec2
    #       if intersectsInner(aSeg, bSeg, at):
    #         crossCuts.binaryInsert(at.y)

    #   if crossCuts.len > 0:
    #     var
    #       thisSweep = sweeps[i]
    #       yTop = cutLines[i]
    #       yBottom = cutLines[i + 1]
    #     sweeps[i].setLen(0)

    #     for k in crossCuts:
    #       let prevLen = cutLines.len
    #       cutLines.binaryInsert(k)
    #       if prevLen != cutLines.len:
    #         sweeps.insert(newSeq[SweepLine](), i + 1)

    #     for a in thisSweep:
    #       var seg = segment(vec2(a.atx, yTop), vec2(a.tox, yBottom))
    #       var at: Vec2
    #       for j, cutterLine in crossCuts:
    #         if intersects(line(vec2(0, cutterLine), vec2(1, cutterLine)), seg, at):
    #           sweeps[i+j].add(toLine((segment(seg.at, at), a.winding)))
    #           seg = segment(at, seg.to)
    #       sweeps[i+crossCuts.len].add(toLine((seg, a.winding)))

    #     i += crossCuts.len

    #   inc i

    i = 0
    while i < sweeps.len:
      # Sort the sweep by X
      sweeps[i].sortSweepLines(0, sweeps[i].high)
      # Do winding order
      var
        pen = 0
        prevFill = false
        j = 0
      while j < sweeps[i].len:
        let a = sweeps[i][j]
        if a.winding == 1:
          inc pen
        if a.winding == -1:
          dec pen
        let thisFill = shouldFill(windingRule, pen)
        if prevFill == thisFill:
          # Remove this sweep line.
          sweeps[i].delete(j)
          continue
        prevFill = thisFill
        inc j
      inc i

    # Used to debug sweeps:
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
      coverages: var seq[uint16],
      y: int,
      startX: int,
      cutLines: seq[float32],
      currCutLine: int,
      sweep: seq[SweepLine]
    ) =

      if cutLines[currCutLine + 1] - cutLines[currCutLine] < 1/256:
        # TODO some thing about micro sweeps
        return

      let
        sweepHeight = cutLines[currCutLine + 1] - cutLines[currCutLine]
        yFracTop = ((y.float32 - cutLines[currCutLine]) / sweepHeight).clamp(0, 1)
        yFracBottom = ((y.float32 + 1 - cutLines[currCutLine]) /
            sweepHeight).clamp(0, 1)
      var i = 0
      while i < sweep.len:
        let
          nwX = mix(sweep[i+0].atx, sweep[i+0].tox, yFracTop)
          neX = mix(sweep[i+1].atx, sweep[i+1].tox, yFracTop)

          swX = mix(sweep[i+0].atx, sweep[i+0].tox, yFracBottom)
          seX = mix(sweep[i+1].atx, sweep[i+1].tox, yFracBottom)

          minWi = min(nwX, swX).int      #.clamp(startX, coverages.len + startX)
          maxWi = max(nwX, swX).ceil.int #.clamp(startX, coverages.len + startX)

          minEi = min(neX, seX).int      #.clamp(startX, coverages.len + startX)
          maxEi = max(neX, seX).ceil.int #.clamp(startX, coverages.len + startX)

        let
          nw = vec2(sweep[i+0].atx, cutLines[currCutLine])
          sw = vec2(sweep[i+0].tox, cutLines[currCutLine + 1])
          f16 = (256 * 256 - 1).float32
        for x in minWi ..< maxWi:
          var area = pixelCover(
            nw - vec2(x.float32, y.float32),
            sw - vec2(x.float32, y.float32)
          )
          coverages[x - startX] += (area * f16).uint16

        let x = maxWi
        var midArea = pixelCover(
          nw - vec2(x.float32, y.float32),
          sw - vec2(x.float32, y.float32)
        )
        for x in maxWi ..< maxEi:
          coverages[x - startX] += (midArea * f16).uint16

        let
          ne = vec2(sweep[i+1].atx, cutLines[currCutLine])
          se = vec2(sweep[i+1].tox, cutLines[currCutLine + 1])
        for x in minEi ..< maxEi:
          var area = pixelCover(
            ne - vec2(x.float32, y.float32),
            se - vec2(x.float32, y.float32)
          )
          coverages[x - startX] -= (area * f16).uint16

        i += 2

    var
      currCutLine = 0
      coverages16 = newSeq[uint16](bounds.w.int)
      coverages8 = newSeq[uint8](bounds.w.int)
    for scanLine in max(cutLines[0].int, 0) ..< min(cutLines[^1].ceil.int, image.height):

      zeroMem(coverages16[0].addr, coverages16.len * 2)

      coverages16.computeCoverage(
        scanLine, startX, cutLines, currCutLine, sweeps[currCutLine])
      while cutLines[currCutLine + 1] < scanLine.float + 1.0:
        inc currCutLine
        if currCutLine == sweeps.len:
          break
        coverages16.computeCoverage(
          scanLine, startX, cutLines, currCutLine, sweeps[currCutLine])

      for i in 0 ..< coverages16.len:
        coverages8[i] = (coverages16[i] shr 8).uint8
      image.fillCoverage(
        rgbx,
        startX = startX,
        y = scanLine,
        coverages8,
        blendMode
      )

else:
