import blends, bumpy, chroma, common, images, masks, paints, pixie/internal,
    strutils, vmath

when defined(amd64) and not defined(pixieNoSimd):
  import nimsimd/sse2

type
  WindingRule* = enum
    ## Winding rules.
    wrNonZero
    wrEvenOdd

  LineCap* = enum
    ## Line cap type for strokes.
    lcButt, lcRound, lcSquare

  LineJoin* = enum
    ## Line join type for strokes.
    ljMiter, ljRound, ljBevel

  PathCommandKind* = enum
    ## Type of path commands
    Close,
    Move, Line, HLine, VLine, Cubic, SCubic, Quad, TQuad, Arc,
    RMove, RLine, RHLine, RVLine, RCubic, RSCubic, RQuad, RTQuad, RArc

  PathCommand* = object
    ## Binary version of an SVG command.
    kind*: PathCommandKind
    numbers*: seq[float32]

  Path* = object
    ## Used to hold paths and create paths.
    commands: seq[PathCommand]
    start, at: Vec2 # Maintained by moveTo, lineTo, etc. Used by arcTo.

  SomePath* = Path | string

  Partitioning = object
    partitions: seq[seq[(Segment, int16)]]
    startY, partitionHeight: uint32

const
  epsilon = 0.0001 * PI ## Tiny value used for some computations.
  defaultMiterLimit*: float32 = 4

when defined(release):
  {.push checks: off.}

proc pixelScale(transform: Vec2 | Mat3): float32 =
  ## What is the largest scale factor of this transform?
  when type(transform) is Vec2:
    return 1.0
  else:
    max(
      vec2(transform[0, 0], transform[0, 1]).length,
      vec2(transform[1, 0], transform[1, 1]).length
    )

proc isRelative(kind: PathCommandKind): bool =
  kind in {
    RMove, RLine, TQuad, RTQuad, RHLine, RVLine, RCubic, RSCubic, RQuad, RArc
  }

proc parameterCount(kind: PathCommandKind): int =
  ## Returns number of parameters a path command has.
  case kind:
  of Close: 0
  of Move, Line, RMove, RLine, TQuad, RTQuad: 2
  of HLine, VLine, RHLine, RVLine: 1
  of Cubic, RCubic: 6
  of SCubic, RSCubic, Quad, RQuad: 4
  of Arc, RArc: 7

proc `$`*(path: Path): string =
  ## Turn path int into a string.
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

proc parsePath*(path: string): Path =
  ## Converts a SVG style path string into seq of commands.

  if path.len == 0:
    return

  var
    p, numberStart: int
    armed, hitDecimal: bool
    kind: PathCommandKind
    numbers: seq[float32]

  proc finishNumber() =
    if numberStart > 0:
      try:
        numbers.add(parseFloat(path[numberStart ..< p]))
      except ValueError:
        raise newException(PixieError, "Invalid path, parsing paramter failed")
    numberStart = 0
    hitDecimal = false

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
          if batch > 0:
            if kind == Move:
              kind = Line
            elif kind == RMove:
              kind = RLine
          result.commands.add(PathCommand(
            kind: kind,
            numbers: numbers[batch * paramCount ..< (batch + 1) * paramCount]
          ))
        numbers.setLen(0)

    armed = true

  template expectsArcFlag(): bool =
    kind in {Arc, RArc} and numbers.len mod 7 in {3, 4}

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
    of '.':
      if hitDecimal or expectsArcFlag():
        finishNumber()
      hitDecimal = true
      if numberStart == 0:
        numberStart = p
    of ' ', ',', '\r', '\n', '\t':
      finishNumber()
    else:
      if numberStart > 0 and expectsArcFlag():
        finishNumber()
      if p - 1 == numberStart and path[p - 1] == '0':
        # If the number starts with 0 and we've hit another digit, finish the 0
        # .. 01.3.. -> [..0, 1.3..]
        finishNumber()
      if numberStart == 0:
        numberStart = p

    inc p

  finishCommand(result)

proc transform*(path: var Path, mat: Mat3) =
  ## Apply a matrix transform to a path.
  if mat == mat3():
    return

  if path.commands.len > 0 and path.commands[0].kind == RMove:
    path.commands[0].kind = Move

  for command in path.commands.mitems:
    var mat = mat
    if command.kind.isRelative():
      mat.pos = vec2(0)

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
  ## Attempts to add a straight line from the current point to the start of
  ## the current sub-path. If the shape has already been closed or has only
  ## one point, this function does nothing.
  path.commands.add(PathCommand(kind: Close))
  path.at = path.start

proc moveTo*(path: var Path, x, y: float32) =
  ## Begins a new sub-path at the point (x, y).
  path.commands.add(PathCommand(kind: Move, numbers: @[x, y]))
  path.start = vec2(x, y)
  path.at = path.start

proc moveTo*(path: var Path, v: Vec2) {.inline.} =
  ## Begins a new sub-path at the point (x, y).
  path.moveTo(v.x, v.y)

proc lineTo*(path: var Path, x, y: float32) =
  ## Adds a straight line to the current sub-path by connecting the sub-path's
  ## last point to the specified (x, y) coordinates.
  path.commands.add(PathCommand(kind: Line, numbers: @[x, y]))
  path.at = vec2(x, y)

proc lineTo*(path: var Path, v: Vec2) {.inline.} =
  ## Adds a straight line to the current sub-path by connecting the sub-path's
  ## last point to the specified (x, y) coordinates.
  path.lineTo(v.x, v.y)

proc bezierCurveTo*(path: var Path, x1, y1, x2, y2, x3, y3: float32) =
  ## Adds a cubic Bézier curve to the current sub-path. It requires three
  ## points: the first two are control points and the third one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the Bézier curve.
  path.commands.add(PathCommand(
    kind: Cubic,
    numbers: @[x1, y1, x2, y2, x3, y3]
  ))
  path.at = vec2(x3, y3)

proc bezierCurveTo*(path: var Path, ctrl1, ctrl2, to: Vec2) {.inline.} =
  ## Adds a cubic Bézier curve to the current sub-path. It requires three
  ## points: the first two are control points and the third one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the Bézier curve.
  path.bezierCurveTo(ctrl1.x, ctrl1.y, ctrl2.x, ctrl2.y, to.x, to.y)

proc quadraticCurveTo*(path: var Path, x1, y1, x2, y2: float32) =
  ## Adds a quadratic Bézier curve to the current sub-path. It requires two
  ## points: the first one is a control point and the second one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the quadratic
  ## Bézier curve.
  path.commands.add(PathCommand(
    kind: Quad,
    numbers: @[x1, y1, x2, y2]
  ))
  path.at = vec2(x2, y2)

proc quadraticCurveTo*(path: var Path, ctrl, to: Vec2) {.inline.} =
  ## Adds a quadratic Bézier curve to the current sub-path. It requires two
  ## points: the first one is a control point and the second one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the quadratic
  ## Bézier curve.
  path.quadraticCurveTo(ctrl.x, ctrl.y, to.x, to.y)

# proc arcTo*(path: var Path, ctrl1, ctrl2: Vec2, radius: float32) {.inline.} =
#   ## Adds a circular arc to the current sub-path, using the given control
#   ## points and radius.

#   const epsilon = 1e-6.float32

#   var radius = radius
#   if radius < 0:
#     radius = -radius

#   if path.commands.len == 0:
#     path.moveTo(ctrl1)

#   let
#     a = path.at - ctrl1
#     b = ctrl2 - ctrl1

#   if a.lengthSq() < epsilon:
#     # If the control point is coincident with at, do nothing
#     discard
#   elif abs(a.y * b.x - a.x * b.y) < epsilon or radius == 0:
#     # If ctrl1, a and b are colinear or coincident or radius is zero
#     path.lineTo(ctrl1)
#   else:
#     let
#       c = ctrl2 - path.at
#       als = a.lengthSq()
#       bls = b.lengthSq()
#       cls = c.lengthSq()
#       al = a.length()
#       bl = b.length()
#       l = radius * tan((PI - arccos((als + bls - cls) / 2 * al * bl)) / 2)
#       ta = l / al
#       tb = l / bl

#     if abs(ta - 1) > epsilon:
#       # If the start tangent is not coincident with path.at
#       path.lineTo(ctrl1 + a * ta)

#     echo "INSIDE ", (als + bls - cls) / 2 * al * bl, " ", arccos((als + bls - cls) / 2 * al * bl)

#     let to = ctrl1 + b * tb
#     path.commands.add(PathCommand(
#       kind: Arc,
#       numbers: @[
#         radius,
#         radius,
#         0,
#         0,
#         if a.y * c.x > a.x * c.y: 1 else: 0,
#         to.x,
#         to.y
#       ]
#     ))
#     path.at = to

# proc arcTo*(path: var Path, x1, y1, x2, y2, radius: float32) {.inline.} =
#   ## Adds a circular arc to the current sub-path, using the given control
#   ## points and radius.
#   path.arcTo(vec2(x1, y1), vec2(x2, y2), radius)

proc ellipticalArcTo*(
  path: var Path,
  rx, ry: float32,
  xAxisRotation: float32,
  largeArcFlag, sweepFlag: bool,
  x, y: float32
) =
  ## Adds an elliptical arc to the current sub-path, using the given radius
  ## ratios, sweep flags, and end position.
  path.commands.add(PathCommand(
    kind: Arc,
    numbers: @[
      rx, ry, xAxisRotation, largeArcFlag.float32, sweepFlag.float32, x, y
    ]
  ))
  path.at = vec2(x, y)

proc rect*(path: var Path, x, y, w, h: float32, clockwise = true) =
  ## Adds a rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.
  if clockwise:
    path.moveTo(x, y)
    path.lineTo(x + w, y)
    path.lineTo(x + w, y + h)
    path.lineTo(x, y + h)
    path.closePath()
  else:
    path.moveTo(x, y)
    path.lineTo(x, y + h)
    path.lineTo(x + w, y + h)
    path.lineTo(x + w, y)
    path.closePath()

proc rect*(path: var Path, pos: Vec2, wh: Vec2, clockwise = true) {.inline.} =
  ## Adds a rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.
  path.rect(pos.x, pos.y, wh.x, wh.y, clockwise)

proc rect*(path: var Path, rect: Rect, clockwise = true) {.inline.} =
  ## Adds a rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.
  path.rect(rect.x, rect.y, rect.w, rect.h, clockwise)

const splineCircleK = 4.0 * (-1.0 + sqrt(2.0)) / 3
  ## Reference for magic constant:
  ## https://dl3.pushbulletusercontent.com/a3fLVC8boTzRoxevD1OgCzRzERB9z2EZ/unknown.png

proc roundedRect*(
  path: var Path, x, y, w, h, nw, ne, se, sw: float32, clockwise = true
) =
  ## Adds a rounded rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.

  var
    nw = nw
    ne = ne
    se = se
    sw = sw
    maxRadius = min(w / 2, h / 2)

  nw = max(0, min(nw, maxRadius))
  ne = max(0, min(ne, maxRadius))
  se = max(0, min(se, maxRadius))
  sw = max(0, min(sw, maxRadius))

  if nw == 0 and ne == 0 and se == 0 and sw == 0:
    path.rect(x, y, w, h, clockwise)
    return

  let
    s = splineCircleK

    t1 = vec2(x + nw, y)
    t2 = vec2(x + w - ne, y)
    r1 = vec2(x + w, y + ne)
    r2 = vec2(x + w, y + h - se)
    b1 = vec2(x + w - se, y + h)
    b2 = vec2(x + sw, y + h)
    l1 = vec2(x, y + h - sw)
    l2 = vec2(x, y + nw)

    t1h = t1 + vec2(-nw * s, 0)
    t2h = t2 + vec2(+ne * s, 0)
    r1h = r1 + vec2(0, -ne * s)
    r2h = r2 + vec2(0, +se * s)
    b1h = b1 + vec2(+se * s, 0)
    b2h = b2 + vec2(-sw * s, 0)
    l1h = l1 + vec2(0, +sw * s)
    l2h = l2 + vec2(0, -nw * s)

  if clockwise:
    path.moveTo(t1)
    path.lineTo(t2)
    path.bezierCurveTo(t2h, r1h, r1)
    path.lineTo(r2)
    path.bezierCurveTo(r2h, b1h, b1)
    path.lineTo(b2)
    path.bezierCurveTo(b2h, l1h, l1)
    path.lineTo(l2)
    path.bezierCurveTo(l2h, t1h, t1)
  else:
    path.moveTo(t1)
    path.bezierCurveTo(t1h, l2h, l2)
    path.lineTo(l1)
    path.bezierCurveTo(l1h, b2h, b2)
    path.lineTo(b1)
    path.bezierCurveTo(b1h, r2h, r2)
    path.lineTo(r1)
    path.bezierCurveTo(r1h, t2h, t2)
    path.lineTo(t1)

  path.closePath()

proc roundedRect*(
  path: var Path, pos, wh: Vec2, nw, ne, se, sw: float32, clockwise = true
) {.inline.} =
  ## Adds a rounded rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.
  path.roundedRect(pos.x, pos.y, wh.x, wh.y, nw, ne, se, sw, clockwise)

proc roundedRect*(
  path: var Path, rect: Rect, nw, ne, se, sw: float32, clockwise = true
) {.inline.} =
  ## Adds a rounded rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.
  path.roundedRect(rect.x, rect.y, rect.w, rect.h, nw, ne, se, sw, clockwise)

proc ellipse*(path: var Path, cx, cy, rx, ry: float32) =
  ## Adds a ellipse.
  let
    magicX = splineCircleK * rx
    magicY = splineCircleK * ry

  path.moveTo(cx + rx, cy)
  path.bezierCurveTo(cx + rx, cy + magicY, cx + magicX, cy + ry, cx, cy + ry)
  path.bezierCurveTo(cx - magicX, cy + ry, cx - rx, cy + magicY, cx - rx, cy)
  path.bezierCurveTo(cx - rx, cy - magicY, cx - magicX, cy - ry, cx, cy - ry)
  path.bezierCurveTo(cx + magicX, cy - ry, cx + rx, cy - magicY, cx + rx, cy)
  path.closePath()

proc ellipse*(path: var Path, center: Vec2, rx, ry: float32) {.inline.} =
  ## Adds a ellipse.
  path.ellipse(center.x, center.y, rx, ry)

proc circle*(path: var Path, cx, cy, r: float32) {.inline.} =
  ## Adds a circle.
  path.ellipse(cx, cy, r, r)

proc circle*(path: var Path, center: Vec2, r: float32) {.inline.} =
  ## Adds a circle.
  path.ellipse(center.x, center.y, r, r)

proc circle*(path: var Path, circle: Circle) {.inline.} =
  ## Adds a circle.
  path.ellipse(circle.pos.x, circle.pos.y, circle.radius, circle.radius)

proc polygon*(path: var Path, x, y, size: float32, sides: int) =
  ## Adds an n-sided regular polygon at (x, y) with the parameter size.
  path.moveTo(x + size * cos(0.0), y + size * sin(0.0))
  for side in 0 .. sides:
    path.lineTo(
      x + size * cos(side.float32 * 2.0 * PI / sides.float32),
      y + size * sin(side.float32 * 2.0 * PI / sides.float32)
    )

proc polygon*(path: var Path, pos: Vec2, size: float32, sides: int) {.inline.} =
  ## Adds a n-sided regular polygon at (x, y) with the parameter size.
  path.polygon(pos.x, pos.y, size, sides)

proc commandsToShapes*(
  path: Path, closeSubpaths = false, pixelScale: float32 = 1.0
): seq[seq[Vec2]] =
  ## Converts SVG-like commands to sequences of vectors.
  var
    start, at: Vec2
    shape: seq[Vec2]

  # Some commands use data from the previous command
  var
    prevCommandKind = Move
    prevCtrl, prevCtrl2: Vec2

  let errorMargin = 0.2 / pixelScale

  proc addSegment(shape: var seq[Vec2], at, to: Vec2) =
    # Don't add any 0 length lines
    if at - to != vec2(0, 0):
      # Don't double up points
      if shape.len == 0 or shape[^1] != at:
        shape.add(at)
      shape.add(to)

  proc addCubic(shape: var seq[Vec2], at, ctrl1, ctrl2, to: Vec2) =
    ## Adds cubic segments to shape.
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
    ## Adds quadratic segments to shape.
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
    ## Adds arc segments to shape.
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
        radians: float32 = rotation / 180 * PI
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
          dot = dot(u, v)
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

      if sweep and delta < 0:
        delta += 2 * PI
      elif not sweep and delta > 0:
        delta -= 2 * PI

      # Normalize the delta
      while delta > PI * 2:
        delta -= PI * 2
      while delta < -PI * 2:
        delta += PI * 2

      ArcParams(
        radii: radii,
        rotMat: rotate(-radians),
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
      if shape.len > 0:
        if closeSubpaths:
          shape.addSegment(at, start)
        result.add(shape)
        shape = newSeq[Vec2]()
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
        let ctrl1 = at * 2 - prevCtrl2
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
            at * 2 - prevCtrl
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
      if shape.len > 0:
        result.add(shape)
        shape = newSeq[Vec2]()
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
            at * 2 - prevCtrl2
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
            at * 2 - prevCtrl
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
        shape = newSeq[Vec2]()

    prevCommandKind = command.kind

  if shape.len > 0:
    if closeSubpaths:
      shape.addSegment(at, start)
    result.add(shape)

proc shapesToSegments(shapes: seq[seq[Vec2]]): seq[(Segment, int16)] =
  ## Converts the shapes into a set of filtered segments with winding value.
  for shape in shapes:
    for segment in shape.segments:
      if segment.at.y == segment.to.y: # Skip horizontal
        continue
      var
        segment = segment
        winding = 1.int16
      if segment.at.y > segment.to.y:
        swap(segment.at, segment.to)
        winding = -1

      result.add((segment, winding))

proc requiresAntiAliasing(segments: seq[(Segment, int16)]): bool =
  ## Returns true if the fill requires antialiasing.

  template hasFractional(v: float32): bool =
    v - trunc(v) != 0

  for i in 0 ..< segments.len: # For arc
    let segment = segments[i][0]
    if segment.at.x != segment.to.x or
      segment.at.x.hasFractional() or # at.x and to.x are the same
      segment.at.y.hasFractional() or
      segment.to.y.hasFractional():
      # AA is required if all segments are not vertical or have fractional > 0
      return true

proc computePixelBounds(segments: seq[(Segment, int16)]): Rect =
  ## Compute the bounds of the segments.
  var
    xMin = float32.high
    xMax = float32.low
    yMin = float32.high
    yMax = float32.low
  for i in 0 ..< segments.len: # For arc
    let segment = segments[i][0]
    xMin = min(xMin, min(segment.at.x, segment.to.x))
    xMax = max(xMax, max(segment.at.x, segment.to.x))
    yMin = min(yMin, segment.at.y)
    yMax = max(yMax, segment.to.y)

  xMin = floor(xMin)
  xMax = ceil(xMax)
  yMin = floor(yMin)
  yMax = ceil(yMax)

  if xMin.isNaN() or xMax.isNaN() or yMin.isNaN() or yMax.isNaN():
    discard
  else:
    result.x = xMin
    result.y = yMin
    result.w = xMax - xMin
    result.h = yMax - yMin

proc computePixelBounds*(path: Path): Rect =
  ## Compute the bounds of the path.
  path.commandsToShapes().shapesToSegments().computePixelBounds()

proc partitionSegments(
  segments: seq[(Segment, int16)], top, height: int
): Partitioning =
  ## Puts segments into the height partitions they intersect with.
  let
    maxPartitions = max(1, height div 10).uint32
    numPartitions = min(maxPartitions, max(1, segments.len div 10).uint32)

  result.partitions.setLen(numPartitions)
  result.startY = top.uint32
  result.partitionHeight = height.uint32 div numPartitions

  for (segment, winding) in segments:
    if result.partitionHeight == 0:
      result.partitions[0].add((segment, winding))
    else:
      var
        atPartition = max(0, segment.at.y - result.startY.float32).uint32
        toPartition = max(0, ceil(segment.to.y - result.startY.float32)).uint32
      atPartition = atPartition div result.partitionHeight
      toPartition = toPartition div result.partitionHeight
      atPartition = clamp(atPartition, 0, result.partitions.high.uint32)
      toPartition = clamp(toPartition, 0, result.partitions.high.uint32)
      for i in atPartition .. toPartition:
        result.partitions[i].add((segment, winding))

proc getIndexForY(partitioning: Partitioning, y: int): uint32 {.inline.} =
  if partitioning.partitionHeight == 0 or partitioning.partitions.len == 1:
    0.uint32
  else:
    min(
      (y.uint32 - partitioning.startY) div partitioning.partitionHeight,
      partitioning.partitions.high.uint32
    )

proc quickSort(a: var seq[(float32, int16)], inl, inr: int) =
  ## Sorts in place + faster than standard lib sort.
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

proc insertionSort(s: var seq[(float32, int16)], hi: int) {.inline.} =
  for i in 1 .. hi:
    var
      j = i - 1
      k = i
    while j >= 0 and s[j][0] > s[k][0]:
      swap(s[j + 1], s[j])
      dec j
      dec k

proc shouldFill(windingRule: WindingRule, count: int): bool {.inline.} =
  ## Should we fill based on the current winding rule and count?
  case windingRule:
  of wrNonZero:
    count != 0
  of wrEvenOdd:
    count mod 2 != 0

iterator walk(
  hits: seq[(float32, int16)],
  numHits: int,
  windingRule: WindingRule,
  y: int,
  size: Vec2
): (float32, float32, int32) =
  var
    prevAt: float32
    count: int32
  for i in 0 ..< numHits:
    let (at, winding) = hits[i]
    if windingRule == wrNonZero and
      (count != 0) == (count + winding != 0) and
      i < numHits - 1:
      # Shortcut: if nonzero rule, we only care about when the count changes
      # between zero and nonzero (or the last hit)
      count += winding
      continue
    if at > 0:
      if shouldFill(windingRule, count):
        yield (prevAt, at, count)
      prevAt = at
    count += winding

  when defined(pixieLeakCheck):
    if prevAt != size.x and count != 0:
      echo "Leak detected: ", count, " @ (", prevAt, ", ", y, ")"

proc computeCoverages(
  coverages: var seq[uint8],
  hits: var seq[(float32, int16)],
  numHits: var int,
  size: Vec2,
  y: int,
  aa: bool,
  partitioning: Partitioning,
  windingRule: WindingRule
) {.inline.} =
  let
    quality = if aa: 5 else: 1 # Must divide 255 cleanly (1, 3, 5, 15, 17, 51, 85)
    sampleCoverage = (255 div quality).uint8
    offset = 1 / quality.float32
    initialOffset = offset / 2 + epsilon

  if aa: # Coverage is only used for anti-aliasing
    zeroMem(coverages[0].addr, coverages.len)

  # Do scanlines for this row
  let partitionIndex = partitioning.getIndexForY(y)
  var
    yLine = y.float32 + initialOffset - offset
    scanline = line(vec2(0, yLine), vec2(size.x, yLine))
  for m in 0 ..< quality:
    yLine += offset
    scanline.a.y = yLine
    scanline.b.y = yLine
    numHits = 0
    for i in 0 ..< partitioning.partitions[partitionIndex].len: # For arc
      let
        segment = partitioning.partitions[partitionIndex][i][0]
        winding = partitioning.partitions[partitionIndex][i][1]
      if segment.at.y <= scanline.a.y and segment.to.y >= scanline.a.y:
        var at: Vec2
        if segment.to != at and scanline.intersects(segment, at):
          if numHits == hits.len:
            hits.setLen(hits.len * 2)
          hits[numHits] = (min(at.x, size.x), winding)
          inc numHits

    if hits.len > 32:
      quickSort(hits, 0, numHits - 1)
    else:
      insertionSort(hits, numHits - 1)

    if aa:
      for (prevAt, at, count) in hits.walk(numHits, windingRule, y, size):
        var fillStart = prevAt.int

        let
          pixelCrossed = at.int - prevAt.int > 0
          leftCover =
            if pixelCrossed:
              trunc(prevAt) + 1 - prevAt
            else:
              at - prevAt
        if leftCover != 0:
          inc fillStart
          coverages[prevAt.int] += (leftCover * sampleCoverage.float32).uint8

        if pixelCrossed:
          let rightCover = at - trunc(at)
          if rightCover > 0:
            coverages[at.int] += (rightCover * sampleCoverage.float32).uint8

        let fillLen = at.int - fillStart
        if fillLen > 0:
          var i = fillStart
          when defined(amd64) and not defined(pixieNoSimd):
            let vSampleCoverage = mm_set1_epi8(cast[int8](sampleCoverage))
            for j in countup(i, fillStart + fillLen - 16, 16):
              var coverage = mm_loadu_si128(coverages[j].addr)
              coverage = mm_add_epi8(coverage, vSampleCoverage)
              mm_storeu_si128(coverages[j].addr, coverage)
              i += 16
          for j in i ..< fillStart + fillLen:
            coverages[j] += sampleCoverage

proc clearUnsafe(target: Image | Mask, startX, startY, toX, toY: int) =
  ## Clears data from [start, to).
  let
    start = target.dataIndex(startX, startY)
    len = target.dataIndex(toX, toY) - start
  when type(target) is Image:
    target.data.fillUnsafe(rgbx(0, 0, 0, 0), start, len)
  else: # target is Mask
    target.data.fillUnsafe(0, start, len)

proc fillCoverage(
  image: Image,
  rgbx: ColorRGBX,
  startX, y: int,
  coverages: seq[uint8],
  blendMode: BlendMode
) =
  var x = startX
  when defined(amd64) and not defined(pixieNoSimd):
    if blendMode.hasSimdBlender():
      # When supported, SIMD blend as much as possible
      let
        blenderSimd = blendMode.blenderSimd()
        first32 = cast[M128i]([uint32.high, 0, 0, 0]) # First 32 bits
        oddMask = mm_set1_epi16(cast[int16](0xff00))
        div255 = mm_set1_epi16(cast[int16](0x8081))
        vColor = mm_set1_epi32(cast[int32](rgbx))
      for _ in countup(x, image.width - 16, 4):
        var coverage = mm_loadu_si128(coverages[x].unsafeAddr)
        coverage = mm_and_si128(coverage, first32)

        let
          index = image.dataIndex(x, y)
          eqZero = mm_cmpeq_epi16(coverage, mm_setzero_si128())
        if mm_movemask_epi8(eqZero) != 0xffff: # or blendMode == bmExcludeMask:
          # If the coverages are not all zero
          if mm_movemask_epi8(mm_cmpeq_epi32(coverage, first32)) == 0xffff:
            # Coverages are all 255
            if blendMode == bmNormal and rgbx.a == 255:
              mm_storeu_si128(image.data[index].addr, vColor)
            else:
              let backdrop = mm_loadu_si128(image.data[index].addr)
              mm_storeu_si128(
                image.data[index].addr,
                blenderSimd(backdrop, vColor)
              )
          else:
            # Coverages are not all 255
            coverage = unpackAlphaValues(coverage)
            # Shift the coverages from `a` to `g` and `a` for multiplying
            coverage = mm_or_si128(coverage, mm_srli_epi32(coverage, 16))

            var
              source = vColor
              sourceEven = mm_slli_epi16(source, 8)
              sourceOdd = mm_and_si128(source, oddMask)

            sourceEven = mm_mulhi_epu16(sourceEven, coverage)
            sourceOdd = mm_mulhi_epu16(sourceOdd, coverage)

            sourceEven = mm_srli_epi16(mm_mulhi_epu16(sourceEven, div255), 7)
            sourceOdd = mm_srli_epi16(mm_mulhi_epu16(sourceOdd, div255), 7)

            source = mm_or_si128(sourceEven, mm_slli_epi16(sourceOdd, 8))

            let backdrop = mm_loadu_si128(image.data[index].addr)
            mm_storeu_si128(
              image.data[index].addr,
              blenderSimd(backdrop, source)
            )
        elif blendMode == bmMask:
          mm_storeu_si128(image.data[index].addr, mm_setzero_si128())
        x += 4

  let blender = blendMode.blender()
  while x < image.width:
    let coverage = coverages[x]
    if coverage != 0 or blendMode == bmExcludeMask:
      if blendMode == bmNormal and coverage == 255 and rgbx.a == 255:
        # Skip blending
        image.setRgbaUnsafe(x, y, rgbx)
      else:
        var source = rgbx
        if coverage != 255:
          source.r = ((source.r.uint32 * coverage) div 255).uint8
          source.g = ((source.g.uint32 * coverage) div 255).uint8
          source.b = ((source.b.uint32 * coverage) div 255).uint8
          source.a = ((source.a.uint32 * coverage) div 255).uint8
        let backdrop = image.getRgbaUnsafe(x, y)
        image.setRgbaUnsafe(x, y, blender(backdrop, source))
    elif blendMode == bmMask:
      image.setRgbaUnsafe(x, y, rgbx(0, 0, 0, 0))
    inc x

  if blendMode == bmMask:
    image.clearUnsafe(0, y, startX, y)

proc fillCoverage(
  mask: Mask,
  startX, y: int,
  coverages: seq[uint8],
  blendMode: BlendMode
) =
  var x = startX
  when defined(amd64) and not defined(pixieNoSimd):
    if blendMode.hasSimdMasker():
      let maskerSimd = blendMode.maskerSimd()
      for _ in countup(x, coverages.len - 16, 16):
        let
          index = mask.dataIndex(x, y)
          coverage = mm_loadu_si128(coverages[x].unsafeAddr)
          eqZero = mm_cmpeq_epi16(coverage, mm_setzero_si128())
        if mm_movemask_epi8(eqZero) != 0xffff: # or blendMode == bmExcludeMask:
          # If the coverages are not all zero
          let backdrop = mm_loadu_si128(mask.data[index].addr)
          mm_storeu_si128(
            mask.data[index].addr,
            maskerSimd(backdrop, coverage)
          )
        elif blendMode == bmMask:
          mm_storeu_si128(mask.data[index].addr, mm_setzero_si128())
        x += 16

  let masker = blendMode.masker()
  while x < mask.width:
    let coverage = coverages[x]
    if coverage != 0 or blendMode == bmExcludeMask:
      let backdrop = mask.getValueUnsafe(x, y)
      mask.setValueUnsafe(x, y, masker(backdrop, coverage))
    elif blendMode == bmMask:
      mask.setValueUnsafe(x, y, 0)
    inc x

  if blendMode == bmMask:
    mask.clearUnsafe(0, y, startX, y)

proc fillHits(
  image: Image,
  rgbx: ColorRGBX,
  startX, y: int,
  hits: seq[(float32, int16)],
  numHits: int,
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  let blender = blendMode.blender()
  var filledTo: int
  for (prevAt, at, count) in hits.walk(numHits, windingRule, y, image.wh):
    let
      fillStart = prevAt.int
      fillLen = at.int - fillStart
    if fillLen <= 0:
      continue

    filledTo = fillStart + fillLen

    if blendMode == bmNormal and rgbx.a == 255:
      fillUnsafe(image.data, rgbx, image.dataIndex(fillStart, y), fillLen)
      continue

    var x = fillStart
    when defined(amd64) and not defined(pixieNoSimd):
      if blendMode.hasSimdBlender():
        # When supported, SIMD blend as much as possible
        let
          blenderSimd = blendMode.blenderSimd()
          vColor = mm_set1_epi32(cast[int32](rgbx))
        for _ in countup(fillStart, fillLen - 16, 4):
          let
            index = image.dataIndex(x, y)
            backdrop = mm_loadu_si128(image.data[index].addr)
          mm_storeu_si128(
            image.data[index].addr,
            blenderSimd(backdrop, vColor)
          )
          x += 4

    for x in x ..< fillStart + fillLen:
      let backdrop = image.getRgbaUnsafe(x, y)
      image.setRgbaUnsafe(x, y, blender(backdrop, rgbx))

  if blendMode == bmMask:
    image.clearUnsafe(0, y, startX, y)
    image.clearUnsafe(filledTo, y, image.width, y)

proc fillHits(
  mask: Mask,
  startX, y: int,
  hits: seq[(float32, int16)],
  numHits: int,
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  let masker = blendMode.masker()
  var filledTo: int
  for (prevAt, at, count) in hits.walk(numHits, windingRule, y, mask.wh):
    let
      fillStart = prevAt.int
      fillLen = at.int - fillStart
    if fillLen <= 0:
      continue

    filledTo = fillStart + fillLen

    if blendMode == bmNormal:
      fillUnsafe(mask.data, 255, mask.dataIndex(fillStart, y), fillLen)
      continue

    var x = fillStart
    when defined(amd64) and not defined(pixieNoSimd):
      if blendMode.hasSimdMasker():
        let
          maskerSimd = blendMode.maskerSimd()
          vValue = mm_set1_epi8(cast[int8](255))
        for _ in countup(fillStart, fillLen - 16, 16):
          let backdrop = mm_loadu_si128(mask.data[mask.dataIndex(x, y)].addr)
          mm_storeu_si128(
            mask.data[mask.dataIndex(x, y)].addr,
            maskerSimd(backdrop, vValue)
          )
          x += 16

    for x in x ..< fillStart + fillLen:
      let backdrop = mask.getValueUnsafe(x, y)
      mask.setValueUnsafe(x, y, masker(backdrop, 255))

  if blendMode == bmMask:
    mask.clearUnsafe(0, y, startX, y)
    mask.clearUnsafe(filledTo, y, mask.width, y)

proc fillShapes(
  image: Image,
  shapes: seq[seq[Vec2]],
  color: SomeColor,
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  # Figure out the total bounds of all the shapes,
  # rasterize only within the total bounds
  let
    rgbx = color.asRgbx()
    segments = shapes.shapesToSegments()
    aa = segments.requiresAntiAliasing()
    bounds = computePixelBounds(segments)
    startX = max(0, bounds.x.int)
    startY = max(0, bounds.y.int)
    pathHeight = min(image.height, (bounds.y + bounds.h).int)
    partitioning = partitionSegments(segments, startY, pathHeight - startY)

  var
    coverages = newSeq[uint8](image.width)
    hits = newSeq[(float32, int16)](4)
    numHits: int

  for y in startY ..< pathHeight:
    computeCoverages(
      coverages,
      hits,
      numHits,
      image.wh,
      y,
      aa,
      partitioning,
      windingRule
    )
    if aa:
      image.fillCoverage(
        rgbx,
        startX,
        y,
        coverages,
        blendMode
      )
    else:
      image.fillHits(
        rgbx,
        startX,
        y,
        hits,
        numHits,
        windingRule,
        blendMode
      )

  if blendMode == bmMask:
    image.clearUnsafe(0, 0, 0, startY)
    image.clearUnsafe(0, pathHeight, 0, image.height)

proc fillShapes(
  mask: Mask,
  shapes: seq[seq[Vec2]],
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  # Figure out the total bounds of all the shapes,
  # rasterize only within the total bounds
  let
    segments = shapes.shapesToSegments()
    aa = segments.requiresAntiAliasing()
    bounds = computePixelBounds(segments)
    startX = max(0, bounds.x.int)
    startY = max(0, bounds.y.int)
    pathHeight = min(mask.height, (bounds.y + bounds.h).int)
    partitioning = partitionSegments(segments, startY, pathHeight)

  var
    coverages = newSeq[uint8](mask.width)
    hits = newSeq[(float32, int16)](4)
    numHits: int

  for y in startY ..< pathHeight:
    computeCoverages(
      coverages,
      hits,
      numHits,
      mask.wh,
      y,
      aa,
      partitioning,
      windingRule
    )
    if aa:
      mask.fillCoverage(startX, y, coverages, blendMode)
    else:
      mask.fillHits(startX, y, hits, numHits, windingRule, blendMode)

  if blendMode == bmMask:
    mask.clearUnsafe(0, 0, 0, startY)
    mask.clearUnsafe(0, pathHeight, 0, mask.height)

proc miterLimitToAngle*(limit: float32): float32 =
  ## Converts miter-limit-ratio to miter-limit-angle.
  arcsin(1 / limit) * 2

proc angleToMiterLimit*(angle: float32): float32 =
  ## Converts miter-limit-angle to miter-limit-ratio.
  1 / sin(angle / 2)

proc strokeShapes(
  shapes: seq[seq[Vec2]],
  strokeWidth: float32,
  lineCap: LineCap,
  lineJoin: LineJoin,
  miterLimit: float32,
  dashes: seq[float32]
): seq[seq[Vec2]] =
  if strokeWidth <= 0:
    return

  let
    halfStroke = strokeWidth / 2
    miterAngleLimit = miterLimitToAngle(miterLimit)

  proc makeCircle(at: Vec2): seq[Vec2] =
    var path: Path
    path.ellipse(at, halfStroke, halfStroke)
    path.commandsToShapes()[0]

  proc makeRect(at, to: Vec2): seq[Vec2] =
    # Rectangle corners
    let
      tangent = (to - at).normalize()
      normal = vec2(tangent.y, tangent.x)
      a = vec2(
        at.x + normal.x * halfStroke,
        at.y - normal.y * halfStroke
      )
      b = vec2(
        to.x + normal.x * halfStroke,
        to.y - normal.y * halfStroke
      )
      c = vec2(
        to.x - normal.x * halfStroke,
        to.y + normal.y * halfStroke
      )
      d = vec2(
        at.x - normal.x * halfStroke,
        at.y + normal.y * halfStroke
      )

    @[a, b, c, d, a]

  proc makeJoin(prevPos, pos, nextPos: Vec2): seq[Vec2] =
    let angle = fixAngle(angle(nextPos - pos) - angle(prevPos - pos))
    if abs(abs(angle) - PI) > epsilon:
      var
        a = (pos - prevPos).normalize() * halfStroke
        b = (pos - nextPos).normalize() * halfStroke
      if angle >= 0:
        a = vec2(-a.y, a.x)
        b = vec2(b.y, -b.x)
      else:
        a = vec2(a.y, -a.x)
        b = vec2(-b.y, b.x)

      var lineJoin = lineJoin
      if lineJoin == ljMiter and abs(angle) < miterAngleLimit:
        lineJoin = ljBevel

      case lineJoin:
      of ljMiter:
        let
          la = line(prevPos + a, pos + a)
          lb = line(nextPos + b, pos + b)
        var at: Vec2
        if la.intersects(lb, at):
          return @[pos + a, at, pos + b, pos, pos + a]

      of ljBevel:
        return @[a + pos, b + pos, pos, a + pos]

      of ljRound:
        return makeCircle(pos)

  for shape in shapes:
    var shapeStroke: seq[seq[Vec2]]

    if shape[0] != shape[^1]:
      # This shape does not end at the same point it starts so draw the
      # first line cap.
      case lineCap:
      of lcButt:
        discard
      of lcRound:
        shapeStroke.add(makeCircle(shape[0]))
      of lcSquare:
        let tangent = (shape[1] - shape[0]).normalize()
        shapeStroke.add(makeRect(
          shape[0] - tangent * halfStroke,
          shape[0]
        ))

    var dashes = dashes
    if dashes.len mod 2 != 0:
      dashes.add(dashes)

    for i in 1 ..< shape.len:
      let
        pos = shape[i]
        prevPos = shape[i - 1]

      if dashes.len > 0:
        var distance = dist(prevPos, pos)
        let dir = dir(pos, prevPos)
        var currPos = prevPos
        block dashLoop:
          while true:
            for i, d in dashes:
              if i mod 2 == 0:
                let d = min(distance, d)
                shapeStroke.add(makeRect(currPos, currPos + dir * d))
              currPos += dir * d
              distance -= d
              if distance <= 0:
                break dashLoop
      else:
        shapeStroke.add(makeRect(prevPos, pos))

      # If we need a line join
      if i < shape.len - 1:
        shapeStroke.add(makeJoin(prevPos, pos, shape[i + 1]))

    if shape[0] == shape[^1]:
      shapeStroke.add(makeJoin(shape[^2], shape[^1], shape[1]))
    else:
      case lineCap:
      of lcButt:
        discard
      of lcRound:
        shapeStroke.add(makeCircle(shape[^1]))
      of lcSquare:
        let tangent = (shape[^1] - shape[^2]).normalize()
        shapeStroke.add(makeRect(
          shape[^1] + tangent * halfStroke,
          shape[^1]
        ))

    result.add(shapeStroke)

proc parseSomePath(
  path: SomePath, closeSubpaths: bool, pixelScale: float32 = 1.0
): seq[seq[Vec2]] {.inline.} =
  ## Given SomePath, parse it in different ways.
  when type(path) is string:
    parsePath(path).commandsToShapes(closeSubpaths, pixelScale)
  elif type(path) is Path:
    path.commandsToShapes(closeSubpaths, pixelScale)

proc transform(shapes: var seq[seq[Vec2]], transform: Vec2 | Mat3) =
  when type(transform) is Vec2:
    if transform != vec2():
      for shape in shapes.mitems:
        for segment in shape.mitems:
          segment += transform
  else:
    if transform != mat3():
      for shape in shapes.mitems:
        for segment in shape.mitems:
          segment = transform * segment

proc fillPath*(
  mask: Mask,
  path: SomePath,
  transform: Vec2 | Mat3 = vec2(),
  windingRule = wrNonZero,
  blendMode = bmNormal
) =
  ## Fills a path.
  var shapes = parseSomePath(path, true, transform.pixelScale())
  shapes.transform(transform)
  mask.fillShapes(shapes, windingRule, blendMode)

proc fillPath*(
  image: Image,
  path: SomePath,
  paint: Paint,
  transform: Vec2 | Mat3 = vec2(),
  windingRule = wrNonZero
) =
  ## Fills a path.
  if paint.kind == pkSolid:
    if paint.color.a > 0 or paint.blendMode == bmOverwrite:
      var shapes = parseSomePath(path, true, transform.pixelScale())
      shapes.transform(transform)
      image.fillShapes(shapes, paint.color, windingRule, paint.blendMode)
    return

  let
    mask = newMask(image.width, image.height)
    fill = newImage(image.width, image.height)

  mask.fillPath(path, transform, windingRule)

  case paint.kind:
    of pkSolid:
      discard # Handled above
    of pkImage:
      fill.draw(paint.image, paint.imageMat)
    of pkImageTiled:
      fill.drawTiled(paint.image, paint.imageMat)
    of pkGradientLinear:
      fill.fillGradientLinear(paint)
    of pkGradientRadial:
      fill.fillGradientRadial(paint)
    of pkGradientAngular:
      fill.fillGradientAngular(paint)

  fill.draw(mask)
  image.draw(fill, blendMode = paint.blendMode)

proc strokePath*(
  mask: Mask,
  path: SomePath,
  transform: Vec2 | Mat3 = vec2(),
  strokeWidth = 1.0,
  lineCap = lcButt,
  lineJoin = ljMiter,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[],
  blendMode = bmNormal
) =
  ## Strokes a path.
  var strokeShapes = strokeShapes(
    parseSomePath(path, false, transform.pixelScale()),
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes
  )
  strokeShapes.transform(transform)
  mask.fillShapes(strokeShapes, wrNonZero, blendMode)

proc strokePath*(
  image: Image,
  path: SomePath,
  paint: Paint,
  transform: Vec2 | Mat3 = vec2(),
  strokeWidth = 1.0,
  lineCap = lcButt,
  lineJoin = ljMiter,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
) =
  ## Strokes a path.
  if paint.kind == pkSolid:
    if paint.color.a > 0 or paint.blendMode == bmOverwrite:
      var strokeShapes = strokeShapes(
        parseSomePath(path, false, transform.pixelScale()),
        strokeWidth,
        lineCap,
        lineJoin,
        miterLimit,
        dashes
      )
      strokeShapes.transform(transform)
      image.fillShapes(strokeShapes, paint.color, wrNonZero, paint.blendMode)
    return

  let
    mask = newMask(image.width, image.height)
    fill = newImage(image.width, image.height)

  mask.strokePath(
    path,
    transform,
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes
  )

  case paint.kind:
    of pkSolid:
      discard # Handled above
    of pkImage:
      fill.draw(paint.image, paint.imageMat)
    of pkImageTiled:
      fill.drawTiled(paint.image, paint.imageMat)
    of pkGradientLinear:
      fill.fillGradientLinear(paint)
    of pkGradientRadial:
      fill.fillGradientRadial(paint)
    of pkGradientAngular:
      fill.fillGradientAngular(paint)

  fill.draw(mask)
  image.draw(fill, blendMode = paint.blendMode)

when defined(release):
  {.pop.}
