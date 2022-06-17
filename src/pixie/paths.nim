import blends, bumpy, chroma, common, fenv, images, internal, masks, paints,
    strutils, vmath

when defined(amd64) and allowSimd:
  import nimsimd/sse2

type
  WindingRule* = enum
    ## Winding rules.
    NonZero
    EvenOdd

  LineCap* = enum
    ## Line cap type for strokes.
    ButtCap, RoundCap, SquareCap

  LineJoin* = enum
    ## Line join type for strokes.
    MiterJoin, RoundJoin, BevelJoin

  PathCommandKind = enum
    ## Type of path commands
    Close,
    Move, Line, HLine, VLine, Cubic, SCubic, Quad, TQuad, Arc,
    RMove, RLine, RHLine, RVLine, RCubic, RSCubic, RQuad, RTQuad, RArc

  PathCommand = object
    ## Binary version of an SVG command.
    kind: PathCommandKind
    numbers: seq[float32]

  Path* = ref object
    ## Used to hold paths and create paths.
    commands: seq[PathCommand]
    start, at: Vec2 # Maintained by moveTo, lineTo, etc. Used by arcTo.

  SomePath* = Path | string

  PartitionEntry = object
    segment: Segment
    m, b: float32
    winding: int16

  Partition = object
    entries: seq[PartitionEntry]
    requiresAntiAliasing: bool

  Partitioning = object
    partitions: seq[Partition]
    startY, partitionHeight: uint32

  Fixed32 = int32 ## 24.8 fixed point

const
  epsilon: float32 = 0.0001 * PI ## Tiny value used for some computations.
  pixelErrorMargin: float32 = 0.2
  defaultMiterLimit*: float32 = 4

when defined(release):
  {.push checks: off.}

proc newPath*(): Path {.raises: [].} =
  ## Create a new Path.
  Path()

proc pixelScale(transform: Mat3): float32 =
  ## What is the largest scale factor of this transform?
  max(
    vec2(transform[0, 0], transform[0, 1]).length,
    vec2(transform[1, 0], transform[1, 1]).length
  )

proc isRelative(kind: PathCommandKind): bool {.inline.} =
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

proc `$`*(path: Path): string {.raises: [].} =
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

proc parsePath*(path: string): Path {.raises: [PixieError].} =
  ## Converts a SVG style path string into seq of commands.
  result = newPath()

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
        raise newException(PixieError, "Invalid path, parsing parameter failed")
    numberStart = 0
    hitDecimal = false

  proc finishCommand(result: Path) =
    finishNumber()

    if armed: # The first finishCommand() arms
      let paramCount = parameterCount(kind)
      if paramCount == 0:
        if numbers.len != 0:
          raise newException(PixieError, "Invalid path, unexpected parameters")
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

proc transform*(path: Path, mat: Mat3) {.raises: [].} =
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

proc addPath*(path: Path, other: Path) {.raises: [].} =
  ## Adds a path to the current path.
  path.commands.add(other.commands)

proc closePath*(path: Path) {.raises: [].} =
  ## Attempts to add a straight line from the current point to the start of
  ## the current sub-path. If the shape has already been closed or has only
  ## one point, this function does nothing.
  path.commands.add(PathCommand(kind: Close))
  path.at = path.start

proc moveTo*(path: Path, x, y: float32) {.raises: [].} =
  ## Begins a new sub-path at the point (x, y).
  path.commands.add(PathCommand(kind: Move, numbers: @[x, y]))
  path.start = vec2(x, y)
  path.at = path.start

proc moveTo*(path: Path, v: Vec2) {.inline, raises: [].} =
  ## Begins a new sub-path at the point (x, y).
  path.moveTo(v.x, v.y)

proc lineTo*(path: Path, x, y: float32) {.raises: [].} =
  ## Adds a straight line to the current sub-path by connecting the sub-path's
  ## last point to the specified (x, y) coordinates.
  path.commands.add(PathCommand(kind: Line, numbers: @[x, y]))
  path.at = vec2(x, y)

proc lineTo*(path: Path, v: Vec2) {.inline, raises: [].} =
  ## Adds a straight line to the current sub-path by connecting the sub-path's
  ## last point to the specified (x, y) coordinates.
  path.lineTo(v.x, v.y)

proc bezierCurveTo*(path: Path, x1, y1, x2, y2, x3, y3: float32) {.raises: [].} =
  ## Adds a cubic Bézier curve to the current sub-path. It requires three
  ## points: the first two are control points and the third one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the Bézier curve.
  path.commands.add(PathCommand(
    kind: Cubic,
    numbers: @[x1, y1, x2, y2, x3, y3]
  ))
  path.at = vec2(x3, y3)

proc bezierCurveTo*(path: Path, ctrl1, ctrl2, to: Vec2) {.inline, raises: [].} =
  ## Adds a cubic Bézier curve to the current sub-path. It requires three
  ## points: the first two are control points and the third one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the Bézier curve.
  path.bezierCurveTo(ctrl1.x, ctrl1.y, ctrl2.x, ctrl2.y, to.x, to.y)

proc quadraticCurveTo*(path: Path, x1, y1, x2, y2: float32) {.raises: [].} =
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

proc quadraticCurveTo*(path: Path, ctrl, to: Vec2) {.inline, raises: [].} =
  ## Adds a quadratic Bézier curve to the current sub-path. It requires two
  ## points: the first one is a control point and the second one is the end
  ## point. The starting point is the latest point in the current path,
  ## which can be changed using moveTo() before creating the quadratic
  ## Bézier curve.
  path.quadraticCurveTo(ctrl.x, ctrl.y, to.x, to.y)

proc ellipticalArcTo*(
  path: Path,
  rx, ry: float32,
  xAxisRotation: float32,
  largeArcFlag, sweepFlag: bool,
  x, y: float32
) {.raises: [].} =
  ## Adds an elliptical arc to the current sub-path, using the given radius
  ## ratios, sweep flags, and end position.
  path.commands.add(PathCommand(
    kind: Arc,
    numbers: @[
      rx, ry, xAxisRotation, largeArcFlag.float32, sweepFlag.float32, x, y
    ]
  ))
  path.at = vec2(x, y)

proc arc*(
  path: Path, x, y, r, a0, a1: float32, ccw: bool = false
) {.raises: [PixieError].} =
  ## Adds a circular arc to the current sub-path.
  if r == 0: # When radius is zero, do nothing.
    return
  if r < 0: # When radius is negative, error.
    raise newException(PixieError, "Invalid arc, negative radius: " & $r)

  let
    dx = r * cos(a0)
    dy = r * sin(a0)
    x0 = x + dx
    y0 = y + dy
    cw = not ccw

  if path.commands.len == 0: # Is this path empty? Move to (x0, y0).
    path.moveTo(x0, y0)
  elif abs(path.at.x - x0) > epsilon or abs(path.at.y - y0) > epsilon:
    path.lineTo(x0, y0)

  var angle =
    if ccw: a0 - a1
    else: a1 - a0
  if angle < 0:
    # When the angle goes the wrong way, flip the direction.
    angle = angle mod TAU + TAU

  if angle > TAU - epsilon:
    # Angle describes a complete circle. Draw it in two arcs.
    path.ellipticalArcTo(r, r, 0, true, cw, x - dx, y - dy)
    path.at.x = x0
    path.at.y = y0
    path.ellipticalArcTo(r, r, 0, true, cw, path.at.x, path.at.y)
  elif angle > epsilon:
    path.at.x = x + r * cos(a1)
    path.at.y = y + r * sin(a1)
    path.ellipticalArcTo(r, r, 0, angle >= PI, cw, path.at.x, path.at.y)

proc arc*(
  path: Path, pos: Vec2, r: float32, a: Vec2, ccw: bool = false
) {.inline, raises: [PixieError].} =
  ## Adds a circular arc to the current sub-path.
  path.arc(pos.x, pos.y, r, a.x, a.y, ccw)

proc arcTo*(path: Path, x1, y1, x2, y2, r: float32) {.raises: [PixieError].} =
  ## Adds a circular arc using the given control points and radius.
  ## Commonly used for making rounded corners.
  if r < 0: # When radius is negative, error.
    raise newException(PixieError, "Invalid arc, negative radius: " & $r)

  let
    x0 = path.at.x
    y0 = path.at.y
    x21 = x2 - x1
    y21 = y2 - y1
    x01 = x0 - x1
    y01 = y0 - y1
    l01_2 = x01 * x01 + y01 * y01

  if path.commands.len == 0: # Is this path empty? Move to (x0, y0).
    path.moveTo(x0, y0)
  elif not(l01_2 > epsilon): # Is (x1, y1) coincident with (x0, y0)? Do nothing.
    discard
  elif not(abs(y01 * x21 - y21 * x01) > epsilon) or r == 0: # Just a line?
    path.lineTo(x1, y1)
  else:
    let
      x20 = x2 - x0
      y20 = y2 - y0
      l21_2 = x21 * x21 + y21 * y21
      l20_2 = x20 * x20 + y20 * y20
      l21 = sqrt(l21_2)
      l01 = sqrt(l01_2)
      l = r * tan((PI - arccos((l21_2 + l01_2 - l20_2) / (2 * l21 * l01))) / 2)
      t01 = l / l01
      t21 = l / l21

    # If the start tangent is not coincident with (x0, y0), line to.
    if abs(t01 - 1) > epsilon:
      path.lineTo(x1 + t01 * x01, y1 + t01 * y01)

    path.at.x = x1 + t21 * x21
    path.at.y = y1 + t21 * y21
    path.ellipticalArcTo(r, r, 0, false, y01 * x20 > x01 * y20, path.at.x, path.at.y)

proc arcTo*(path: Path, a, b: Vec2, r: float32) {.inline, raises: [PixieError].} =
  ## Adds a circular arc using the given control points and radius.
  path.arcTo(a.x, a.y, b.x, b.y, r)

proc rect*(path: Path, x, y, w, h: float32, clockwise = true) {.raises: [].} =
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

proc rect*(path: Path, rect: Rect, clockwise = true) {.inline, raises: [].} =
  ## Adds a rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.
  path.rect(rect.x, rect.y, rect.w, rect.h, clockwise)

const splineCircleK = 4.0 * (-1.0 + sqrt(2.0)) / 3
  ## Reference for magic constant:
  ## https://dl3.pushbulletusercontent.com/a3fLVC8boTzRoxevD1OgCzRzERB9z2EZ/unknown.png

proc roundedRect*(
  path: Path, x, y, w, h, nw, ne, se, sw: float32, clockwise = true
) {.raises: [].} =
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
  path: Path, rect: Rect, nw, ne, se, sw: float32, clockwise = true
) {.inline, raises: [].} =
  ## Adds a rounded rectangle.
  ## Clockwise param can be used to subtract a rect from a path when using
  ## even-odd winding rule.
  path.roundedRect(rect.x, rect.y, rect.w, rect.h, nw, ne, se, sw, clockwise)

proc ellipse*(path: Path, cx, cy, rx, ry: float32) {.raises: [].} =
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

proc ellipse*(path: Path, center: Vec2, rx, ry: float32) {.inline, raises: [].} =
  ## Adds a ellipse.
  path.ellipse(center.x, center.y, rx, ry)

proc circle*(path: Path, cx, cy, r: float32) {.inline, raises: [].} =
  ## Adds a circle.
  path.ellipse(cx, cy, r, r)

proc circle*(path: Path, circle: Circle) {.inline, raises: [].} =
  ## Adds a circle.
  path.ellipse(circle.pos.x, circle.pos.y, circle.radius, circle.radius)

proc polygon*(
  path: Path, x, y, size: float32, sides: int
) {.raises: [PixieError].} =
  ## Adds an n-sided regular polygon at (x, y) with the parameter size.
  ## Polygons "face" north.
  if sides <= 2:
    raise newException(PixieError, "Invalid polygon sides value")
  path.moveTo(x + size * sin(0.0), y - size * cos(0.0))
  for side in 1 .. sides - 1:
    path.lineTo(
      x + size * sin(side.float32 * 2.0 * PI / sides.float32),
      y - size * cos(side.float32 * 2.0 * PI / sides.float32)
    )
  path.closePath()

proc polygon*(
  path: Path, pos: Vec2, size: float32, sides: int
) {.inline, raises: [PixieError].} =
  ## Adds a n-sided regular polygon at (x, y) with the parameter size.
  path.polygon(pos.x, pos.y, size, sides)

proc commandsToShapes(
  path: Path, closeSubpaths: bool, pixelScale: float32
): seq[Polygon] =
  ## Converts SVG-like commands to sequences of vectors.
  var
    start, at: Vec2
    shape: Polygon

  # Some commands use data from the previous command
  var
    prevCommandKind = Move
    prevCtrl, prevCtrl2: Vec2

  let errorMarginSq = pow(pixelErrorMargin / pixelScale, 2)

  proc addSegment(shape: var Polygon, at, to: Vec2) =
    # Don't add any 0 length lines
    if at - to != vec2(0, 0):
      # Don't double up points
      if shape.len == 0 or shape[^1] != at:
        shape.add(at)
      shape.add(to)

  proc addCubic(shape: var Polygon, at, ctrl1, ctrl2, to: Vec2) =
    ## Adds cubic segments to shape.
    proc compute(at, ctrl1, ctrl2, to: Vec2, t: float32): Vec2 {.inline.} =
      pow(1 - t, 3) * at +
      pow(1 - t, 2) * 3 * t * ctrl1 +
      (1 - t) * 3 * pow(t, 2) * ctrl2 +
      pow(t, 3) * to

    var
      t: float32       # Where we are at on the curve from [0, 1]
      step = 1.float32 # How far we want to try to move along the curve
      prev = at
      next = compute(at, ctrl1, ctrl2, to, t + step)
      halfway = compute(at, ctrl1, ctrl2, to, t + step / 2)
    while true:
      if step <= epsilon(float32):
        raise newException(PixieError, "Unable to discretize cubic")
      let
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).lengthSq
      if error > errorMarginSq:
        next = halfway
        halfway = compute(at, ctrl1, ctrl2, to, t + step / 4)
        step /= 2
      else:
        shape.addSegment(prev, next)
        t += step
        if t == 1:
          break
        prev = next
        step = min(step * 2, 1 - t) # Optimistically attempt larger steps
        next = compute(at, ctrl1, ctrl2, to, t + step)
        halfway = compute(at, ctrl1, ctrl2, to, t + step / 2)

  proc addQuadratic(shape: var Polygon, at, ctrl, to: Vec2) =
    ## Adds quadratic segments to shape.
    proc compute(at, ctrl, to: Vec2, t: float32): Vec2 {.inline.} =
      pow(1 - t, 2) * at +
      2 * (1 - t) * t * ctrl +
      pow(t, 2) * to

    var
      t: float32       # Where we are at on the curve from [0, 1]
      step = 1.float32 # How far we want to try to move along the curve
      prev = at
      next = compute(at, ctrl, to, t + step)
      halfway = compute(at, ctrl, to, t + step / 2)
      halfStepping = false
    while true:
      if step <= epsilon(float32):
        raise newException(PixieError, "Unable to discretize quadratic")
      let
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).lengthSq
      if error > errorMarginSq:
        next = halfway
        halfway = compute(at, ctrl, to, t + step / 4)
        halfStepping = true
        step /= 2
      else:
        shape.addSegment(prev, next)
        t += step
        if t == 1:
          break
        prev = next
        if halfStepping:
          step = min(step, 1 - t)
        else:
          step = min(step * 2, 1 - t) # Optimistically attempt larger steps
        next = compute(at, ctrl, to, t + step)
        halfway = compute(at, ctrl, to, t + step / 2)

  proc addArc(
    shape: var Polygon,
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

    let arc = endpointToCenterArcParams(at, radii, rotation, large, sweep, to)

    var
      t: float32       # Where we are at on the curve from [0, 1]
      step = 1.float32 # How far we want to try to move along the curve
      prev = at
    while t != 1:
      if step <= epsilon(float32):
        raise newException(PixieError, "Unable to discretize arc")
      let
        aPrev = arc.theta + arc.delta * t
        a = arc.theta + arc.delta * (t + step)
        next = arc.compute(a)
        halfway = arc.compute(aPrev + (a - aPrev) / 2)
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).lengthSq
      if error > errorMarginSq:
        let
          quarterway = arc.compute(aPrev + (a - aPrev) / 4)
          midpoint = (prev + halfway) / 2
          halfwayError = (midpoint - quarterway).lengthSq
        if halfwayError < errorMarginSq:
          shape.addSegment(prev, halfway)
          prev = halfway
          t += step / 2
          step = min(step / 2, 1 - t) # Assume next steps hould be the same size
        else:
          step = step / 4 # We know a half-step is too big
      else:
        shape.addSegment(prev, next)
        prev = next
        t += step
        step = min(step * 2, 1 - t) # Optimistically attempt larger steps

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

proc shapesToSegments(shapes: seq[Polygon]): seq[(Segment, int16)] =
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

      # Quantize the segment to prevent leaks
      segment = segment(
        vec2(segment.at.x.quantize(1 / 256), segment.at.y.quantize(1 / 256)),
        vec2(segment.to.x.quantize(1 / 256), segment.to.y.quantize(1 / 256))
      )

      result.add((segment, winding))

proc transform(shapes: var seq[Polygon], transform: Mat3) =
  if transform != mat3():
    for shape in shapes.mitems:
      for vec in shape.mitems:
        vec = transform * vec

proc computeBounds(segments: seq[(Segment, int16)]): Rect =
  ## Compute the bounds of the segments.
  var
    xMin = float32.high
    xMax = float32.low
    yMin = float32.high
    yMax = float32.low
  for i, (segment, _) in segments:
    xMin = min(xMin, min(segment.at.x, segment.to.x))
    xMax = max(xMax, max(segment.at.x, segment.to.x))
    yMin = min(yMin, segment.at.y)
    yMax = max(yMax, segment.to.y)

  if xMin.isNaN() or xMax.isNaN() or yMin.isNaN() or yMax.isNaN():
    discard
  else:
    result.x = xMin
    result.y = yMin
    result.w = xMax - xMin
    result.h = yMax - yMin

proc computeBounds*(
  path: Path, transform = mat3()
): Rect {.raises: [PixieError].} =
  ## Compute the bounds of the path.
  var shapes = path.commandsToShapes(true, pixelScale(transform))
  shapes.transform(transform)
  computeBounds(shapes.shapesToSegments())

proc initPartitionEntry(segment: Segment, winding: int16): PartitionEntry =
  result.segment = segment
  result.winding = winding
  let d = segment.at.x - segment.to.x
  if d == 0:
    result.b = segment.at.x # Leave m = 0, store the x we want in b
  else:
    result.m = (segment.at.y - segment.to.y) / d
    result.b = segment.at.y - result.m * segment.at.x

proc requiresAntiAliasing(entries: var seq[PartitionEntry]): bool =
  ## Returns true if the fill requires antialiasing.

  template hasFractional(v: float32): bool =
    v - trunc(v) != 0

  for entry in entries:
    if entry.segment.at.x != entry.segment.to.x or
      entry.segment.at.x.hasFractional() or # at.x and to.x are the same
      entry.segment.at.y.hasFractional() or
      entry.segment.to.y.hasFractional():
      # AA is required if all segments are not vertical or have fractional > 0
      return true

proc partitionSegments(
  segments: seq[(Segment, int16)], top, height: int
): Partitioning =
  ## Puts segments into the height partitions they intersect with.
  let
    maxPartitions = max(1, height div 4).uint32
    numPartitions = min(maxPartitions, max(1, segments.len div 2).uint32)

  result.partitions.setLen(numPartitions)
  result.startY = top.uint32
  result.partitionHeight = height.uint32 div numPartitions

  for (segment, winding) in segments:
    let entry = initPartitionEntry(segment, winding)
    if result.partitionHeight == 0:
      result.partitions[0].entries.add(entry)
    else:
      var
        atPartition = max(0, segment.at.y - result.startY.float32).uint32
        toPartition = max(0, segment.to.y - result.startY.float32).uint32
      atPartition = atPartition div result.partitionHeight
      toPartition = toPartition div result.partitionHeight
      atPartition = min(atPartition, result.partitions.high.uint32)
      toPartition = min(toPartition, result.partitions.high.uint32)
      for i in atPartition .. toPartition:
        result.partitions[i].entries.add(entry)

  for partition in result.partitions.mitems:
    partition.requiresAntiAliasing =
      requiresAntiAliasing(partition.entries)

proc maxEntryCount(partitioning: var Partitioning): int =
  for i in 0 ..< partitioning.partitions.len:
    result = max(result, partitioning.partitions[i].entries.len)

proc fixed32(f: float32): Fixed32 {.inline.} =
  Fixed32(f * 256)

proc integer(p: Fixed32): int {.inline.} =
  p div 256

proc trunc(p: Fixed32): Fixed32 {.inline.} =
  (p div 256) * 256

proc sortHits(hits: var seq[(Fixed32, int16)], inl, inr: int) =
  ## Quicksort + insertion sort, in-place and faster than standard lib sort.
  let n = inr - inl + 1
  if n < 32: # Use insertion sort for the rest
    for i in inl + 1 .. inr:
      var
        j = i - 1
        k = i
      while j >= inl and hits[j][0] > hits[k][0]:
        swap(hits[j + 1], hits[j])
        dec j
        dec k
    return
  var
    l = inl
    r = inr
  let p = hits[l + n div 2][0]
  while l <= r:
    if hits[l][0] < p:
      inc l
    elif hits[r][0] > p:
      dec r
    else:
      swap(hits[l], hits[r])
      inc l
      dec r
  sortHits(hits, inl, r)
  sortHits(hits, l, inr)

proc shouldFill(
  windingRule: WindingRule, count: int
): bool {.inline.} =
  ## Should we fill based on the current winding rule and count?
  case windingRule:
  of NonZero:
    count != 0
  of EvenOdd:
    count mod 2 != 0

iterator walk(
  hits: seq[(Fixed32, int16)],
  numHits: int,
  windingRule: WindingRule,
  y: int,
  width: int
): (Fixed32, Fixed32, int) =
  var
    i, count: int
    prevAt: Fixed32
  while i < numHits:
    let (at, winding) = hits[i]
    if at > 0:
      if shouldFill(windingRule, count):
        if i < numHits - 1:
          # Look ahead to see if the next hit is in the same spot as this hit.
          # If it is, see if this hit and the next hit's windings cancel out.
          # If they do, skip the hits. It will be yielded later in a
          # larger chunk.
          let (nextAt, nextWinding) = hits[i + 1]
          if nextAt == at and winding + nextWinding == 0:
            i += 2
            continue
          # Shortcut: we only care about when we stop filling (or the last hit).
          # If we continue filling, move to next hit.
          if windingRule == NonZero and count + winding != 0:
            count += winding
            inc i
            continue
        yield (prevAt, at, count)
      prevAt = at
    count += winding
    inc i

  when defined(pixieLeakCheck):
    if prevAt != width.float32.fixed32 and count != 0:
      echo "Leak detected: ", count, " @ (", prevAt, ", ", y, ")"

proc computeCoverage(
  coverages: ptr UncheckedArray[uint8],
  hits: var seq[(Fixed32, int16)],
  numHits: var int,
  aa: var bool,
  width: int,
  y, startX: int,
  partitioning: var Partitioning,
  windingRule: WindingRule
) {.inline.} =
  let partitionIndex =
    if partitioning.partitions.len == 1:
      0.uint32
    else:
      min(
        (y.uint32 - partitioning.startY) div partitioning.partitionHeight,
        partitioning.partitions.high.uint32
      )

  aa = partitioning.partitions[partitionIndex].requiresAntiAliasing

  let
    quality = if aa: 5 else: 1 # Must divide 255 cleanly (1, 3, 5, 15, 17, 51, 85)
    sampleCoverage = (255 div quality).uint8
    offset = 1 / quality.float32
    initialOffset = offset / 2 + epsilon

  var yLine = y.float32 + initialOffset - offset
  for m in 0 ..< quality:
    yLine += offset
    numHits = 0
    for entry in partitioning.partitions[partitionIndex].entries.mitems:
      if entry.segment.at.y <= yLine and entry.segment.to.y >= yLine:
        let x =
          if entry.m == 0:
            entry.b
          else:
            (yLine - entry.b) / entry.m

        hits[numHits] = (min(x, width.float32).fixed32, entry.winding)
        inc numHits

    if numHits > 0:
      sortHits(hits, 0, numHits - 1)

    if aa:
      for (prevAt, at, count) in hits.walk(numHits, windingRule, y, width):
        var fillStart = prevAt.integer

        let
          pixelCrossed = at.integer != prevAt.integer
          leftCover =
            if pixelCrossed:
              prevAt.trunc + 1.0.fixed32 - prevAt
            else:
              at - prevAt
        if leftCover != 0:
          inc fillStart
          coverages[prevAt.integer - startX] +=
            (leftCover * sampleCoverage.int32).integer.uint8

        if pixelCrossed:
          let rightCover = at - at.trunc
          if rightCover > 0:
            coverages[at.integer - startX] +=
              (rightCover * sampleCoverage.int32).integer.uint8

        let fillLen = at.integer - fillStart
        if fillLen > 0:
          var i = fillStart
          when defined(amd64) and allowSimd:
            let sampleCoverageVec = mm_set1_epi8(cast[int8](sampleCoverage))
            for _ in 0 ..< fillLen div 16:
              var coverageVec = mm_loadu_si128(coverages[i - startX].addr)
              coverageVec = mm_add_epi8(coverageVec, sampleCoverageVec)
              mm_storeu_si128(coverages[i - startX].addr, coverageVec)
              i += 16
          for j in i ..< fillStart + fillLen:
            coverages[j - startX] += sampleCoverage

proc clearUnsafe(target: Image | Mask, startX, startY, toX, toY: int) =
  ## Clears data from [start, to).
  if startX == target.width or startY == target.height:
    return
  let
    start = target.dataIndex(startX, startY)
    len = target.dataIndex(toX, toY) - start
  when type(target) is Image:
    fillUnsafe(target.data, rgbx(0, 0, 0, 0), start, len)
  else: # target is Mask
    fillUnsafe(target.data, 0, start, len)

proc fillCoverage(
  image: Image,
  rgbx: ColorRGBX,
  startX, y: int,
  coverages: seq[uint8],
  blendMode: BlendMode
) =
  var x = startX
  when defined(amd64) and allowSimd:
    if blendMode.hasSimdBlender():
      # When supported, SIMD blend as much as possible
      let
        blenderSimd = blendMode.blenderSimd()
        oddMask = mm_set1_epi16(cast[int16](0xff00))
        div255 = mm_set1_epi16(cast[int16](0x8081))
        vec255 = mm_set1_epi32(cast[int32](uint32.high))
        vecZero = mm_setzero_si128()
        colorVec = mm_set1_epi32(cast[int32](rgbx))
      for _ in 0 ..< coverages.len div 16:
        let
          index = image.dataIndex(x, y)
          coverageVec = mm_loadu_si128(coverages[x - startX].unsafeAddr)

        if mm_movemask_epi8(mm_cmpeq_epi16(coverageVec, vecZero)) != 0xffff:
          # If the coverages are not all zero
          if mm_movemask_epi8(mm_cmpeq_epi32(coverageVec, vec255)) == 0xffff:
            # If the coverages are all 255
            if blendMode == OverwriteBlend:
              for i in 0 ..< 4:
                mm_storeu_si128(image.data[index + i * 4].addr, colorVec)
            elif blendMode == NormalBlend:
              if rgbx.a == 255:
                for i in 0 ..< 4:
                  mm_storeu_si128(image.data[index + i * 4].addr, colorVec)
              else:
                for i in 0 ..< 4:
                  let backdrop = mm_loadu_si128(image.data[index + i * 4].addr)
                  mm_storeu_si128(
                    image.data[index + i * 4].addr,
                    blendNormalSimd(backdrop, colorVec)
                  )
            else:
              for i in 0 ..< 4:
                let backdrop = mm_loadu_si128(image.data[index + i * 4].addr)
                mm_storeu_si128(
                  image.data[index + i * 4].addr,
                  blenderSimd(backdrop, colorVec)
                )
          else:
            # Coverages are not all 255
            template useCoverage(blendProc: untyped) =
              var coverageVec = coverageVec
              for i in 0 ..< 4:
                var unpacked = unpackAlphaValues(coverageVec)
                # Shift the coverages from `a` to `g` and `a` for multiplying
                unpacked = mm_or_si128(unpacked, mm_srli_epi32(unpacked, 16))

                var
                  source = colorVec
                  sourceEven = mm_slli_epi16(source, 8)
                  sourceOdd = mm_and_si128(source, oddMask)

                sourceEven = mm_mulhi_epu16(sourceEven, unpacked)
                sourceOdd = mm_mulhi_epu16(sourceOdd, unpacked)

                sourceEven = mm_srli_epi16(mm_mulhi_epu16(sourceEven, div255), 7)
                sourceOdd = mm_srli_epi16(mm_mulhi_epu16(sourceOdd, div255), 7)

                source = mm_or_si128(sourceEven, mm_slli_epi16(sourceOdd, 8))

                if blendMode == OverwriteBlend:
                  mm_storeu_si128(image.data[index + i * 4].addr, source)
                else:
                  let backdrop = mm_loadu_si128(image.data[index + i * 4].addr)
                  mm_storeu_si128(
                    image.data[index + i * 4].addr,
                    blendProc(backdrop, source)
                  )

                coverageVec = mm_srli_si128(coverageVec, 4)

            if blendMode == NormalBlend:
              useCoverage(blendNormalSimd)
            else:
              useCoverage(blenderSimd)

        elif blendMode == MaskBlend:
          for i in 0 ..< 4:
            mm_storeu_si128(image.data[index + i * 4].addr, vecZero)

        x += 16

  let blender = blendMode.blender()
  for x in x ..< startX + coverages.len:
    let coverage = coverages[x - startX]
    if coverage != 0 or blendMode == ExcludeMaskBlend:
      if blendMode == NormalBlend and coverage == 255 and rgbx.a == 255:
        # Skip blending
        image.unsafe[x, y] = rgbx
        continue

      var source = rgbx
      if coverage != 255:
        source.r = ((source.r.uint32 * coverage) div 255).uint8
        source.g = ((source.g.uint32 * coverage) div 255).uint8
        source.b = ((source.b.uint32 * coverage) div 255).uint8
        source.a = ((source.a.uint32 * coverage) div 255).uint8

      if blendMode == OverwriteBlend:
        image.unsafe[x, y] = source
      else:
        let backdrop = image.unsafe[x, y]
        image.unsafe[x, y] = blender(backdrop, source)
    elif blendMode == MaskBlend:
      image.unsafe[x, y] = rgbx(0, 0, 0, 0)

  if blendMode == MaskBlend:
    image.clearUnsafe(0, y, startX, y)
    image.clearUnsafe(startX + coverages.len, y, image.width, y)

proc fillCoverage(
  mask: Mask,
  startX, y: int,
  coverages: seq[uint8],
  blendMode: BlendMode
) =
  var x = startX
  when defined(amd64) and allowSimd:
    if blendMode.hasSimdMasker():
      let
        maskerSimd = blendMode.maskerSimd()
        vecZero = mm_setzero_si128()
      for _ in 0 ..< coverages.len div 16:
        let
          index = mask.dataIndex(x, y)
          coverageVec = mm_loadu_si128(coverages[x - startX].unsafeAddr)
        if mm_movemask_epi8(mm_cmpeq_epi16(coverageVec, vecZero)) != 0xffff:
          # If the coverages are not all zero
          if blendMode == OverwriteBlend:
            mm_storeu_si128(mask.data[index].addr, coverageVec)
          else:
            let backdrop = mm_loadu_si128(mask.data[index].addr)
            mm_storeu_si128(
              mask.data[index].addr,
              maskerSimd(backdrop, coverageVec)
            )
        elif blendMode == MaskBlend:
          mm_storeu_si128(mask.data[index].addr, vecZero)
        x += 16

  let masker = blendMode.masker()
  for x in x ..< startX + coverages.len:
    let coverage = coverages[x - startX]
    if coverage != 0 or blendMode == ExcludeMaskBlend:
      if blendMode == OverwriteBlend:
        mask.unsafe[x, y] = coverage
      else:
        let backdrop = mask.unsafe[x, y]
        mask.unsafe[x, y] = masker(backdrop, coverage)
    elif blendMode == MaskBlend:
      mask.unsafe[x, y] = 0

  if blendMode == MaskBlend:
    mask.clearUnsafe(0, y, startX, y)
    mask.clearUnsafe(startX + coverages.len, y, mask.width, y)

template walkHits(
  hits: seq[(int32, int16)],
  numHits: int,
  windingRule: WindingRule,
  y, width: int,
  inner: untyped
) =
  for (prevAt, at, count) in hits.walk(numHits, windingRule, y, width):
    let
      fillStart {.inject.} = prevAt.integer
      fillLen {.inject.} = at.integer - fillStart
    if fillLen <= 0:
      continue

    inner

proc fillHits(
  image: Image,
  rgbx: ColorRGBX,
  startX, y: int,
  hits: seq[(Fixed32, int16)],
  numHits: int,
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  template simdBlob(image: Image, x: var int, blendProc: untyped) =
    when allowSimd:
      when defined(amd64):
        let colorVec = mm_set1_epi32(cast[int32](rgbx))
        for _ in 0 ..< fillLen div 4:
          let
            index = image.dataIndex(x, y)
            backdrop = mm_loadu_si128(image.data[index].addr)
          mm_storeu_si128(image.data[index].addr, blendProc(backdrop, colorVec))
          x += 4

  case blendMode:
  of OverwriteBlend:
    walkHits hits, numHits, windingRule, y, image.width:
      fillUnsafe(image.data, rgbx, image.dataIndex(fillStart, y), fillLen)

  of NormalBlend:
    walkHits hits, numHits, windingRule, y, image.width:
      if rgbx.a == 255:
        fillUnsafe(image.data, rgbx, image.dataIndex(fillStart, y), fillLen)
      else:
        var x = fillStart
        simdBlob(image, x, blendNormalSimd)
        for x in x ..< fillStart + fillLen:
          let backdrop = image.unsafe[x, y]
          image.unsafe[x, y] = blendNormal(backdrop, rgbx)

  of MaskBlend:
    var filledTo = startX
    walkHits hits, numHits, windingRule, y, image.width:
      block: # Clear any gap between this fill and the previous fill
        let gapBetween = fillStart - filledTo
        if gapBetween > 0:
          fillUnsafe(
            image.data,
            rgbx(0, 0, 0, 0),
            image.dataIndex(filledTo, y),
            gapBetween
          )
        filledTo = fillStart + fillLen
      block: # Handle this fill
        if rgbx.a != 255:
          var x = fillStart
          simdBlob(image, x, blendMaskSimd)
          for x in x ..< fillStart + fillLen:
            let backdrop = image.unsafe[x, y]
            image.unsafe[x, y] = blendMask(backdrop, rgbx)

    image.clearUnsafe(0, y, startX, y)
    image.clearUnsafe(filledTo, y, image.width, y)

  else:
    let blender = blendMode.blender()
    walkHits hits, numHits, windingRule, y, image.width:
      for x in fillStart ..< fillStart + fillLen:
        let backdrop = image.unsafe[x, y]
        image.unsafe[x, y] = blender(backdrop, rgbx)

proc fillHits(
  mask: Mask,
  startX, y: int,
  hits: seq[(Fixed32, int16)],
  numHits: int,
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  case blendMode:
  of NormalBlend, OverwriteBlend:
    walkHits hits, numHits, windingRule, y, mask.width:
      fillUnsafe(mask.data, 255, mask.dataIndex(fillStart, y), fillLen)

  of MaskBlend:
    var filledTo = startX
    walkHits hits, numHits, windingRule,y,  mask.width:
      let gapBetween = fillStart - filledTo
      if gapBetween > 0:
        fillUnsafe(mask.data, 0, mask.dataIndex(filledTo, y), gapBetween)
      filledTo = fillStart + fillLen

    mask.clearUnsafe(0, y, startX, y)
    mask.clearUnsafe(filledTo, y, mask.width, y)

  of SubtractMaskBlend:
    walkHits hits, numHits, windingRule, y, mask.width:
      for x in fillStart ..< fillStart + fillLen:
        let backdrop = mask.unsafe[x, y]
        mask.unsafe[x, y] = maskBlendSubtract(backdrop, 255)

  of ExcludeMaskBlend:
    walkHits hits, numHits, windingRule, y, mask.width:
      for x in fillStart ..< fillStart + fillLen:
        let backdrop = mask.unsafe[x, y]
        mask.unsafe[x, y] = maskBlendExclude(backdrop, 255)

  else:
    failUnsupportedBlendMode(blendMode)

proc fillShapes(
  image: Image,
  shapes: seq[Polygon],
  color: SomeColor,
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  # Figure out the total bounds of all the shapes,
  # rasterize only within the total bounds
  let
    rgbx = color.asRgbx()
    segments = shapes.shapesToSegments()
    bounds = computeBounds(segments).snapToPixels()
    startX = max(0, bounds.x.int)
    startY = max(0, bounds.y.int)
    pathWidth =
      if startX < image.width:
        min(bounds.w.int, image.width - startX)
      else:
        0
    pathHeight = min(image.height, (bounds.y + bounds.h).int)

  if pathWidth == 0:
    return

  if pathWidth < 0:
    raise newException(PixieError, "Path int overflow detected")

  var
    partitioning = partitionSegments(segments, startY, pathHeight - startY)
    coverages = newSeq[uint8](pathWidth)
    hits = newSeq[(Fixed32, int16)](partitioning.maxEntryCount)
    numHits: int
    aa: bool

  for y in startY ..< pathHeight:
    computeCoverage(
      cast[ptr UncheckedArray[uint8]](coverages[0].addr),
      hits,
      numHits,
      aa,
      image.width,
      y,
      startX,
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
      zeroMem(coverages[0].addr, coverages.len)
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

  if blendMode == MaskBlend:
    image.clearUnsafe(0, 0, 0, startY)
    image.clearUnsafe(0, pathHeight, 0, image.height)

proc fillShapes(
  mask: Mask,
  shapes: seq[Polygon],
  windingRule: WindingRule,
  blendMode: BlendMode
) =
  # Figure out the total bounds of all the shapes,
  # rasterize only within the total bounds
  let
    segments = shapes.shapesToSegments()
    bounds = computeBounds(segments).snapToPixels()
    startX = max(0, bounds.x.int)
    startY = max(0, bounds.y.int)
    pathWidth =
      if startX < mask.width:
        min(bounds.w.int, mask.width - startX)
      else:
        0
    pathHeight = min(mask.height, (bounds.y + bounds.h).int)

  if pathWidth == 0:
    return

  if pathWidth < 0:
    raise newException(PixieError, "Path int overflow detected")

  var
    partitioning = partitionSegments(segments, startY, pathHeight)
    coverages = newSeq[uint8](pathWidth)
    hits = newSeq[(Fixed32, int16)](partitioning.maxEntryCount)
    numHits: int
    aa: bool

  for y in startY ..< pathHeight:
    computeCoverage(
      cast[ptr UncheckedArray[uint8]](coverages[0].addr),
      hits,
      numHits,
      aa,
      mask.width,
      y,
      startX,
      partitioning,
      windingRule
    )
    if aa:
      mask.fillCoverage(startX, y, coverages, blendMode)
      zeroMem(coverages[0].addr, coverages.len)
    else:
      mask.fillHits(startX, y, hits, numHits, windingRule, blendMode)

  if blendMode == MaskBlend:
    mask.clearUnsafe(0, 0, 0, startY)
    mask.clearUnsafe(0, pathHeight, 0, mask.height)

proc miterLimitToAngle*(limit: float32): float32 {.inline.} =
  ## Converts miter-limit-ratio to miter-limit-angle.
  arcsin(1 / limit) * 2

proc angleToMiterLimit*(angle: float32): float32 {.inline.} =
  ## Converts miter-limit-angle to miter-limit-ratio.
  1 / sin(angle / 2)

proc strokeShapes(
  shapes: seq[Polygon],
  strokeWidth: float32,
  lineCap: LineCap,
  lineJoin: LineJoin,
  miterLimit: float32,
  dashes: seq[float32],
  pixelScale: float32
): seq[Polygon] =
  if strokeWidth <= 0:
    return

  let
    halfStroke = strokeWidth / 2
    miterAngleLimit = miterLimitToAngle(miterLimit)

  proc makeCircle(at: Vec2): Polygon =
    let path = newPath()
    path.ellipse(at, halfStroke, halfStroke)
    path.commandsToShapes(true, pixelScale)[0]

  proc makeRect(at, to: Vec2): Polygon =
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

  proc addJoin(shape: var seq[Polygon], prevPos, pos, nextPos: Vec2) =
    let minArea = pixelErrorMargin / pixelScale

    if lineJoin == RoundJoin:
      let area = PI.float32 * halfStroke * halfStroke
      if area > minArea:
        shape.add makeCircle(pos)
      return

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
      if lineJoin == MiterJoin and abs(angle) < miterAngleLimit:
        lineJoin = BevelJoin

      case lineJoin:
      of MiterJoin:
        let
          la = line(prevPos + a, pos + a)
          lb = line(nextPos + b, pos + b)
        var at: Vec2
        if la.intersects(lb, at):
          let
            bisectorLengthSq = (at - pos).lengthSq
            areaSq = 0.25.float32 * (
              a.lengthSq * bisectorLengthSq + b.lengthSq * bisectorLengthSq
            )
          if areaSq > (minArea * minArea):
            shape.add @[pos + a, at, pos + b, pos, pos + a]

      of BevelJoin:
        let areaSq = 0.25.float32 * a.lengthSq * b.lengthSq
        if areaSq > (minArea * minArea):
          shape.add @[a + pos, b + pos, pos, a + pos]

      of RoundJoin:
        discard # Handled above, skipping angle calculation

  for shape in shapes:
    var shapeStroke: seq[Polygon]

    if shape[0] != shape[^1]:
      # This shape does not end at the same point it starts so draw the
      # first line cap.
      case lineCap:
      of ButtCap:
        discard
      of RoundCap:
        shapeStroke.add(makeCircle(shape[0]))
      of SquareCap:
        let tangent = (shape[1] - shape[0]).normalize()
        shapeStroke.add(makeRect(
          shape[0] - tangent * halfStroke,
          shape[0]
        ))

    var dashes = dashes
    if dashes.len mod 2 != 0:
      dashes.add(dashes)
    # Make sure gaps and dashes are more then zero, otherwise it will hang.
    for d in dashes:
      if d <= 0.0:
        raise newException(PixieError, "Invalid line dash value")

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
        shapeStroke.addJoin(prevPos, pos, shape[i + 1])

    if shape[0] == shape[^1]:
      shapeStroke.addJoin(shape[^2], shape[^1], shape[1])
    else:
      case lineCap:
      of ButtCap:
        discard
      of RoundCap:
        shapeStroke.add(makeCircle(shape[^1]))
      of SquareCap:
        let tangent = (shape[^1] - shape[^2]).normalize()
        shapeStroke.add(makeRect(
          shape[^1] + tangent * halfStroke,
          shape[^1]
        ))

    result.add(shapeStroke)

proc parseSomePath(
  path: SomePath, closeSubpaths: bool, pixelScale: float32
): seq[Polygon] {.inline.} =
  ## Given SomePath, parse it in different ways.
  when type(path) is string:
    parsePath(path).commandsToShapes(closeSubpaths, pixelScale)
  elif type(path) is Path:
    path.commandsToShapes(closeSubpaths, pixelScale)

proc fillPath*(
  mask: Mask,
  path: SomePath,
  transform = mat3(),
  windingRule = NonZero,
  blendMode = NormalBlend
) {.raises: [PixieError].} =
  ## Fills a path.
  var shapes = parseSomePath(path, true, transform.pixelScale())
  shapes.transform(transform)
  mask.fillShapes(shapes, windingRule, blendMode)

proc fillPath*(
  image: Image,
  path: SomePath,
  paint: Paint,
  transform = mat3(),
  windingRule = NonZero
) {.raises: [PixieError].} =
  ## Fills a path.
  paint.opacity = clamp(paint.opacity, 0, 1)

  if paint.opacity == 0:
    return

  if paint.kind == SolidPaint:
    if paint.color.a > 0 or paint.blendMode == OverwriteBlend:
      var shapes = parseSomePath(path, true, transform.pixelScale())
      shapes.transform(transform)
      var color = paint.color
      color.a *= paint.opacity
      image.fillShapes(shapes, color, windingRule, paint.blendMode)
    return

  let
    mask = newMask(image.width, image.height)
    fill = newImage(image.width, image.height)

  mask.fillPath(path, transform, windingRule)

  # Draw the image (maybe tiled) or gradients. Do this with opaque paint and
  # and then apply the paint's opacity to the mask.
  let savedOpacity = paint.opacity
  paint.opacity = 1

  case paint.kind:
    of SolidPaint:
      discard # Handled above
    of ImagePaint:
      fill.draw(paint.image, paint.imageMat)
    of TiledImagePaint:
      fill.drawTiled(paint.image, paint.imageMat)
    of LinearGradientPaint, RadialGradientPaint, AngularGradientPaint:
      fill.fillGradient(paint)

  paint.opacity = savedOpacity

  if paint.opacity != 1:
    mask.applyOpacity(paint.opacity)

  fill.draw(mask)
  image.draw(fill, blendMode = paint.blendMode)

proc strokePath*(
  mask: Mask,
  path: SomePath,
  transform = mat3(),
  strokeWidth: float32 = 1.0,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[],
  blendMode = NormalBlend
) {.raises: [PixieError].} =
  ## Strokes a path.
  let pixelScale = transform.pixelScale()
  var strokeShapes = strokeShapes(
    parseSomePath(path, false, pixelScale),
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes,
    pixelScale
  )
  strokeShapes.transform(transform)
  mask.fillShapes(strokeShapes, NonZero, blendMode)

proc strokePath*(
  image: Image,
  path: SomePath,
  paint: Paint,
  transform = mat3(),
  strokeWidth: float32 = 1.0,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[]
) {.raises: [PixieError].} =
  ## Strokes a path.
  paint.opacity = clamp(paint.opacity, 0, 1)

  if paint.opacity == 0:
    return

  if paint.kind == SolidPaint:
    if paint.color.a > 0 or paint.blendMode == OverwriteBlend:
      var strokeShapes = strokeShapes(
        parseSomePath(path, false, transform.pixelScale()),
        strokeWidth,
        lineCap,
        lineJoin,
        miterLimit,
        dashes,
        pixelScale(transform)
      )
      strokeShapes.transform(transform)
      var color = paint.color
      color.a *= paint.opacity
      image.fillShapes(strokeShapes, color, NonZero, paint.blendMode)
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

  # Draw the image (maybe tiled) or gradients. Do this with opaque paint and
  # and then apply the paint's opacity to the mask.
  let savedOpacity = paint.opacity
  paint.opacity = 1

  case paint.kind:
    of SolidPaint:
      discard # Handled above
    of ImagePaint:
      fill.draw(paint.image, paint.imageMat)
    of TiledImagePaint:
      fill.drawTiled(paint.image, paint.imageMat)
    of LinearGradientPaint, RadialGradientPaint, AngularGradientPaint:
      fill.fillGradient(paint)

  paint.opacity = savedOpacity

  if paint.opacity != 1:
    mask.applyOpacity(paint.opacity)

  fill.draw(mask)
  image.draw(fill, blendMode = paint.blendMode)

proc overlaps(
  shapes: seq[Polygon],
  test: Vec2,
  windingRule: WindingRule
): bool =
  var hits: seq[(Fixed32, int16)]

  let
    scanline = line(vec2(0, test.y), vec2(1000, test.y))
    segments = shapes.shapesToSegments()
  for (segment, winding) in segments:
    if segment.at.y <= scanline.a.y and segment.to.y >= scanline.a.y:
      var at: Vec2
      if scanline.intersects(segment, at):
        if segment.to != at:
          hits.add((at.x.fixed32, winding))

  sortHits(hits, 0, hits.high)

  let testX = test.x.fixed32

  var count: int
  for (at, winding) in hits:
    if at > testX:
      return shouldFill(windingRule, count)
    count += winding

proc fillOverlaps*(
  path: Path,
  test: Vec2,
  transform = mat3(), ## Applied to the path, not the test point.
  windingRule = NonZero
): bool {.raises: [PixieError].} =
  ## Returns whether or not the specified point is contained in the current path.
  var shapes = path.commandsToShapes(true, transform.pixelScale())
  shapes.transform(transform)
  shapes.overlaps(test, windingRule)

proc strokeOverlaps*(
  path: Path,
  test: Vec2,
  transform = mat3(), ## Applied to the path, not the test point.
  strokeWidth: float32 = 1.0,
  lineCap = ButtCap,
  lineJoin = MiterJoin,
  miterLimit = defaultMiterLimit,
  dashes: seq[float32] = @[],
): bool {.raises: [PixieError].} =
  ## Returns whether or not the specified point is inside the area contained
  ## by the stroking of a path.
  let pixelScale = transform.pixelScale()
  var strokeShapes = strokeShapes(
    path.commandsToShapes(false, pixelScale),
    strokeWidth,
    lineCap,
    lineJoin,
    miterLimit,
    dashes,
    pixelScale
  )
  strokeShapes.transform(transform)
  strokeShapes.overlaps(test, NonZero)

when defined(release):
  {.pop.}
