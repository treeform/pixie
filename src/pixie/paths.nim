import vmath, images, chroma, strutils, algorithm, common, bumpy, blends

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

proc parameterCount(kind: PathCommandKind): int =
  case kind:
  of Close: 0
  of Move, Line, RMove, RLine: 2
  of HLine, VLine, RHLine, RVLine: 1
  of Cubic, RCubic: 6
  of SCubic, RSCubic, Quad, RQuad: 4
  of TQuad, RTQuad: 2
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

proc commandsToShapes*(path: Path): seq[seq[Segment]] =
  ## Converts SVG-like commands to simpler polygon

  var
    start, at: Vec2
    shape: seq[Segment]

  # Some commands use data from the previous command
  var
    prevCommandKind = Move
    prevCtrl, prevCtrl2: Vec2

  const errorMargin = 0.2

  proc addCubic(shape: var seq[Segment], at, ctrl1, ctrl2, to: Vec2) =

    proc compute(at, ctrl1, ctrl2, to: Vec2, t: float32): Vec2 {.inline.} =
      pow(1 - t, 3) * at +
      pow(1 - t, 2) * 3 * t * ctrl1 +
      (1 - t) * 3 * pow(t, 2) * ctrl2 +
      pow(t, 3) * to

    var prev = at

    proc discretize(shape: var seq[Segment], i, steps: int) =
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
        shape.add(segment(prev, next))
        prev = next

    shape.discretize(1, 1)

  proc addQuadratic(shape: var seq[Segment], at, ctrl, to: Vec2) =

    proc compute(at, ctrl, to: Vec2, t: float32): Vec2 {.inline.} =
      pow(1 - t, 2) * at +
      2 * (1 - t) * t * ctrl +
      pow(t, 2) * to

    var prev = at

    proc discretize(shape: var seq[Segment], i, steps: int) =
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
        shape.add(segment(prev, next))
        prev = next

    shape.discretize(1, 1)

  proc addArc(
    shape: var seq[Segment],
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

    proc discretize(shape: var seq[Segment], arc: ArcParams, i, steps: int) =
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
        shape.add(segment(prev, next))
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
      shape.add(segment(at, to))
      at = to

    of HLine:
      let to = vec2(command.numbers[0], at.y)
      shape.add(segment(at, to))
      at = to

    of VLine:
      let to = vec2(at.x, command.numbers[0])
      shape.add(segment(at, to))
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
      shape.add(segment(at, to))
      at = to

    of RHLine:
      let to = vec2(at.x + command.numbers[0], at.y)
      shape.add(segment(at, to))
      at = to

    of RVLine:
      let to = vec2(at.x, at.y + command.numbers[0])
      shape.add(segment(at, to))
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
        shape.add(segment(at, start))
        at = start
      if shape.len > 0:
        result.add(shape)
        shape.setLen(0)

    prevCommandKind = command.kind

  if shape.len > 0:
    result.add(shape)

proc strokeShapes(
  shapes: seq[seq[Segment]],
  color: ColorRGBA,
  strokeWidth: float32,
  windingRule: WindingRule
): seq[seq[Segment]] =
  if strokeWidth == 0:
    return

  let
    widthLeft = strokeWidth / 2
    widthRight = strokeWidth / 2

  for shape in shapes:
    var
      points: seq[Vec2]
      back: seq[Vec2]
    for segment in shape:
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

      points.add([right.at, right.to])
      back.add([left.at, left.to])

    # Add the back side reversed
    for i in 1 .. back.len:
      points.add(back[^i])

    points.add(points[0])

    # Walk the points to create the shape
    var strokeShape: seq[Segment]
    for i in 0 ..< points.len - 1:
      strokeShape.add(segment(points[i], points[i + 1]))

    if strokeShape.len > 0:
      result.add(strokeShape)

proc computeBounds(shape: seq[Segment]): Rect =
  var
    xMin = float32.high
    xMax = float32.low
    yMin = float32.high
    yMax = float32.low
  for segment in shape:
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

{.push checks: off, stacktrace: off.}

proc fillShapes*(
  image: Image,
  shapes: seq[seq[Segment]],
  color: ColorRGBA,
  windingRule: WindingRule,
  quality = 4
) =
  var sortedShapes = newSeq[seq[(Segment, bool)]](shapes.len)
  for i, sorted in sortedShapes.mpairs:
    for j, segment in shapes[i]:
      if segment.at.y == segment.to.y or segment.at - segment.to == Vec2():
        # Skip horizontal and zero-length
        continue
      var
        segment = segment
        winding = segment.at.y > segment.to.y
      if winding:
        swap(segment.at, segment.to)
      sorted.add((segment, winding))

  # Compute the bounds of each shape
  var bounds = newSeq[Rect](shapes.len)
  for i, shape in shapes:
    bounds[i] = computeBounds(shape)

  const ep = 0.0001 * PI

  proc scanLineHits(
    shapes: seq[seq[(Segment, bool)]],
    bounds: seq[Rect],
    hits: var seq[(float32, bool)],
    size: Vec2,
    y: int,
    shiftY: float32
  ) {.inline.} =
    hits.setLen(0)

    let
      yLine = y.float32 + ep + shiftY
      scanline = Line(a: vec2(-10000, yLine), b: vec2(10000, yLine))

    for i, shape in shapes:
      let bounds = bounds[i]
      if bounds.y > y.float32 or bounds.y + bounds.h < y.float32:
        continue
      for (segment, winding) in shape:
        # Lines often connect and we need them to not share starts and ends
        var at: Vec2
        if scanline.intersects(segment, at) and segment.to != at:
          hits.add((at.x.clamp(0, size.x), winding))

    hits.sort(proc(a, b: (float32, bool)): int = cmp(a[0], b[0]))

  var
    hits = newSeq[(float32, bool)]()
    alphas = newSeq[float32](image.width)
  for y in 0 ..< image.height:
    # Reset alphas for this row.
    zeroMem(alphas[0].addr, alphas.len * 4)

    # Do scan lines for this row.
    for m in 0 ..< quality:
      sortedShapes.scanLineHits(bounds, hits, image.wh, y, float32(m) / float32(quality))
      if hits.len == 0:
        continue
      var
        penFill = 0
        curHit = 0
      for x in 0 ..< image.width:
        var penEdge: float32
        case windingRule
        of wrNonZero:
          penEdge = penFill.float32
        of wrEvenOdd:
          if penFill mod 2 == 0:
            penEdge = 0.0
          else:
            penEdge = 1.0

        while true:
          if curHit >= hits.len or x != hits[curHit][0].int:
            break
          let
            cover = hits[curHit][0] - x.float32
            winding = hits[curHit][1]
          if winding == false:
            penFill += 1
            penEdge += 1.0 - cover
          else:
            penFill -= 1
            penEdge -= 1.0 - cover
          inc curHit
        alphas[x] += penEdge

    for x in 0 ..< image.width:
      let a = clamp(abs(alphas[x]) / float32(quality), 0.0, 1.0)
      if a > 0:
        var colorWithAlpha = color
        colorWithAlpha.a = uint8(a * 255.0)
        let rgba = image.getRgbaUnsafe(x, y)
        image.setRgbaUnsafe(x, y, blendNormal(rgba, colorWithAlpha))

{.pop.}

type SomePath = seq[seq[Segment]] | string | Path

proc parseSomePath(path: SomePath): seq[seq[Segment]] =
  ## Given some path, turns it into polys.
  when type(path) is string:
    commandsToShapes(parsePath(path))
  elif type(path) is Path:
    commandsToShapes(path)
  elif type(path) is seq[seq[Segment]]:
    path

proc fillPath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  windingRule = wrNonZero
) =
  let polys = parseSomePath(path)
  image.fillShapes(polys, color, windingRule)

proc fillPath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  pos: Vec2,
  windingRule = wrNonZero
) =
  var polys = parseSomePath(path)
  for poly in polys.mitems:
    for i, p in poly.mpairs:
      poly[i] = p + pos
  image.fillShapes(polys, color, windingRule)

proc fillPath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  mat: Mat3,
  windingRule = wrNonZero
) =
  var polys = parseSomePath(path)
  for poly in polys.mitems:
    for i, p in poly.mpairs:
      poly[i] = mat * p
  image.fillShapes(polys, color, windingRule)

proc strokePath*(
  image: Image,
  path: SomePath,
  color: ColorRGBA,
  strokeWidth: float32,
  windingRule = wrNonZero
) =
  var strokeShapes = strokeShapes(
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
  strokeWidth: float32,
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
  strokeWidth: float32,
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
