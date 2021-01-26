import common, strutils, vmath, images, chroma, bumpy, blends

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

type
  WindingRule* = enum
    wrNonZero
    wrEvenOdd

  PathCommandKind* = enum
    ## Type of path commands
    Close,
    Move, Line, HLine, VLine, Cubic, SCubic, Quad, TQuad, Arc,
    RMove, RLine, RHLine, RVLine, RCubic, RSCubic, RQuad, RTQuad, RArc

  PathCommand* = object
    ## Binary version of an SVG command
    kind*: PathCommandKind
    numbers*: seq[float32]

  Path* = object
    commands*: seq[PathCommand]
    start, at: Vec2 # Maintained by moveTo, lineTo, etc. Used by arcTo.

  SomePath* = Path | string | seq[seq[Vec2]]

when defined(release):
  {.push checks: off.}

proc parameterCount(kind: PathCommandKind): int =
  case kind:
  of Close: 0
  of Move, Line, RMove, RLine, TQuad, RTQuad: 2
  of HLine, VLine, RHLine, RVLine: 1
  of Cubic, RCubic: 6
  of SCubic, RSCubic, Quad, RQuad: 4
  of Arc, RArc: 7

proc parsePath*(path: string): Path =
  ## Converts a SVG style path into seq of commands.

  if path.len == 0:
    return

  var
    p, numberStart: int
    armed: bool
    kind: PathCommandKind
    numbers: seq[float32]

  proc finishNumber() =
    if numberStart > 0:
      try:
        numbers.add(parseFloat(path[numberStart ..< p]))
      except ValueError:
        raise newException(PixieError, "Invalid path, parsing paramter failed")
    numberStart = 0

  proc finishCommand(result: var Path) =
    finishNumber()

    if armed: # The first finishCommand() arms
      let paramCount = parameterCount(kind)
      if paramCount == 0:
        if numbers.len != 0:
          raise newException(PixieError, "Invalid path, unexpected paramters")
        result.commands.add(PathCommand(kind: kind))
      else:
        if numbers.len mod paramCount != 0:
          raise newException(
            PixieError,
            "Invalid path, wrong number of parameters"
          )
        for batch in 0 ..< numbers.len div paramCount:
          result.commands.add(PathCommand(
            kind: kind,
            numbers: numbers[batch * paramCount ..< (batch + 1) * paramCount]
          ))
        numbers.setLen(0)

    armed = true

  while p < path.len:
    case path[p]:
    # Relative
    of 'm':
      finishCommand(result)
      kind = RMove
    of 'l':
      finishCommand(result)
      kind = RLine
    of 'h':
      finishCommand(result)
      kind = RHLine
    of 'v':
      finishCommand(result)
      kind = RVLine
    of 'c':
      finishCommand(result)
      kind = RCubic
    of 's':
      finishCommand(result)
      kind = RSCubic
    of 'q':
      finishCommand(result)
      kind = RQuad
    of 't':
      finishCommand(result)
      kind = RTQuad
    of 'a':
      finishCommand(result)
      kind = RArc
    of 'z':
      finishCommand(result)
      kind = Close
    # Absolute
    of 'M':
      finishCommand(result)
      kind = Move
    of 'L':
      finishCommand(result)
      kind = Line
    of 'H':
      finishCommand(result)
      kind = HLine
    of 'V':
      finishCommand(result)
      kind = VLine
    of 'C':
      finishCommand(result)
      kind = Cubic
    of 'S':
      finishCommand(result)
      kind = SCubic
    of 'Q':
      finishCommand(result)
      kind = Quad
    of 'T':
      finishCommand(result)
      kind = TQuad
    of 'A':
      finishCommand(result)
      kind = Arc
    of 'Z':
      finishCommand(result)
      kind = Close
    of '-', '+':
      if numberStart > 0 and path[p - 1] in {'e', 'E'}:
        discard
      else:
        finishNumber()
        numberStart = p
    of ' ', ',', '\r', '\n', '\t':
      finishNumber()
    else:
      if numberStart == 0:
        numberStart = p

    inc p

  finishCommand(result)

proc `$`*(path: Path): string =
  for i, command in path.commands:
    case command.kind
    of Move: result.add "M"
    of Line: result.add "L"
    of HLine: result.add "H"
    of VLine: result.add "V"
    of Cubic: result.add "C"
    of SCubic: result.add "S"
    of Quad: result.add "Q"
    of TQuad: result.add "T"
    of Arc: result.add "A"
    of RMove: result.add "m"
    of RLine: result.add "l"
    of RHLine: result.add "h"
    of RVLine: result.add "v"
    of RCubic: result.add "c"
    of RSCubic: result.add "s"
    of RQuad: result.add "q"
    of RTQuad: result.add "t"
    of RArc: result.add "a"
    of Close: result.add "Z"
    for j, number in command.numbers:
      if floor(number) == number:
        result.add $number.int
      else:
        result.add $number
      if i != path.commands.len - 1 or j != command.numbers.len - 1:
        result.add " "

proc transform*(path: var Path, mat: Mat3) =
  for command in path.commands.mitems:
    case command.kind:
    of Close:
      discard
    of Move, Line, RMove, RLine, TQuad, RTQuad:
      var pos = vec2(command.numbers[0], command.numbers[1])
      pos = mat * pos
      command.numbers[0] = pos.x
      command.numbers[1] = pos.y
    of HLine, RHLine:
      var pos = vec2(command.numbers[0], 0)
      pos = mat * pos
      command.numbers[0] = pos.x
    of VLine, RVLine:
      var pos = vec2(0, command.numbers[0])
      pos = mat * pos
      command.numbers[0] = pos.y
    of Cubic, RCubic:
      var
        ctrl1 = vec2(command.numbers[0], command.numbers[1])
        ctrl2 = vec2(command.numbers[2], command.numbers[3])
        to = vec2(command.numbers[4], command.numbers[5])
      ctrl1 = mat * ctrl1
      ctrl2 = mat * ctrl2
      to = mat * to
      command.numbers[0] = ctrl1.x
      command.numbers[1] = ctrl1.y
      command.numbers[2] = ctrl2.x
      command.numbers[3] = ctrl2.y
      command.numbers[4] = to.x
      command.numbers[5] = to.y
    of SCubic, RSCubic, Quad, RQuad:
      var
        ctrl = vec2(command.numbers[0], command.numbers[1])
        to = vec2(command.numbers[2], command.numbers[3])
      ctrl = mat * ctrl
      to = mat * to
      command.numbers[0] = ctrl.x
      command.numbers[1] = ctrl.y
      command.numbers[2] = to.x
      command.numbers[3] = to.y
    of Arc, RArc:
      var
        radii = vec2(command.numbers[0], command.numbers[1])
        to = vec2(command.numbers[5], command.numbers[6])
      # Extract the scale from the matrix and only apply that to the radii
      radii = scale(vec2(mat[0, 0], mat[1, 1])) * radii
      to = mat * to
      command.numbers[0] = radii.x
      command.numbers[1] = radii.y
      command.numbers[5] = to.x
      command.numbers[6] = to.y

proc addPath*(path: var Path, other: Path) =
  ## Adds a path to the current path.
  path.commands.add(other.commands)

proc closePath*(path: var Path) =
  path.commands.add(PathCommand(kind: Close))
  path.at = path.start

proc moveTo*(path: var Path, x, y: float32) =
  path.commands.add(PathCommand(kind: Move, numbers: @[x, y]))
  path.start = vec2(x, y)
  path.at = path.start

proc moveTo*(path: var Path, v: Vec2) {.inline.} =
  path.moveTo(v.x, v.y)

proc lineTo*(path: var Path, x, y: float32) =
  path.commands.add(PathCommand(kind: Line, numbers: @[x, y]))
  path.at = vec2(x, y)

proc lineTo*(path: var Path, v: Vec2) {.inline.} =
  path.lineTo(v.x, v.y)

proc bezierCurveTo*(path: var Path, x1, y1, x2, y2, x3, y3: float32) =
  ## Adds a cubic Bézier curve to the path. This requires three points.
  ## The first two points are control points and the third is the end point.
  ## The starting point is the last point in the current path, which can be
  ## changed using moveTo() before creating the curve.
  path.commands.add(PathCommand(
    kind: Cubic,
    numbers: @[x1, y1, x2, y2, x3, y3]
  ))
  path.at = vec2(x3, y3)

proc bezierCurveTo*(path: var Path, ctrl1, ctrl2, to: Vec2) {.inline.} =
  path.bezierCurveTo(ctrl1.x, ctrl1.y, ctrl2.x, ctrl2.y, to.x, to.y)

proc quadraticCurveTo*(path: var Path, x1, y1, x2, y2: float32) =
  ## Adds a quadratic Bézier curve to the path. This requires 2 points.
  ## The first point is the control point and the second is the end point.
  ## The starting point is the last point in the current path, which can be
  ## changed using moveTo() before creating the curve.
  path.commands.add(PathCommand(
    kind: Quad,
    numbers: @[x1, y1, x2, y2]
  ))
  path.at = vec2(x2, y2)

proc quadraticCurveTo*(path: var Path, ctrl, to: Vec2) {.inline.} =
  path.quadraticCurveTo(ctrl.x, ctrl.y, to.x, to.y)

proc arcTo*(path: var Path, ctrl1, ctrl2: Vec2, radius: float32) {.inline.} =
  ## Adds a circular arc to the current sub-path, using the given control
  ## points and radius.

  const epsilon = 1e-6.float32

  var radius = radius
  if radius < 0:
    radius = -radius

  if path.commands.len == 0:
    path.moveTo(ctrl1)

  let
    a = path.at - ctrl1
    b = ctrl2 - ctrl1

  if a.lengthSq() < epsilon:
    # If the control point is coincident with at, do nothing
    discard
  elif abs(a.y * b.x - a.x * b.y) < epsilon or radius == 0:
    # If ctrl1, a and b are colinear or coincident or radius is zero
    path.lineTo(ctrl1)
  else:
    let
      c = ctrl2 - path.at
      als = a.lengthSq()
      bls = b.lengthSq()
      cls = c.lengthSq()
      al = a.length()
      bl = b.length()
      l = radius * tan((PI - arccos((als + bls - cls) / 2 * al * bl)) / 2)
      ta = l / al
      tb = l / bl

    if abs(ta - 1) > epsilon:
      # If the start tangent is not coincident with path.at
      path.lineTo(ctrl1 + a * ta)

    let to = ctrl1 + b * tb
    path.commands.add(PathCommand(
      kind: Arc,
      numbers: @[
        radius,
        radius,
        0,
        0,
        if a.y * c.x > a.x * c.y: 1 else: 0,
        to.x,
        to.y
      ]
    ))
    path.at = to

proc arcTo*(path: var Path, x1, y1, x2, y2, radius: float32) =
  path.arcTo(vec2(x1, y1), vec2(x2, y2), radius)

proc rect*(path: var Path, x, y, w, h: float32) =
  path.moveTo(x, y)
  path.lineTo(x + w, y)
  path.lineTo(x + w, y + h)
  path.lineTo(x, y + h)
  path.closePath()

proc polygon*(path: var Path, x, y, size: float32, sides: int) =
  ## Draws a n sided regular polygon at (x, y) with size.
  path.moveTo(x + size * cos(0.0), y + size * sin(0.0))
  for side in 0 .. sides:
    path.lineTo(
      x + size * cos(side.float32 * 2.0 * PI / sides.float32),
      y + size * sin(side.float32 * 2.0 * PI / sides.float32)
    )

proc commandsToShapes*(path: Path): seq[seq[Vec2]] =
  ## Converts SVG-like commands to line segments.

  var
    start, at: Vec2
    shape: seq[Vec2]

  # Some commands use data from the previous command
  var
    prevCommandKind = Move
    prevCtrl, prevCtrl2: Vec2

  const errorMargin = 0.2

  proc addSegment(shape: var seq[Vec2], at, to: Vec2) =
    # Don't add any 0 length lines
    if at - to != vec2(0, 0):
      # Don't double up points
      if shape.len == 0 or shape[^1] != at:
        shape.add(at)
      shape.add(to)

  proc addCubic(shape: var seq[Vec2], at, ctrl1, ctrl2, to: Vec2) =

    proc compute(at, ctrl1, ctrl2, to: Vec2, t: float32): Vec2 {.inline.} =
      pow(1 - t, 3) * at +
      pow(1 - t, 2) * 3 * t * ctrl1 +
      (1 - t) * 3 * pow(t, 2) * ctrl2 +
      pow(t, 3) * to

    var prev = at

    proc discretize(shape: var seq[Vec2], i, steps: int) =
      # Closure captures at, ctrl1, ctrl2, to and prev
      let
        tPrev = (i - 1).float32 / steps.float32
        t = i.float32 / steps.float32
        next = compute(at, ctrl1, ctrl2, to, t)
        halfway = compute(at, ctrl1, ctrl2, to, tPrev + (t - tPrev) / 2)
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).length

      if error >= errorMargin:
        # Error too large, double precision for this step
        shape.discretize(i * 2 - 1, steps * 2)
        shape.discretize(i * 2, steps * 2)
      else:
        shape.addSegment(prev, next)
        prev = next

    shape.discretize(1, 1)

  proc addQuadratic(shape: var seq[Vec2], at, ctrl, to: Vec2) =

    proc compute(at, ctrl, to: Vec2, t: float32): Vec2 {.inline.} =
      pow(1 - t, 2) * at +
      2 * (1 - t) * t * ctrl +
      pow(t, 2) * to

    var prev = at

    proc discretize(shape: var seq[Vec2], i, steps: int) =
      # Closure captures at, ctrl, to and prev
      let
        tPrev = (i - 1).float32 / steps.float32
        t = i.float32 / steps.float32
        next = compute(at, ctrl, to, t)
        halfway = compute(at, ctrl, to, tPrev + (t - tPrev) / 2)
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).length

      if error >= errorMargin:
        # Error too large, double precision for this step
        shape.discretize(i * 2 - 1, steps * 2)
        shape.discretize(i * 2, steps * 2)
      else:
        shape.addSegment(prev, next)
        prev = next

    shape.discretize(1, 1)

  proc addArc(
    shape: var seq[Vec2],
    at, radii: Vec2,
    rotation: float32,
    large, sweep: bool,
    to: Vec2
  ) =
    type ArcParams = object
      radii: Vec2
      rotMat: Mat3
      center: Vec2
      theta, delta: float32

    proc endpointToCenterArcParams(
      at, radii: Vec2, rotation: float32, large, sweep: bool, to: Vec2
    ): ArcParams =
      var
        radii = vec2(abs(radii.x), abs(radii.y))
        radiiSq = vec2(radii.x * radii.x, radii.y * radii.y)

      let
        radians = rotation / 180 * PI
        d = vec2((at.x - to.x) / 2.0, (at.y - to.y) / 2.0)
        p = vec2(
          cos(radians) * d.x + sin(radians) * d.y,
          -sin(radians) * d.x + cos(radians) * d.y
        )
        pSq = vec2(p.x * p.x, p.y * p.y)

      let cr = pSq.x / radiiSq.x + pSq.y / radiiSq.y
      if cr > 1:
        radii *= sqrt(cr)
        radiiSq = vec2(radii.x * radii.x, radii.y * radii.y)

      let
        dq = radiiSq.x * pSq.y + radiiSq.y * pSq.x
        pq = (radiiSq.x * radiiSq.y - dq) / dq

      var q = sqrt(max(0, pq))
      if large == sweep:
          q = -q

      proc svgAngle(u, v: Vec2): float32 =
        let
          dot = dot(u,v)
          len = length(u) * length(v)
        result = arccos(clamp(dot / len, -1, 1))
        if (u.x * v.y - u.y * v.x) < 0:
            result = -result

      let
        cp = vec2(q * radii.x * p.y / radii.y, -q * radii.y * p.x / radii.x)
        center = vec2(
          cos(radians) * cp.x - sin(radians) * cp.y + (at.x + to.x) / 2,
          sin(radians) * cp.x + cos(radians) * cp.y + (at.y + to.y) / 2
        )
        theta = svgAngle(vec2(1, 0), vec2((p.x-cp.x) / radii.x, (p.y - cp.y) / radii.y))

      var delta = svgAngle(
          vec2((p.x - cp.x) / radii.x, (p.y - cp.y) / radii.y),
          vec2((-p.x - cp.x) / radii.x, (-p.y - cp.y) / radii.y)
        )
      delta = delta mod (PI * 2)

      if not sweep:
        delta -= 2 * PI

      # Normalize the delta
      while delta > PI * 2:
        delta -= PI * 2
      while delta < -PI * 2:
        delta += PI * 2

      ArcParams(
        radii: radii,
        rotMat: rotationMat3(-radians),
        center: center,
        theta: theta,
        delta: delta
      )

    proc compute(arc: ArcParams, a: float32): Vec2 =
      result = vec2(cos(a) * arc.radii.x, sin(a) * arc.radii.y)
      result = arc.rotMat * result + arc.center

    var prev = at

    proc discretize(shape: var seq[Vec2], arc: ArcParams, i, steps: int) =
      let
        step = arc.delta / steps.float32
        aPrev = arc.theta + step * (i - 1).float32
        a = arc.theta + step * i.float32
        next = arc.compute(a)
        halfway = arc.compute(aPrev + (a - aPrev) / 2)
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).length

      if error >= errorMargin:
        # Error too large, try again with doubled precision
        shape.discretize(arc, i * 2 - 1, steps * 2)
        shape.discretize(arc, i * 2, steps * 2)
      else:
        shape.addSegment(prev, next)
        prev = next

    let arc = endpointToCenterArcParams(at, radii, rotation, large, sweep, to)
    shape.discretize(arc, 1, 1)

  for command in path.commands:
    if command.numbers.len != command.kind.parameterCount():
      raise newException(PixieError, "Invalid path")

    case command.kind:
    of Move:
      at.x = command.numbers[0]
      at.y = command.numbers[1]
      start = at

    of Line:
      let to = vec2(command.numbers[0], command.numbers[1])
      shape.addSegment(at, to)
      at = to

    of HLine:
      let to = vec2(command.numbers[0], at.y)
      shape.addSegment(at, to)
      at = to

    of VLine:
      let to = vec2(at.x, command.numbers[0])
      shape.addSegment(at, to)
      at = to

    of Cubic:
      let
        ctrl1 = vec2(command.numbers[0], command.numbers[1])
        ctrl2 = vec2(command.numbers[2], command.numbers[3])
        to = vec2(command.numbers[4], command.numbers[5])
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of SCubic:
      let
        ctrl2 = vec2(command.numbers[0], command.numbers[1])
        to = vec2(command.numbers[2], command.numbers[3])
      if prevCommandKind in {Cubic, SCubic, RCubic, RSCubic}:
        let ctrl1 = 2 * at - prevCtrl2
        shape.addCubic(at, ctrl1, ctrl2, to)
      else:
        shape.addCubic(at, at, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of Quad:
      let
        ctrl = vec2(command.numbers[0], command.numbers[1])
        to = vec2(command.numbers[2], command.numbers[3])
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of TQuad:
      let
        to = vec2(command.numbers[0], command.numbers[1])
        ctrl =
          if prevCommandKind in {Quad, TQuad, RQuad, RTQuad}:
            2 * at - prevCtrl
          else:
            at
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of Arc:
      let
        radii = vec2(command.numbers[0], command.numbers[1])
        rotation = command.numbers[2]
        large = command.numbers[3] == 1
        sweep = command.numbers[4] == 1
        to = vec2(command.numbers[5], command.numbers[6])
      shape.addArc(at, radii, rotation, large, sweep, to)
      at = to

    of RMove:
      at.x += command.numbers[0]
      at.y += command.numbers[1]
      start = at

    of RLine:
      let to = vec2(at.x + command.numbers[0], at.y + command.numbers[1])
      shape.addSegment(at, to)
      at = to

    of RHLine:
      let to = vec2(at.x + command.numbers[0], at.y)
      shape.addSegment(at, to)
      at = to

    of RVLine:
      let to = vec2(at.x, at.y + command.numbers[0])
      shape.addSegment(at, to)
      at = to

    of RCubic:
      let
        ctrl1 = vec2(at.x + command.numbers[0], at.y + command.numbers[1])
        ctrl2 = vec2(at.x + command.numbers[2], at.y + command.numbers[3])
        to = vec2(at.x + command.numbers[4], at.y + command.numbers[5])
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of RSCubic:
      let
        ctrl2 = vec2(at.x + command.numbers[0], at.y + command.numbers[1])
        to = vec2(at.x + command.numbers[2], at.y + command.numbers[3])
        ctrl1 =
          if prevCommandKind in {Cubic, SCubic, RCubic, RSCubic}:
            2 * at - prevCtrl2
          else:
            at
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of RQuad:
      let
        ctrl = vec2(at.x + command.numbers[0], at.y + command.numbers[1])
        to = vec2(at.x + command.numbers[2], at.y + command.numbers[3])
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of RTQuad:
      let
        to = vec2(at.x + command.numbers[0], at.y + command.numbers[1])
        ctrl =
          if prevCommandKind in {Quad, TQuad, RQuad, RTQuad}:
            2 * at - prevCtrl
          else:
            at
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of RArc:
      let
        radii = vec2(command.numbers[0], command.numbers[1])
        rotation = command.numbers[2]
        large = command.numbers[3] == 1
        sweep = command.numbers[4] == 1
        to = vec2(at.x + command.numbers[5], at.y + command.numbers[6])
      shape.addArc(at, radii, rotation, large, sweep, to)
      at = to

    of Close:
      if at != start:
        shape.addSegment(at, start)
        at = start
      if shape.len > 0:
        result.add(shape)
        shape.setLen(0)

    prevCommandKind = command.kind

  if shape.len > 0:
    result.add(shape)

iterator segments*(s: seq[Vec2]): Segment =
  ## Return elements in pairs: (1st, 2nd), (2nd, 3rd) ... (n - 1, last).
  for i in 0 ..< s.len - 1:
    yield(segment(s[i], s[i + 1]))

proc quickSort(a: var seq[(float32, bool)], inl, inr: int) =
  var
    r = inr
    l = inl
  let n = r - l + 1
  if n < 2:
    return
  let p = a[l + 3 * n div 4][0]
  while l <= r:
    if a[l][0] < p:
      inc l
    elif a[r][0] > p:
      dec r
    else:
      swap(a[l], a[r])
      inc l
      dec r
  quickSort(a, inl, r)
  quickSort(a, l, inr)

proc computeBounds(shapes: seq[seq[(Segment, bool)]]): Rect =
  var
    xMin = float32.high
    xMax = float32.low
    yMin = float32.high
    yMax = float32.low
  for shape in shapes:
    for (segment, _) in shape:
      xMin = min(xMin, min(segment.at.x, segment.to.x))
      xMax = max(xMax, max(segment.at.x, segment.to.x))
      yMin = min(yMin, min(segment.at.y, segment.to.y))
      yMax = max(yMax, max(segment.at.y, segment.to.y))

  xMin = floor(xMin)
  xMax = ceil(xMax)
  yMin = floor(yMin)
  yMax = ceil(yMax)

  result.x = xMin
  result.y = yMin
  result.w = xMax - xMin
  result.h = yMax - yMin

proc fillShapes(
  image: Image,
  shapes: seq[seq[Vec2]],
  color: ColorRGBA,
  windingRule: WindingRule
) =
  var sortedShapes = newSeq[seq[(Segment, bool)]](shapes.len)
  for i, sorted in sortedShapes.mpairs:
    for segment in shapes[i].segments:
      if segment.at.y == segment.to.y: # Skip horizontal
        continue
      let winding = segment.at.y > segment.to.y
      if winding:
        var segment = segment
        swap(segment.at, segment.to)
        sorted.add((segment, winding))
      else:
        sorted.add((segment, winding))

  # Figure out the total bounds of all the shapes,
  # rasterize only within the total bounds
  let
    bounds = computeBounds(sortedShapes)
    startX = max(0, bounds.x.int)
    startY = max(0, bounds.y.int)
    stopY = min(image.height, (bounds.y + bounds.h).int)

  const
    quality = 5 # Must divide 255 cleanly
    sampleCoverage = 255.uint8 div quality
    ep = 0.0001 * PI
    offset = 1 / quality.float32
    initialOffset = offset / 2

  var
    hits = newSeq[(float32, bool)](4)
    coverages = newSeq[uint8](image.width)
    numHits: int

  for y in startY ..< stopY:
    # Reset buffer for this row
    zeroMem(coverages[0].addr, coverages.len)

    # Do scanlines for this row
    for m in 0 ..< quality:
      let
        yLine = y.float32 + initialOffset + offset * m.float32 + ep
        scanline = Line(a: vec2(0, yLine), b: vec2(1000, yLine))
      numHits = 0
      for i, shape in sortedShapes:
        for (segment, winding) in shape:
          if segment.at.y > yLine or segment.to.y < y.float32:
            continue
          var at: Vec2
          if scanline.intersects(segment, at):# and segment.to != at:
            if numHits == hits.len:
              hits.setLen(hits.len * 2)
            hits[numHits] = (at.x.clamp(0, image.width.float32), winding)
            inc numHits

      quickSort(hits, 0, numHits - 1)

      proc shouldFill(windingRule: WindingRule, count: int): bool {.inline.} =
        case windingRule:
        of wrNonZero:
          count != 0
        of wrEvenOdd:
          count mod 2 != 0

      var
        x: float32
        count: int
      for i in 0 ..< numHits:
        let (at, winding) = hits[i]

        var
          fillStart = x.int
          leftCover = if at.int - x.int > 0: ceil(x) - x else: at - x
        if leftCover != 0:
          inc fillStart
          if shouldFill(windingRule, count):
            coverages[x.int] += (leftCover * sampleCoverage.float32).uint8

        if at.int - x.int > 0:
          let rightCover = at - trunc(at)
          if rightCover > 0 and shouldFill(windingRule, count):
            coverages[at.int] += (rightCover * sampleCoverage.float32).uint8

        let fillLen = at.int - fillStart
        if fillLen > 0 and shouldFill(windingRule, count):
          var i = fillStart
          when defined(amd64) and not defined(pixieNoSimd):
            let vSampleCoverage = mm_set1_epi8(cast[int8](sampleCoverage))
            for j in countup(i, fillStart + fillLen - 16, 16):
              let current = mm_loadu_si128(coverages[j].addr)
              mm_storeu_si128(
                coverages[j].addr,
                mm_add_epi8(current, vSampleCoverage)
              )
              i += 16
          for j in i ..< fillStart + fillLen:
            coverages[j] += sampleCoverage

        count += (if winding: -1 else: 1)
        x = at

    # Apply the coverage and blend
    var x = startX
    when defined(amd64) and not defined(pixieNoSimd):
      # When supported, SIMD blend as much as possible

      let
        coverageMask1 = cast[M128i]([0xffffffff, 0, 0, 0]) # First 32 bits
        coverageMask3 = mm_set1_epi32(cast[int32](0x000000ff)) # Only `r`
        oddMask = mm_set1_epi16(cast[int16](0xff00))
        div255 = mm_set1_epi16(cast[int16](0x8081))
        zero = mm_set1_epi32(0)
        v255 = mm_set1_epi32(255)
        vColor = mm_set1_epi32(cast[int32](color))

      for _ in countup(x, coverages.len - 16, 16):
        var coverage = mm_loadu_si128(coverages[x].addr)
        coverage = mm_and_si128(coverage, coverageMask1)

        if mm_movemask_epi8(mm_cmpeq_epi16(coverage, zero)) != 0xffff:
          # If the coverages are not all zero
          var source = vColor
          coverage = mm_slli_si128(coverage, 2)
          coverage = mm_shuffle_epi32(coverage, MM_SHUFFLE(1, 1, 0, 0))

          var
            a = mm_and_si128(coverage, coverageMask1)
            b = mm_and_si128(coverage, mm_slli_si128(coverageMask1, 4))
            c = mm_and_si128(coverage, mm_slli_si128(coverageMask1, 8))
            d = mm_and_si128(coverage, mm_slli_si128(coverageMask1, 12))

          # Shift the coverages to `r`
          a = mm_srli_si128(a, 2)
          b = mm_srli_si128(b, 3)
          d = mm_srli_si128(d, 1)

          coverage = mm_and_si128(
            mm_or_si128(mm_or_si128(a, b), mm_or_si128(c, d)),
            coverageMask3
          )

          if mm_movemask_epi8(mm_cmpeq_epi32(coverage, v255)) != 0xffff:
            # If the coverages are not all 255

            # Shift the coverages from `r` to `g` and `a` for multiplying later
            coverage = mm_or_si128(
              mm_slli_epi32(coverage, 8), mm_slli_epi32(coverage, 24)
            )

            var
              colorEven = mm_slli_epi16(source, 8)
              colorOdd = mm_and_si128(source, oddMask)

            colorEven = mm_mulhi_epu16(colorEven, coverage)
            colorOdd = mm_mulhi_epu16(colorOdd, coverage)

            colorEven = mm_srli_epi16(mm_mulhi_epu16(colorEven, div255), 7)
            colorOdd = mm_srli_epi16(mm_mulhi_epu16(colorOdd, div255), 7)

            source = mm_or_si128(colorEven, mm_slli_epi16(colorOdd, 8))

          let
            index = image.dataIndex(x, y)
            backdrop = mm_loadu_si128(image.data[index].addr)
          mm_storeu_si128(
            image.data[index].addr,
            blendNormalPremultiplied(backdrop, source)
          )

        x += 4

    while x < image.width:
      if x + 8 <= coverages.len:
        let peeked = cast[ptr uint64](coverages[x].addr)[]
        if peeked == 0:
          x += 8
          continue

      let coverage = coverages[x]
      if coverage != 0:
        var source = color
        if coverage != 255:
          source.r = ((color.r.uint16 * coverage) div 255).uint8
          source.g = ((color.g.uint16 * coverage) div 255).uint8
          source.b = ((color.b.uint16 * coverage) div 255).uint8
          source.a = ((color.a.uint16 * coverage) div 255).uint8

        let backdrop = image.getRgbaUnsafe(x, y)
        image.setRgbaUnsafe(x, y, blendNormalPremultiplied(backdrop, source))
      inc x

proc parseSomePath(path: SomePath): seq[seq[Vec2]] {.inline.} =
  when type(path) is string:
    parsePath(path).commandsToShapes()
  elif type(path) is Path:
    path.commandsToShapes()
  elif type(path) is seq[seq[Segment]]:
    path

proc fillPath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  windingRule = wrNonZero
) {.inline.} =
  image.fillShapes(parseSomePath(path), color, windingRule)

proc fillPath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  pos: Vec2,
  windingRule = wrNonZero
) =
  var shapes = parseSomePath(path)
  for shape in shapes.mitems:
    for segment in shape.mitems:
      segment += pos
  image.fillShapes(shapes, color, windingRule)

proc fillPath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  mat: Mat3,
  windingRule = wrNonZero
) =
  var shapes = parseSomePath(path)
  for shape in shapes.mitems:
    for segment in shape.mitems:
      segment = mat * segment
  image.fillShapes(shapes, color, windingRule)

proc strokeShapes(
  shapes: seq[seq[Vec2]],
  color: ColorRGBA,
  strokeWidth: float32,
  windingRule: WindingRule
): seq[seq[Vec2]] =
  if strokeWidth == 0:
    return

  let
    widthLeft = strokeWidth / 2
    widthRight = strokeWidth / 2

  for shape in shapes:
    var
      strokeShape: seq[Vec2]
      back: seq[Vec2]
    for segment in shape.segments:
      let
        tangent = (segment.at - segment.to).normalize()
        normal = vec2(-tangent.y, tangent.x)
        left = segment(
          segment.at - normal * widthLeft,
          segment.to - normal * widthLeft
        )
        right = segment(
          segment.at + normal * widthRight,
          segment.to + normal * widthRight
        )

      strokeShape.add([right.at, right.to])
      back.add([left.at, left.to])

    # Add the back side reversed
    for i in 1 .. back.len:
      strokeShape.add(back[^i])

    strokeShape.add(strokeShape[0])

    if strokeShape.len > 0:
      result.add(strokeShape)

proc strokePath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  strokeWidth = 1.0,
  windingRule = wrNonZero
) =
  let strokeShapes = strokeShapes(
    parseSomePath(path),
    color,
    strokeWidth,
    windingRule
  )
  image.fillShapes(strokeShapes, color, windingRule)

proc strokePath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  strokeWidth = 1.0,
  pos: Vec2,
  windingRule = wrNonZero
) =
  var strokeShapes = strokeShapes(
    parseSomePath(path),
    color,
    strokeWidth,
    windingRule
  )
  for shape in strokeShapes.mitems:
    for segment in shape.mitems:
      segment += pos
  image.fillShapes(strokeShapes, color, windingRule)

proc strokePath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  strokeWidth = 1.0,
  mat: Mat3,
  windingRule = wrNonZero
) =
  var strokeShapes = strokeShapes(
    parseSomePath(path),
    color,
    strokeWidth,
    windingRule
  )
  for shape in strokeShapes.mitems:
    for segment in shape.mitems:
      segment = mat * segment
  image.fillShapes(strokeShapes, color, windingRule)

when defined(release):
  {.pop.}
