import vmath, images, chroma, strutils, algorithm, common

type

  PathCommandKind* = enum
    ## Type of path commands
    Start, End
    Move, Line, HLine, VLine, Cubic, SCurve, Quad, TQuad, Arc,
    RMove, RLine, RHLine, RVLine, RCubic, RSCurve, RQuad, RTQuad, RArc

  PathCommand* = object
    ## Binary version of an SVG command
    kind*: PathCommandKind
    numbers*: seq[float32]

  Path* = ref object
    at*: Vec2
    commands*: seq[PathCommand]

proc newPath*(): Path =
  result = Path()

proc commandNumbers(kind: PathCommandKind): int =
  ## How many numbers does a command take:
  case kind:
    of Start, End: 0
    of Move, Line, RMove, RLine: 2
    of HLine, VLine, RHLine, RVLine: 1
    of Cubic, RCubic: 6
    of SCurve, RSCurve, Quad, RQuad: 4
    of TQuad, RTQuad: 2
    of Arc, RArc: 7

proc parsePath*(path: string): Path =
  ## Converts a SVG style path into seq of commands.
  result = newPath()
  var command = Start
  var number = ""
  var numbers = newSeq[float32]()

  template finishDigit() =
    if number.len > 0:
      numbers.add(parseFloat(number))
      number = ""

  template finishCommand() =
    finishDigit()
    if command != Start:
      let num = commandNumbers(command)
      if num > 0:
        assert numbers.len mod num == 0
        for batch in 0 ..< numbers.len div num:
          result.commands.add PathCommand(
            kind: command,
            numbers: numbers[batch*num ..< (batch+1)*num]
          )
        numbers.setLen(0)
      else:
        assert numbers.len == 0
        result.commands.add PathCommand(kind: command)

  for c in path:
    case c:
      # Relative.
      of 'm':
        finishCommand()
        command = RMove
      of 'l':
        finishCommand()
        command = RLine
      of 'h':
        finishCommand()
        command = RHLine
      of 'v':
        finishCommand()
        command = RVLine
      of 'c':
        finishCommand()
        command = RCubic
      of 's':
        finishCommand()
        command = RSCurve
      of 'q':
        finishCommand()
        command = RQuad
      of 't':
        finishCommand()
        command = RTQuad
      of 'a':
        finishCommand()
        command = RArc
      of 'z':
        finishCommand()
        command = End
      # Absolute
      of 'M':
        finishCommand()
        command = Move
      of 'L':
        finishCommand()
        command = Line
      of 'H':
        finishCommand()
        command = HLine
      of 'V':
        finishCommand()
        command = VLine
      of 'C':
        finishCommand()
        command = Cubic
      of 'S':
        finishCommand()
        command = SCurve
      of 'Q':
        finishCommand()
        command = Quad
      of 'T':
        finishCommand()
        command = TQuad
      of 'A':
        finishCommand()
        command = Arc
      of 'Z':
        finishCommand()
        command = End
      # Punctuation
      of '-', '+':
        if number.len > 0 and number[^1] in {'e', 'E'}:
          number &= c
        else:
          finishDigit()
          number = $c
      of ' ', ',', '\r', '\n', '\t':
        finishDigit()
      else:
        if command == Move and numbers.len == 2:
          finishCommand()
          command = Line
        elif command == Line and numbers.len == 2:
          finishCommand()
          command = Line
        number &= c

  finishCommand()

proc `$`*(path: Path): string =
  for command in path.commands:
    case command.kind:
      of Move:
        result.add "M"
      of Arc:
        result.add "A"
      of Line:
        result.add "L"
      of End:
        result.add "Z"
      else:
        result.add "?"
    for number in command.numbers:
      if floor(number) == number:
        result.add $(number.int)
      else:
        result.add $number
      result.add " "

## See https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes

type ArcParams = object
  s: float32
  rx, ry: float32
  rotation: float32
  cx, cy: float32
  theta, delta: float32

proc svgAngle (ux, uy, vx, vy: float32): float32 =
  var u = vec2(ux, uy);
  var v = vec2(vx, vy);
  # (F.6.5.4)
  var dot = dot(u,v);
  var len = length(u) * length(v);
  var ang = arccos( clamp(dot / len,-1,1) ); # floating point precision, slightly over values appear
  if (u.x*v.y - u.y*v.x) < 0:
      ang = -ang
  return ang;

proc endpointToCenterArcParams(
  ax, ay, rx, ry, rotation, large, sweep, bx, by: float32
): ArcParams =

  var r = vec2(rx, ry)
  var p1 = vec2(ax, ay)
  var p2 = vec2(bx, by)
  var xAngle = rotation/180*PI
  var flagA = large == 1.0
  var flagS = sweep == 1.0
  var rX = abs(r.x)
  var rY = abs(r.y)

  # (F.6.5.1)
  var dx2 = (p1.x - p2.x) / 2.0
  var dy2 = (p1.y - p2.y) / 2.0
  var x1p = cos(xAngle)*dx2 + sin(xAngle)*dy2;
  var y1p = -sin(xAngle)*dx2 + cos(xAngle)*dy2;

  # (F.6.5.2)
  var rxs = rX * rX;
  var rys = rY * rY;
  var x1ps = x1p * x1p;
  var y1ps = y1p * y1p;
  #  check if the radius is too small `pq < 0`, when `dq > rxs * rys` (see below)
  #  cr is the ratio (dq : rxs * rys)
  var cr = x1ps/rxs + y1ps/rys;
  var s = 1.0
  if cr > 1:
      # scale up rX,rY equally so cr == 1
      s = sqrt(cr);
      rX = s * rX;
      rY = s * rY;
      rxs = rX * rX;
      rys = rY * rY;

  var dq = (rxs * y1ps + rys * x1ps);
  var pq = (rxs*rys - dq) / dq;
  var q = sqrt(max(0,pq)); # use Max to account for float precision
  if flagA == flagS:
      q = -q;
  var cxp = q * rX * y1p / rY;
  var cyp = - q * rY * x1p / rX;

  # (F.6.5.3)
  var cx = cos(xAngle)*cxp - sin(xAngle)*cyp + (p1.x + p2.x)/2;
  var cy = sin(xAngle)*cxp + cos(xAngle)*cyp + (p1.y + p2.y)/2;

  # (F.6.5.5)
  var theta = svgAngle( 1,0, (x1p-cxp) / rX, (y1p - cyp)/rY );
  # (F.6.5.6)
  var delta = svgAngle(
      (x1p - cxp)/rX, (y1p - cyp)/rY,
      (-x1p - cxp)/rX, (-y1p-cyp)/rY);
  delta = delta mod (PI * 2)

  if not flagS:
    delta -= 2 * PI;

  # normalize the delta
  while delta > PI*2:
    delta -= PI*2
  while delta < -PI*2:
    delta += PI*2

  r = vec2(rX, rY);

  return ArcParams(
    s: s, rx: rX, rY: ry, rotation: xAngle, cx: cx, cy: cy,
    theta: theta, delta: delta
  )

proc commandsToPolygons*(commands: seq[PathCommand]): seq[seq[Vec2]] =
  ## Converts SVG-like commands to simpler polygon

  var start, at, to, ctr, ctr2: Vec2
  var prevCommand: PathCommandKind

  var polygon: seq[Vec2]

  proc drawLine(at, to: Vec2) =
    # Don't add any 0 length lines.
    if at - to != vec2(0, 0):
      # Don't double up points.
      if polygon.len == 0 or polygon[^1] != at:
        polygon.add(at)
      polygon.add(to)

  proc getCurvePoint(points: seq[Vec2], t: float32): Vec2 =
    if points.len == 1:
      return points[0]
    else:
      var newPoints = newSeq[Vec2](points.len - 1)
      for i in 0 ..< newPoints.len:
        newPoints[i] = points[i] * (1-t) + points[i + 1] * t
      return getCurvePoint(newPoints, t)

  proc drawCurve(points: seq[Vec2]) =
    let n = 10
    var a = at
    for t in 1..n:
      var b = getCurvePoint(points, float32(t) / float32(n))
      drawLine(a, b)
      a = b

  proc drawQuad(p0, p1, p2: Vec2) =
    let devx = p0.x - 2.0 * p1.x + p2.x
    let devy = p0.y - 2.0 * p1.y + p2.y
    let devsq = devx * devx + devy * devy
    if devsq < 0.333:
      drawLine(p0, p2)
      return
    let tol = 3.0
    let n = 1 + (tol * (devsq)).sqrt().sqrt().floor()
    var p = p0
    let nrecip = 1 / n
    var t = 0.0
    for i in 0 ..< int(n):
      t += nrecip
      let pn = lerp(lerp(p0, p1, t), lerp(p1, p2, t), t)
      drawLine(p, pn)
      p = pn

    drawLine(p, p2)

  for command in commands:
    case command.kind
      of Move:
        assert command.numbers.len == 2
        at.x = command.numbers[0]
        at.y = command.numbers[1]
        start = at

      of Line:
        assert command.numbers.len == 2
        to.x = command.numbers[0]
        to.y = command.numbers[1]
        drawLine(at, to)
        at = to

      of VLine:
        assert command.numbers.len == 1
        to.x = at.x
        to.y = command.numbers[0]
        drawLine(at, to)
        at = to

      of HLine:
        assert command.numbers.len == 1
        to.x = command.numbers[0]
        to.y = at.y
        drawLine(at, to)
        at = to

      of Quad:
        assert command.numbers.len mod 4 == 0
        var i = 0
        while i < command.numbers.len:
          ctr.x = command.numbers[i+0]
          ctr.y = command.numbers[i+1]
          to.x = command.numbers[i+2]
          to.y = command.numbers[i+3]

          drawQuad(at, ctr, to)
          at = to
          i += 4

      of TQuad:
        if prevCommand != Quad and prevCommand != TQuad:
          ctr = at
        assert command.numbers.len == 2
        to.x = command.numbers[0]
        to.y = command.numbers[1]
        ctr = at - (ctr - at)
        drawQuad(at, ctr, to)
        at = to

      of Cubic:
        assert command.numbers.len == 6
        ctr.x = command.numbers[0]
        ctr.y = command.numbers[1]
        ctr2.x = command.numbers[2]
        ctr2.y = command.numbers[3]
        to.x = command.numbers[4]
        to.y = command.numbers[5]
        drawCurve(@[at, ctr, ctr2, to])
        at = to

      of Arc:
        var arc = endpointToCenterArcParams(
          at.x,
          at.y,
          command.numbers[0],
          command.numbers[1],
          command.numbers[2],
          command.numbers[3],
          command.numbers[4],
          command.numbers[5],
          command.numbers[6],
        )
        let steps = int(abs(arc.delta)/PI*180/5)
        let step = arc.delta / steps.float32
        var a = arc.theta
        var rotMat = rotationMat3(arc.rotation)
        for i in 0 .. steps:
          # polygon.add(polygon[^1])
          polygon.add(rotMat * vec2(
            cos(a)*arc.rx,
            sin(a)*arc.ry) + vec2(arc.cx, arc.cy)
          )
          a += step
        at = polygon[^1]

      of End:
        assert command.numbers.len == 0
        if at != start:
          if prevCommand == Quad or prevCommand == TQuad:
              drawQuad(at, ctr, start)
          else:
            drawLine(at, start)
        if polygon.len > 0:
          result.add(polygon)
        polygon = newSeq[Vec2]()
        at = start

      of RMove:
        assert command.numbers.len == 2
        at.x += command.numbers[0]
        at.y += command.numbers[1]
        start = at

      of RLine:
        assert command.numbers.len == 2
        to.x = at.x + command.numbers[0]
        to.y = at.y + command.numbers[1]
        drawLine(at, to)
        at = to

      of RVLine:
        assert command.numbers.len == 1
        to.x = at.x
        to.y = at.y + command.numbers[0]
        drawLine(at, to)
        at = to

      of RHLine:
        assert command.numbers.len == 1
        to.x = at.x + command.numbers[0]
        to.y = at.y
        drawLine(at, to)
        at = to

      of RQuad:
        assert command.numbers.len == 4
        ctr.x = at.x + command.numbers[0]
        ctr.y = at.y + command.numbers[1]
        to.x = at.x + command.numbers[2]
        to.y = at.y + command.numbers[3]
        drawQuad(at, ctr, to)
        at = to

      of RTQuad:
        if prevCommand != RQuad and prevCommand != RTQuad:
          ctr = at
        assert command.numbers.len == 2
        to.x = at.x + command.numbers[0]
        to.y = at.y + command.numbers[1]
        ctr = at - (ctr - at)
        drawQuad(at, ctr, to)
        at = to

      of RCubic:
        assert command.numbers.len == 6
        ctr.x = at.x + command.numbers[0]
        ctr.y = at.y + command.numbers[1]
        ctr2.x = at.x + command.numbers[2]
        ctr2.y = at.y + command.numbers[3]
        to.x = at.x + command.numbers[4]
        to.y = at.y + command.numbers[5]
        drawCurve(@[at, ctr, ctr2, to])
        at = to

      of RSCurve:
        assert command.numbers.len == 4
        ctr = at
        ctr2.x = at.x + command.numbers[0]
        ctr2.y = at.y + command.numbers[1]
        to.x = at.x + command.numbers[2]
        to.y = at.y + command.numbers[3]
        drawCurve(@[at, ctr, ctr2, to])
        at = to

      else:
       raise newException(ValueError, "not supported path command " & $command)

    prevCommand = command.kind

  if polygon.len > 0:
    result.add(polygon)

iterator zipline*[T](s: seq[T]): (T, T) =
  ## Return elements in pairs: (1st, 2nd), (2nd, 3rd) ... (nth, last).
  for i in 0 ..< s.len - 1:
    yield(s[i], s[i + 1])

iterator zipwise*[T](s: seq[T]): (T, T) =
  ## Return elements in pairs: (1st, 2nd), (2nd, 3rd) ... (last, 1st).
  for i in 0 ..< s.len - 1:
    yield(s[i], s[i + 1])
  if s.len > 0:
    yield(s[^1], s[0])

proc strokePolygons*(ps: seq[seq[Vec2]], strokeWidthR, strokeWidthL: float32): seq[seq[Vec2]] =
  ## Converts simple polygons into stroked versions:
  # TODO: Stroke location, add caps and joins.
  for p in ps:
    var poly: seq[Vec2]
    var back: seq[Vec2] # Back side of poly.
    var prevRSeg: Segment
    var prevLSeg: Segment
    var first = true
    for (at, to) in p.zipline:
      #echo at, ":", to
      let tangent = (at - to).normalize()
      let normal = vec2(-tangent.y, tangent.x)
      #print tangent, normal

      var
        rSeg = segment(at + normal * strokeWidthR, to + normal * strokeWidthR)
        lSeg = segment(at - normal * strokeWidthL, to - normal * strokeWidthL)

      if first:
        first = false
        # TODO: draw start cap
      else:
        # as previous lines
        var touch: Vec2
        if intersects(prevRSeg, rSeg, touch):
          rSeg.at = touch
          poly.setLen(poly.len - 1)
        else:
          discard # TODO: draw joint

        if intersects(prevLSeg, lSeg, touch):
          lSeg.at = touch
          back.setLen(back.len - 1)
        else:
          discard # TODO: draw joint

      poly.add rSeg.at
      back.add lSeg.at
      poly.add rSeg.to
      back.add lSeg.to

      prevRSeg = rSeg
      prevLSeg = lSeg

    # Add the backside reversed:
    for i in 1 .. back.len:
      poly.add back[^i]

    # TODO: draw end cap
    # Cap it at the end:
    poly.add poly[0]

    result.add(poly)


{.push checks: off, stacktrace: off.}

proc fillPolygons*(
    image: Image,
    polys: seq[seq[Vec2]],
    color: ColorRGBA,
    quality = 4,
  ): Image =
  const ep = 0.0001 * PI

  result = newImage(image.width, image.height)

  proc scanLineHits(
    polys: seq[seq[Vec2]],
    hits: var seq[(float32, bool)],
    y: int,
    shiftY: float32
  ) =
    hits.setLen(0)
    var yLine = (float32(y) + ep) + shiftY
    var scan = Segment(at: vec2(-10000, yLine), to: vec2(100000, yLine))

    for poly in polys:
      for (at, to) in poly.zipwise:
        let line = Segment(at: at, to: to)
        var at: Vec2
        if line.intersects(scan, at):
          let winding = line.at.y > line.to.y
          let x = at.x.clamp(0, image.width.float32)
          hits.add((x, winding))

    hits.sort(proc(a, b: (float32, bool)): int = cmp(a[0], b[0]))

  var hits: seq[(float32, bool)]

  var alphas = newSeq[float32](result.width)
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      alphas[x] = 0
    for m in 0 ..< quality:
      polys.scanLineHits(hits, y, float32(m)/float32(quality))
      if hits.len == 0:
        continue
      var
        penFill = 0.0
        curHit = 0
      for x in 0 ..< result.width:
        var penEdge = penFill
        while true:
          if curHit >= hits.len:
            break
          if x != hits[curHit][0].int:
            break
          let cover = hits[curHit][0] - x.float32
          let winding = hits[curHit][1]
          if winding == false:
            penFill += 1.0
            penEdge += 1.0 - cover
          else:
            penFill -= 1.0
            penEdge -= 1.0 - cover
          inc curHit
        alphas[x] += penEdge
    for x in 0 ..< result.width:
      var a = clamp(abs(alphas[x]) / float32(quality), 0.0, 1.0)
      var colorWithAlpha = color
      colorWithAlpha.a = uint8(clamp(a, 0, 1) * 255.0)
      result[x, y] = colorWithAlpha

{.pop.}

proc fillPath*(
    image: Image,
    path: Path,
    color: ColorRGBA
  ): Image =
  let polys = commandsToPolygons(path.commands)
  image.fillPolygons(polys, color)

proc fillPath*(
    image: Image,
    path: string,
    color: ColorRGBA
  ): Image =
  image.fillPath(parsePath(path), color)

proc fillPath*(
    image: Image,
    path: string,
    color: ColorRGBA,
    pos: Vec2
  ): Image =
  var polys = commandsToPolygons(parsePath(path).commands)
  for poly in polys.mitems:
    for i, p in poly.mpairs:
      poly[i] = p + pos
  image.fillPolygons(polys, color)

proc fillPath*(
    image: Image,
    path: Path,
    color: ColorRGBA,
    mat: Mat3
  ): Image =
  var polys = commandsToPolygons(path.commands)
  for poly in polys.mitems:
    for i, p in poly.mpairs:
      poly[i] = mat * p
  image.fillPolygons(polys, color)

proc fillPath*(
    image: Image,
    path: string,
    color: ColorRGBA,
    mat: Mat3
  ): Image =
  image.fillPath(parsePath(path), color, mat)

proc strokePath*(
    image: Image,
    path: Path,
    color: ColorRGBA,
    strokeWidth: float32,
    # strokeLocation: StrokeLocation,
    # strokeCap: StorkeCap,
    # strokeJoin: StorkeJoin
  ): Image =
  let polys = commandsToPolygons(path.commands)
  let (strokeL, strokeR) = (strokeWidth/2, strokeWidth/2)
  let polys2 = strokePolygons(polys, strokeL, strokeR)
  image.fillPolygons(polys2, color)

proc strokePath*(
    image: Image,
    path: string,
    color: ColorRGBA,
    strokeWidth: float32
  ): Image =
  image.strokePath(parsePath(path), color, strokeWidth)

proc strokePath*(
    image: Image,
    path: string,
    color: ColorRGBA,
    strokeWidth: float32,
    pos: Vec2
  ): Image =
  var polys = commandsToPolygons(parsePath(path).commands)
  let (strokeL, strokeR) = (strokeWidth/2, strokeWidth/2)
  var polys2 = strokePolygons(polys, strokeL, strokeR)
  for poly in polys2.mitems:
    for i, p in poly.mpairs:
      poly[i] = p + pos
  image.fillPolygons(polys2, color)

proc strokePath*(
    image: Image,
    path: string,
    color: ColorRGBA,
    strokeWidth: float32,
    mat: Mat3
  ): Image =
  var polys = commandsToPolygons(parsePath(path).commands)
  let (strokeL, strokeR) = (strokeWidth/2, strokeWidth/2)
  var polys2 = strokePolygons(polys, strokeL, strokeR)
  for poly in polys2.mitems:
    for i, p in poly.mpairs:
      poly[i] = mat * p
  image.fillPolygons(polys2, color)

proc addPath*(path: Path, other: Path) =
  ## Adds a path to the current path.
  path.commands &= other.commands

proc closePath*(path: Path) =
  ## Causes the point of the pen to move back to the start of the current sub-path. It tries to draw a straight line from the current point to the start. If the shape has already been closed or has only one point, this function does nothing.
  path.commands.add PathCommand(kind: End)

proc moveTo*(path: Path, x, y: float32) =
  ## Moves the starting point of a new sub-path to the (x, y) coordinates.
  path.commands.add PathCommand(kind: Move, numbers: @[x, y])
  path.at = vec2(x, y)

proc lineTo*(path: Path, x, y: float32) =
  ## Connects the last point in the subpath to the (x, y) coordinates with a straight line.
  path.commands.add PathCommand(kind: Line, numbers: @[x, y])
  path.at = vec2(x, y)

proc bezierCurveTo*(path: Path) =
  ## Adds a cubic Bézier curve to the path. It requires three points. The first two points are control points and the third one is the end point. The starting point is the last point in the current path, which can be changed using moveTo() before creating the Bézier curve.
  raise newException(ValueError, "not implemented")

proc quadraticCurveTo*(path: Path) =
  ## Adds a quadratic Bézier curve to the current path.
  raise newException(ValueError, "not implemented")

proc arc*(path: Path) =
  ## Adds an arc to the path which is centered at (x, y) position with radius r starting at startAngle and ending at endAngle going in the given direction by anticlockwise (defaulting to clockwise).
  raise newException(ValueError, "not implemented")

proc arcTo*(path: Path, x1, y1, x2, y2, r: float32) =
  ## Adds a circular arc to the path with the given control points and radius, connected to the previous point by a straight line.

  var
    x0 = path.at.x
    y0 = path.at.y
    x21 = x2 - x1
    y21 = y2 - y1
    x01 = x0 - x1
    y01 = y0 - y1
    l01_2 = x01 * x01 + y01 * y01

  const epsilon: float32 = 1e-6

  # if x1 != path.at.x or y1 != path.at.y:
  #   path.commands.add(PathCommand(kind: Line, numbers: @[x1, y1]))
  #   path.at.x = x1
  #   path.at.y = y1
  var r = r
  if r < 0:
    # Is the radius negative? Error.
    r = -r
    #raise newException(ValueError, "negative radius: " & $r)

  if path.commands.len == 0:
    # Is this path empty? Move to (x1,y1).
    path.commands.add(PathCommand(kind: Move, numbers: @[x1,y1]))

  elif not (l01_2 > epsilon):
    # Or, is (x1,y1) coincident with (x0,y0)? Do nothing.
    discard

  elif not (abs(y01 * x21 - y21 * x01) > epsilon) or r == 0:
    # // Or, are (x0,y0), (x1,y1) and (x2,y2) collinear?
    # // Equivalently, is (x1,y1) coincident with (x2,y2)?
    # // Or, is the radius zero? Line to (x1,y1).

    #this._ += "L" + (this._x1 = x1) + "," + (this._y1 = y1);
    path.commands.add(PathCommand(kind: Line, numbers: @[x1, y1]))
    path.at.x = x1
    path.at.y = y1

  else:
    # Otherwise, draw an arc!
    var
      x20 = x2 - x0
      y20 = y2 - y0
      l21_2 = x21 * x21 + y21 * y21
      l20_2 = x20 * x20 + y20 * y20
      l21 = sqrt(l21_2)
      l01 = sqrt(l01_2)
      l:float32 = r * tan((PI - arccos((l21_2 + l01_2 - l20_2) / (2 * l21 * l01))) / 2)
      t01 = l / l01
      t21 = l / l21

    # If the start tangent is not coincident with (x0,y0), line to.
    if abs(t01 - 1) > epsilon:
      #this._ += "L" + (x1 + t01 * x01) + "," + (y1 + t01 * y01)
      path.commands.add(PathCommand(kind: Line, numbers: @[x1 + t01 * x01, y1 + t01 * y01]))
      discard

    # this._ += "A" + r + "," + r + ",0,0," + (+(y01 * x20 > x01 * y20)) + "," + (this._x1 = x1 + t21 * x21) + "," + (this._y1 = y1 + t21 * y21);

    path.at.x = x1 + t21 * x21
    path.at.y = y1 + t21 * y21
    path.commands.add(PathCommand(
      kind: Arc,
      numbers: @[
        r,
        r,
        0,
        0,
        if y01 * x20 > x01 * y20: 1 else: 0,
        path.at.x,
        path.at.y
      ]
    ))

proc ellipse*(path: Path) =
  ## Adds an elliptical arc to the path which is centered at (x, y) position with the radii radiusX and radiusY starting at startAngle and ending at endAngle going in the given direction by anticlockwise (defaulting to clockwise).
  raise newException(ValueError, "not implemented")

proc rect*(path: Path, x, y, w, h: float32) =
  ## Creates a path for a rectangle at position (x, y) with a size that is determined by width and height.
  path.moveTo(x, y)
  path.lineTo(x+w, y)
  path.lineTo(x+w, y+h)
  path.lineTo(x,   y+h)
  path.lineTo(x,   y)
  path.closePath()
