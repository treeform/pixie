import blends, bumpy, chroma, common, images, internal, paints, simd, std/fenv,
    std/strutils, vmath

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

  Path* = ref object
    ## Used to hold paths and create paths.
    commands: seq[float32]
    start, at: Vec2 # Maintained by moveTo, lineTo, etc. Used by arcTo.

  SomePath* = Path | string

  PartitionEntry = object
    segment: Segment
    m, b: float32
    winding: int16

  Partition = object
    entries: seq[PartitionEntry]
    requiresAntiAliasing, twoNonintersectingSpanningSegments: bool
    top, bottom: int

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

proc copy*(path: Path): Path {.raises: [].} =
  result = Path()
  result.commands = path.commands
  result.start = path.start
  result.at = path.at

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
  var i: int
  while i < path.commands.len:
    let kind = path.commands[i].PathCommandKind
    inc i
    case kind
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
    for _ in 0 ..< kind.parameterCount():
      let number = path.commands[i]
      if floor(number) == number:
        result.add $number.int
      else:
        result.add $number
      if i != path.commands.len - 1:
        result.add " "
      inc i

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
        result.commands.add(kind.float32)
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
          result.commands.add(kind.float32)
          for i in 0 ..< paramCount:
            result.commands.add(numbers[batch * paramCount + i])
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

  if path.commands.len > 0 and path.commands[0] == RMove.float32:
    path.commands[0] = Move.float32

  var i: int
  while i < path.commands.len:
    let kind = path.commands[i].PathCommandKind
    inc i

    var mat = mat
    if kind.isRelative():
      mat.pos = vec2(0)

    case kind:
    of Close:
      discard
    of Move, Line, RMove, RLine, TQuad, RTQuad:
      var pos = vec2(path.commands[i + 0], path.commands[i + 1])
      pos = mat * pos
      path.commands[i + 0] = pos.x
      path.commands[i + 1] = pos.y
    of HLine, RHLine:
      var pos = vec2(path.commands[i + 0], 0)
      pos = mat * pos
      path.commands[i + 0] = pos.x
    of VLine, RVLine:
      var pos = vec2(0, path.commands[i + 0])
      pos = mat * pos
      path.commands[i + 0] = pos.y
    of Cubic, RCubic:
      var
        ctrl1 = vec2(path.commands[i + 0], path.commands[i + 1])
        ctrl2 = vec2(path.commands[i + 2], path.commands[i + 3])
        to = vec2(path.commands[i + 4], path.commands[i + 5])
      ctrl1 = mat * ctrl1
      ctrl2 = mat * ctrl2
      to = mat * to
      path.commands[i + 0] = ctrl1.x
      path.commands[i + 1] = ctrl1.y
      path.commands[i + 2] = ctrl2.x
      path.commands[i + 3] = ctrl2.y
      path.commands[i + 4] = to.x
      path.commands[i + 5] = to.y
    of SCubic, RSCubic, Quad, RQuad:
      var
        ctrl = vec2(path.commands[i + 0], path.commands[i + 1])
        to = vec2(path.commands[i + 2], path.commands[i + 3])
      ctrl = mat * ctrl
      to = mat * to
      path.commands[i + 0] = ctrl.x
      path.commands[i + 1] = ctrl.y
      path.commands[i + 2] = to.x
      path.commands[i + 3] = to.y
    of Arc, RArc:
      var
        radii = vec2(path.commands[i + 0], path.commands[i + 1])
        to = vec2(path.commands[i + 5], path.commands[i + 6])
      # Extract the scale from the matrix and only apply that to the radii
      radii = scale(vec2(mat[0, 0], mat[1, 1])) * radii
      to = mat * to
      path.commands[i + 0] = radii.x
      path.commands[i + 1] = radii.y
      path.commands[i + 5] = to.x
      path.commands[i + 6] = to.y

    i += kind.parameterCount()

proc addPath*(path: Path, other: Path) {.raises: [].} =
  ## Adds a path to the current path.
  path.commands.add(other.commands)

proc closePath*(path: Path) {.raises: [].} =
  ## Attempts to add a straight line from the current point to the start of
  ## the current sub-path. If the shape has already been closed or has only
  ## one point, this function does nothing.
  path.commands.add(Close.float32)
  path.at = path.start

proc moveTo*(path: Path, x, y: float32) {.raises: [].} =
  ## Begins a new sub-path at the point (x, y).
  path.commands.add(@[Move.float32, x, y])
  path.start = vec2(x, y)
  path.at = path.start

proc moveTo*(path: Path, v: Vec2) {.inline, raises: [].} =
  ## Begins a new sub-path at the point (x, y).
  path.moveTo(v.x, v.y)

proc lineTo*(path: Path, x, y: float32) {.raises: [].} =
  ## Adds a straight line to the current sub-path by connecting the sub-path's
  ## last point to the specified (x, y) coordinates.
  path.commands.add(@[Line.float32, x, y])
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
  path.commands.add(@[Cubic.float32, x1, y1, x2, y2, x3, y3])
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
  path.commands.add(@[Quad.float32, x1, y1, x2, y2])
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
  path.commands.add(@[
    Arc.float32,
    rx, ry,
    xAxisRotation, largeArcFlag.float32, sweepFlag.float32,
    x, y
  ])
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
      let
        t2 = t*t
        t3 = t2*t
      at * (-t3 + 3*t2 - 3*t + 1) +
      ctrl1 * (3*t3 - 6*t2 + 3*t) +
      ctrl2 * (-3*t3 + 3*t2) +
      to * (t3)

    proc computeDeriv(at, ctrl1, ctrl2, to: Vec2, t: float32): Vec2 {.inline.} =
      let t2 = t*t
      at * (-3*t2 + 6*t - 3) +
      ctrl1 * (9*t2 - 12*t + 3) +
      ctrl2 * (-9*t2 + 6*t) +
      to * (3 * t2)

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
        lineTangent = midpoint - prev
        curveTangent = computeDeriv(at, ctrl1, ctrl2, to, t + step / 2)
        curveTangentScaled = curveTangent.normalize() * lineTangent.length()
        error = (midpoint - halfway).lengthSq
        errorTangent = (lineTangent - curveTangentScaled).lengthSq
      if error + errorTangent > errorMarginSq:
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
      let t2 = t*t
      at * (t2 - 2*t + 1) +
      ctrl * (-2*t2 + 2*t) +
      to * t2

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

  var i: int
  while i < path.commands.len:
    let kind = path.commands[i].PathCommandKind
    inc i

    case kind:
    of Move:
      if shape.len > 0:
        if closeSubpaths:
          shape.addSegment(at, start)
        result.add(shape)
        shape = newSeq[Vec2]()
      at.x = path.commands[i + 0]
      at.y = path.commands[i + 1]
      start = at

    of Line:
      let to = vec2(path.commands[i + 0], path.commands[i + 1])
      shape.addSegment(at, to)
      at = to

    of HLine:
      let to = vec2(path.commands[i + 0], at.y)
      shape.addSegment(at, to)
      at = to

    of VLine:
      let to = vec2(at.x, path.commands[i + 0])
      shape.addSegment(at, to)
      at = to

    of Cubic:
      let
        ctrl1 = vec2(path.commands[i + 0], path.commands[i + 1])
        ctrl2 = vec2(path.commands[i + 2], path.commands[i + 3])
        to = vec2(path.commands[i + 4], path.commands[i + 5])
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of SCubic:
      let
        ctrl2 = vec2(path.commands[i + 0], path.commands[i + 1])
        to = vec2(path.commands[i + 2], path.commands[i + 3])
      if prevCommandKind in {Cubic, SCubic, RCubic, RSCubic}:
        let ctrl1 = at * 2 - prevCtrl2
        shape.addCubic(at, ctrl1, ctrl2, to)
      else:
        shape.addCubic(at, at, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of Quad:
      let
        ctrl = vec2(path.commands[i + 0], path.commands[i + 1])
        to = vec2(path.commands[i + 2], path.commands[i + 3])
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of TQuad:
      let
        to = vec2(path.commands[i + 0], path.commands[i + 1])
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
        radii = vec2(path.commands[i + 0], path.commands[i + 1])
        rotation = path.commands[i + 2]
        large = path.commands[i + 3] == 1
        sweep = path.commands[i + 4] == 1
        to = vec2(path.commands[i + 5], path.commands[i + 6])
      shape.addArc(at, radii, rotation, large, sweep, to)
      at = to

    of RMove:
      if shape.len > 0:
        result.add(shape)
        shape = newSeq[Vec2]()
      at.x += path.commands[i + 0]
      at.y += path.commands[i + 1]
      start = at

    of RLine:
      let to = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
      shape.addSegment(at, to)
      at = to

    of RHLine:
      let to = vec2(at.x + path.commands[i + 0], at.y)
      shape.addSegment(at, to)
      at = to

    of RVLine:
      let to = vec2(at.x, at.y + path.commands[i + 0])
      shape.addSegment(at, to)
      at = to

    of RCubic:
      let
        ctrl1 = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
        ctrl2 = vec2(at.x + path.commands[i + 2], at.y + path.commands[i + 3])
        to = vec2(at.x + path.commands[i + 4], at.y + path.commands[i + 5])
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of RSCubic:
      let
        ctrl2 = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
        to = vec2(at.x + path.commands[i + 2], at.y + path.commands[i + 3])
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
        ctrl = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
        to = vec2(at.x + path.commands[i + 2], at.y + path.commands[i + 3])
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of RTQuad:
      let
        to = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
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
        radii = vec2(path.commands[i + 0], path.commands[i + 1])
        rotation = path.commands[i + 2]
        large = path.commands[i + 3] == 1
        sweep = path.commands[i + 4] == 1
        to = vec2(at.x + path.commands[i + 5], at.y + path.commands[i + 6])
      shape.addArc(at, radii, rotation, large, sweep, to)
      at = to

    of Close:
      if at != start:
        shape.addSegment(at, start)
        at = start
      if shape.len > 0:
        result.add(shape)
        shape = newSeq[Vec2]()

    i += kind.parameterCount()
    prevCommandKind = kind

  if shape.len > 0:
    if closeSubpaths:
      shape.addSegment(at, start)
    result.add(shape)

proc shapesToSegments(shapes: seq[Polygon]): seq[(Segment, int16)] =
  ## Converts the shapes into a set of filtered segments with winding value.

  # Quantize the segment to prevent leaks
  template quantizeY(v: Vec2): Vec2 =
    vec2(v.x, v.y.quantize(1 / 256))

  for poly in shapes:
    var
      vec1 = poly[^1].quantizeY()
      vec2: Vec2
      segment: Segment
    for i in 0 ..< poly.len:
      vec2 = poly[i].quantizeY()
      if i == 0 and vec1 == vec2:
        continue
      segment = segment(vec1, vec2)
      vec1 = vec2

      if segment.at.y == segment.to.y: # Skip horizontal
        continue
      var
        segment = segment
        winding = 1.int16
      if segment.at.y > segment.to.y:
        swap(segment.at, segment.to)
        winding = -1

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

proc solveX(entry: PartitionEntry, y: float32): float32 {.inline.} =
  if entry.m == 0:
    entry.b
  else:
    (y - entry.b) / entry.m

proc solveY(entry: PartitionEntry, x: float32): float32 {.inline.} =
  entry.m * x + entry.b

proc midpointX(segment: Segment): float32 {.inline.} =
  (segment.at.x + segment.to.x) * 0.5

proc requiresAntiAliasing(segment: Segment): bool {.inline.} =
  ## Returns true if the segment requires antialiasing.

  template hasFractional(v: float32): bool =
    v - trunc(v) != 0

  if segment.at.x != segment.to.x or
    segment.at.x.hasFractional() or # at.x and to.x are the same
    segment.at.y.hasFractional() or
    segment.to.y.hasFractional():
    # AA is required if all segments are not vertical or have fractional > 0
    return true

proc requiresAntiAliasing(entries: var seq[PartitionEntry]): bool =
  ## Returns true if the fill requires antialiasing.
  for entry in entries:
    if entry.segment.requiresAntiAliasing:
      return true

proc partitionSegments(
  segments: seq[(Segment, int16)], top, height: int
): seq[Partition] =
  ## Puts segments into the height partitions they intersect with.
  let
    maxPartitions = max(1, height div 4).uint32
    numPartitions = min(maxPartitions, max(1, segments.len div 2).uint32)

  result.setLen(numPartitions)

  let
    startY = top.uint32
    partitionHeight = height.uint32 div numPartitions

  # Set the bottom values for the partitions (y value where this partition ends)
  result[0].top = top
  result[0].bottom = top + partitionHeight.int
  for i in 1 ..< result.len:
    result[i].top = result[i - 1].bottom
    result[i].bottom = result[i - 1].bottom + partitionHeight.int

  # Ensure the final partition goes to the actual bottom
  # This is needed since the final partition includes
  # height - (height div numPartitions) * numPartitions
  result[^1].bottom = top + height

  var entries = newSeq[PartitionEntry](segments.len)
  for i, (segment, winding) in segments:
    entries[i] = initPartitionEntry(segment, winding)

  if numPartitions == 1:
    result[0].entries = move entries
  else:
    iterator partitionRange(
      segment: Segment,
      numPartitions, startY, partitionHeight: uint32
    ): uint32 =
      var
        atPartition = max(0, segment.at.y - startY.float32).uint32
        toPartition = max(0, segment.to.y - startY.float32).uint32
      atPartition = atPartition div partitionHeight
      toPartition = toPartition div partitionHeight
      atPartition = min(atPartition, numPartitions - 1)
      toPartition = min(toPartition, numPartitions - 1)
      for partitionIndex in atPartition .. toPartition:
        yield partitionIndex

    var entryCounts = newSeq[int](numPartitions)
    for (segment, _) in segments:
      for partitionIndex in segment.partitionRange(
        numPartitions, startY, partitionHeight
      ):
        inc entryCounts[partitionIndex]

    for partitionIndex, entryCounts in entryCounts:
      result[partitionIndex].entries.setLen(entryCounts)

    var indexes = newSeq[int](numPartitions)
    for i, (segment, winding) in segments:
      for partitionIndex in segment.partitionRange(
        numPartitions, startY, partitionHeight
      ):
        result[partitionIndex].entries[indexes[partitionIndex]] = entries[i]
        inc indexes[partitionIndex]

  for partition in result.mitems:
    partition.requiresAntiAliasing = requiresAntiAliasing(partition.entries)

    # Clip the entries to the parition bounds
    let
      top = partition.top.float32
      bottom = partition.bottom.float32
      topLine = line(vec2(0, top), vec2(1000, top))
      bottomLine = line(vec2(0, bottom), vec2(1000, bottom))
    for entry in partition.entries.mitems:
      if entry.segment.at.y <= top and entry.segment.to.y >= bottom:
        var at: Vec2
        discard intersects(entry.segment, topLine, at)
        entry.segment.at = at
        discard intersects(entry.segment, bottomLine, at)
        entry.segment.to = at

    if partition.entries.len == 2:
      let
        entry0 = partition.entries[0].segment
        entry1 = partition.entries[1].segment
      var at: Vec2
      if not intersectsInside(entry0, entry1, at):
        if entry0.at.y <= top and entry0.to.y >= bottom and
          entry1.at.y <= top and entry1.to.y >= bottom:
          # These two segments do not intersect and span the partition
          partition.twoNonintersectingSpanningSegments = true
          # Ensure entry[0] is on the left
          if entry0.midpointX > entry1.midpointX:
            swap partition.entries[1], partition.entries[0]

proc maxEntryCount(partitions: var seq[Partition]): int =
  for i in 0 ..< partitions.len:
    result = max(result, partitions[i].entries.len)

proc fixed32(f: float32): Fixed32 {.inline.} =
  Fixed32(f * 256)

proc integer(p: Fixed32): int {.inline.} =
  p div 256

proc trunc(p: Fixed32): Fixed32 {.inline.} =
  (p div 256) * 256

proc sortHits(hits: var seq[(Fixed32, int16)], len: int) {.inline.} =
  ## Insertion sort
  for i in 1 ..< len:
    var
      j = i - 1
      k = i
    while j >= 0 and hits[j][0] > hits[k][0]:
      swap(hits[j + 1], hits[j])
      dec j
      dec k

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

iterator walkInteger(
  hits: seq[(int32, int16)],
  numHits: int,
  windingRule: WindingRule,
  y, width: int
): (int, int) =
  for (prevAt, at, count) in hits.walk(numHits, windingRule, y, width):
    let
      fillStart = prevAt.integer
      fillLen = at.integer - fillStart
    if fillLen <= 0:
      continue
    yield (fillStart, fillLen)

proc computeCoverage(
  coverages: ptr UncheckedArray[uint8],
  hits: var seq[(Fixed32, int16)],
  numHits: var int,
  width: int,
  y, startX: int,
  partitions: var seq[Partition],
  partitionIndex: int,
  entryIndices: seq[int],
  numEntryIndices: int,
  windingRule: WindingRule
) {.inline.} =
  let
    aa = partitions[partitionIndex].requiresAntiAliasing
    quality = if aa: 5 else: 1 # Must divide 255 cleanly (1, 3, 5, 15, 17, 51, 85)
    sampleCoverage = (255 div quality).uint8
    offset = 1 / quality.float32
    initialOffset = offset / 2 + epsilon

  var yLine = y.float32 + initialOffset - offset
  for m in 0 ..< quality:
    yLine += offset
    numHits = 0
    for i in 0 ..< numEntryIndices:
      let
        entryIndex = entryIndices[i]
        entry = partitions[partitionIndex].entries[entryIndex].addr
      if entry.segment.at.y <= yLine and entry.segment.to.y >= yLine:
        let x =
          if entry.m == 0:
            entry.b
          else:
            (yLine - entry.b) / entry.m

        hits[numHits] = (min(x, width.float32).fixed32, entry.winding)
        inc numHits

    if numHits > 0:
      sortHits(hits, numHits)

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
          when allowSimd:
            when defined(amd64):
              let sampleCoverageVec = mm_set1_epi8(sampleCoverage)
              for _ in 0 ..< fillLen div 16:
                var coverageVec = mm_loadu_si128(coverages[i - startX].addr)
                coverageVec = mm_add_epi8(coverageVec, sampleCoverageVec)
                mm_storeu_si128(coverages[i - startX].addr, coverageVec)
                i += 16
            elif defined(arm64):
              let sampleCoverageVec = vmovq_n_u8(sampleCoverage)
              for _ in 0 ..< fillLen div 16:
                var coverageVec = vld1q_u8(coverages[i - startX].addr)
                coverageVec = vaddq_u8(coverageVec, sampleCoverageVec)
                vst1q_u8(coverages[i - startX].addr, coverageVec)
                i += 16
          for j in i ..< fillStart + fillLen:
            coverages[j - startX] += sampleCoverage

proc clearUnsafe(image: Image, startX, startY, toX, toY: int) =
  ## Clears data from [start, to).
  if startX == image.width or startY == image.height:
    return
  let
    start = image.dataIndex(startX, startY)
    len = image.dataIndex(toX, toY) - start
  fillUnsafe(image.data, rgbx(0, 0, 0, 0), start, len)

proc blendLineCoverageOverwrite(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
 ) {.hasSimd.} =
  for i in 0 ..< len:
    let coverage = coverages[i]
    if coverage != 0:
      line[i] = rgbx * coverage

proc blendLineCoverageNormal(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.hasSimd.} =
  for i in 0 ..< len:
    let coverage = coverages[i]
    if coverage == 0:
      discard
    else:
      line[i] = blendNormal(line[i], rgbx * coverage)

proc blendLineCoverageMask(
  line: ptr UncheckedArray[ColorRGBX],
  coverages: ptr UncheckedArray[uint8],
  rgbx: ColorRGBX,
  len: int
) {.hasSimd.} =
  for i in 0 ..< len:
    let coverage = coverages[i]
    if coverage == 255:
      discard
    else:
      line[i] = blendMask(line[i], rgbx * coverage)

proc fillCoverage(
  image: Image,
  rgbx: ColorRGBX,
  startX, y: int,
  coverages: seq[uint8],
  blendMode: BlendMode
) =
  var
    x = startX
    dataIndex = image.dataIndex(x, y)

  case blendMode:
  of OverwriteBlend:
    blendLineCoverageOverwrite(
      image.getUncheckedArray(startX, y),
      cast[ptr UncheckedArray[uint8]](coverages[0].unsafeAddr),
      rgbx,
      coverages.len
    )

  of NormalBlend:
    blendLineCoverageNormal(
      image.getUncheckedArray(startX, y),
      cast[ptr UncheckedArray[uint8]](coverages[0].unsafeAddr),
      rgbx,
      coverages.len
    )

  of MaskBlend:
    {.linearScanEnd.}
    blendLineCoverageMask(
      image.getUncheckedArray(startX, y),
      cast[ptr UncheckedArray[uint8]](coverages[0].unsafeAddr),
      rgbx,
      coverages.len
    )

    image.clearUnsafe(0, y, startX, y)
    image.clearUnsafe(startX + coverages.len, y, image.width, y)

  else:
    let blender = blendMode.blender()
    for x in x ..< startX + coverages.len:
      let coverage = coverages[x - startX]
      if coverage != 0:
        let backdrop = image.data[dataIndex]
        image.data[dataIndex] = blender(backdrop, rgbx * coverage)
      inc dataIndex

proc blendLineNormal(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.hasSimd.} =
  for i in 0 ..< len:
    line[i] = blendNormal(line[i], rgbx)

proc blendLineMask(
  line: ptr UncheckedArray[ColorRGBX], rgbx: ColorRGBX, len: int
) {.hasSimd.} =
  for i in 0 ..< len:
    line[i] = blendMask(line[i], rgbx)

proc fillHits(
  image: Image,
  rgbx: ColorRGBX,
  startX, y: int,
  hits: seq[(Fixed32, int16)],
  numHits: int,
  windingRule: WindingRule,
  blendMode: BlendMode,
  maskClears = true
) =
  case blendMode:
  of OverwriteBlend:
    for (start, len) in hits.walkInteger(numHits, windingRule, y, image.width):
      fillUnsafe(image.data, rgbx, image.dataIndex(start, y), len)

  of NormalBlend:
    for (start, len) in hits.walkInteger(numHits, windingRule, y, image.width):
      if rgbx.a == 255:
        fillUnsafe(image.data, rgbx, image.dataIndex(start, y), len)
      else:
        blendLineNormal(image.getUncheckedArray(start, y), rgbx, len)

  of MaskBlend:
    {.linearScanEnd.}
    var filledTo = startX
    for (start, len) in hits.walkInteger(numHits, windingRule, y, image.width):
      if maskClears: # Clear any gap between this fill and the previous fill
        let gapBetween = start - filledTo
        if gapBetween > 0:
          fillUnsafe(
            image.data,
            rgbx(0, 0, 0, 0),
            image.dataIndex(filledTo, y),
            gapBetween
          )
      block: # Handle this fill
        if rgbx.a != 255:
          blendLineMask(image.getUncheckedArray(start, y), rgbx, len)
        filledTo = start + len

    if maskClears:
      image.clearUnsafe(0, y, startX, y)
      image.clearUnsafe(filledTo, y, image.width, y)

  else:
    let blender = blendMode.blender()
    for (start, len) in hits.walkInteger(numHits, windingRule, y, image.width):
      var dataIndex = image.dataIndex(start, y)
      for _ in 0 ..< len:
        let backdrop = image.data[dataIndex]
        image.data[dataIndex] = blender(backdrop, rgbx)
        inc dataIndex

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
    partitions = partitionSegments(segments, startY, pathHeight - startY)
    partitionIndex: int
    entryIndices = newSeq[int](partitions.maxEntryCount)
    numEntryIndices: int
    trapezoidSegments = newSeq[Segment](entryIndices.len)
    coverages = newSeq[uint8](pathWidth)
    hits = newSeq[(Fixed32, int16)](entryIndices.len)
    numHits: int

  var y = startY
  while y < pathHeight:
    if y >= partitions[partitionIndex].bottom:
      inc partitionIndex

    let
      partition = partitions[partitionIndex].addr
      partitionTop = partition.top
      partitionBottom = partition.bottom
      partitionHeight = partitionBottom - partitionTop
    if partitionHeight == 0:
      continue

    if partition.twoNonintersectingSpanningSegments:
      if not partition.requiresAntiAliasing:
        # No AA required, must be 2 vertical pixel-aligned lines
        let
          left = partition.entries[0].segment.at.x.int
          right = partition.entries[1].segment.at.x.int
          minX = left.clamp(0, image.width)
          maxX = right.clamp(0, image.width)
          skipBlending =
            blendMode == OverwriteBlend or
            (blendMode == NormalBlend and rgbx.a == 255)
        if skipBlending and minX == 0 and maxX == image.width:
          # We can be greedy, just do one big mult-row fill
          let
            start = image.dataIndex(0, y)
            len = image.dataIndex(0, y + partitionHeight) - start
          fillUnsafe(image.data, rgbx, start, len)
        else:
          for r in 0 ..< partitionHeight:
            hits[0] = (cast[Fixed32](minX * 256), 1.int16)
            hits[1] = (cast[Fixed32](maxX * 256), -1.int16)
            image.fillHits(rgbx, 0, y + r, hits, 2, NonZero, blendMode)

        y += partitionHeight
        continue

    let
      scanTop = y.float32
      scanBottom = (y + 1).float32

    var allEntriesInScanlineSpanIt = true
    numEntryIndices = 0
    if partition.twoNonintersectingSpanningSegments:
      numEntryIndices = 2
      entryIndices[0] = 0
      entryIndices[1] = 1
    else:
      for i in 0 ..< partition.entries.len:
        if partition.entries[i].segment.to.y <= scanTop or
          partition.entries[i].segment.at.y >= scanBottom:
          continue
        if partition.entries[i].segment.at.y > scanTop or
          partition.entries[i].segment.to.y < scanBottom:
          allEntriesInScanlineSpanIt = false
        entryIndices[numEntryIndices] = i
        inc numEntryIndices

    if allEntriesInScanlineSpanIt and numEntryIndices mod 2 == 0:
      for i in 0 ..< numEntryIndices:
        let index = entryIndices[i]
        trapezoidSegments[index].at.y = scanTop
        trapezoidSegments[index].to.y = scanBottom
        trapezoidSegments[index].at.x =
          partition.entries[index].solveX(scanTop)
        trapezoidSegments[index].to.x =
          partition.entries[index].solveX(scanBottom)

      # Sort the segments by midpoint. If they intersect this will be wrong
      # but it will get caught when we check partial coverage overlap and we
      # won't take the shortcut.

      var noEntriesInScanlineOverlap = true

      for i in 1 ..< numEntryIndices:
        var
          j = i - 1
          k = i
        while j >= 0 and
          trapezoidSegments[entryIndices[j]].midpointX >
          trapezoidSegments[entryIndices[k]].midpointX:
          swap(entryIndices[j + 1], entryIndices[j])
          dec j
          dec k

      # Only take this shortcut if the partial coverage areas on the
      # left and the right do not overlap
      for i in 0 ..< numEntryIndices - 1:
        let
          left = trapezoidSegments[entryIndices[i]]
          right = trapezoidSegments[entryIndices[i + 1]]
          leftMaxX = max(left.at.x, left.to.x)
          rightMinX = min(right.at.x, right.to.x)
        if leftMaxX.ceil.int > rightMinX.int:
          noEntriesInScanlineOverlap = false
          break

      if noEntriesInScanlineOverlap:
        # Confirm the pairs of points represent simple fills between them
        var
          onlySimpleFillPairs = true
          i, windingCount: int
        while i < numEntryIndices:
          windingCount += partition.entries[entryIndices[i]].winding
          if not windingRule.shouldFill(windingCount):
            onlySimpleFillPairs = false
            break
          windingCount += partition.entries[entryIndices[i + 1]].winding
          if windingRule.shouldFill(windingCount):
            onlySimpleFillPairs = false
            break
          i += 2

        if onlySimpleFillPairs:
          var i, filledTo: int
          while i < numEntryIndices:
            let
              left = partition.entries[entryIndices[i]]
              right = partition.entries[entryIndices[i + 1]]
              trapLeft = trapezoidSegments[entryIndices[i]]
              trapRight = trapezoidSegments[entryIndices[i + 1]]

            # Use trapezoid coverage at the edges and fill in the middle

            when allowSimd and defined(amd64):
              let vecRgbx = mm_set_ps(
                rgbx.a.float32,
                rgbx.b.float32,
                rgbx.g.float32,
                rgbx.r.float32
              )

            let
              leftMaxX = max(trapLeft.at.x, trapLeft.to.x)
              rightMinX = min(trapRight.at.x, trapRight.to.x)
              leftCoverEnd = leftMaxX.ceil.int
              rightCoverBegin = rightMinX.trunc.int
              blender = blendMode.blender()

            block: # Left-side partial coverage
              let
                inverted = trapLeft.at.x < trapLeft.to.x
                sliverStart = min(trapLeft.at.x, trapLeft.to.x)
                rectStart = leftMaxX
              var
                pen = sliverStart
                prevPen = pen
                penY = if inverted: y.float32 else: (y + 1).float32
                prevPenY = penY
              for x in sliverStart.int ..< rectStart.ceil.int:
                prevPen = pen
                pen = (x + 1).float32
                var rightRectArea = 0.float32
                if pen > rectStart:
                  rightRectArea = pen - rectStart
                  pen = rectStart
                prevPenY = penY
                penY = left.solveY(pen)
                if x < 0 or x >= image.width:
                  continue
                let
                  run = pen - prevPen
                  triangleArea = 0.5.float32 * run * abs(penY - prevPenY)
                  rectArea =
                    if inverted:
                      (prevPenY - y.float32) * run
                    else:
                      ((y + 1).float32 - prevPenY) * run
                  area = triangleArea + rectArea + rightRectArea
                  dataIndex = image.dataIndex(x, y)
                  backdrop = image.data[dataIndex]
                  source =
                    when allowSimd and defined(amd64):
                      applyOpacity(vecRgbx, area)
                    else:
                      rgbx * area
                image.data[dataIndex] = blender(backdrop, source)

            block: # Right-side partial coverage
              let
                inverted = trapRight.at.x > trapRight.to.x
                rectEnd = rightMinX
                sliverEnd = max(trapRight.at.x, trapRight.to.x)
              var
                pen = rectEnd
                prevPen = pen
                penY = if inverted: (y + 1).float32 else: y.float32
                prevPenY = penY
              for x in rectEnd.int ..< sliverEnd.ceil.int:
                prevPen = pen
                pen = (x + 1).float32
                let leftRectArea = prevPen.fractional
                if pen > sliverEnd:
                  pen = sliverEnd
                prevPenY = penY
                penY = right.solveY(pen)
                if x < 0 or x >= image.width:
                  continue
                let
                  run = pen - prevPen
                  triangleArea = 0.5.float32 * run * abs(penY - prevPenY)
                  rectArea =
                    if inverted:
                      (penY - y.float32) * run
                    else:
                      ((y + 1).float32 - penY) * run
                  area = leftRectArea + triangleArea + rectArea
                  dataIndex = image.dataIndex(x, y)
                  backdrop = image.data[dataIndex]
                  source =
                    when allowSimd and defined(amd64):
                      applyOpacity(vecRgbx, area)
                    else:
                      rgbx * area
                image.data[dataIndex] = blender(backdrop, source)

            let
              fillBegin = leftCoverEnd.clamp(0, image.width)
              fillEnd = rightCoverBegin.clamp(0, image.width)
            hits[0] = (fixed32(fillBegin.float32), 1.int16)
            hits[1] = (fixed32(fillEnd.float32), -1.int16)
            image.fillHits(rgbx, 0, y, hits, 2, NonZero, blendMode, false)

            if blendMode == MaskBlend:
              let clearTo = min(trapLeft.at.x, trapLeft.to.x).int
              image.clearUnsafe(
                min(filledTo, image.width),
                y,
                min(clearTo, image.width),
                y
              )

            filledTo = max(trapRight.at.x, trapRight.to.x).ceil.int
            i += 2

          if blendMode == MaskBlend:
            image.clearUnsafe(min(filledTo, image.width), y, image.width, y)

          inc y
          continue

    computeCoverage(
      cast[ptr UncheckedArray[uint8]](coverages[0].addr),
      hits,
      numHits,
      image.width,
      y,
      startX,
      partitions,
      partitionIndex,
      entryIndices,
      numEntryIndices,
      windingRule
    )

    if partitions[partitionIndex].requiresAntiAliasing:
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

    inc y

  if blendMode == MaskBlend:
    image.clearUnsafe(0, 0, 0, startY)
    image.clearUnsafe(0, pathHeight, 0, image.height)

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
    mask = newImage(image.width, image.height)
    fill = newImage(image.width, image.height)

  mask.fillPath(path, color(1, 1, 1, 1), transform, windingRule)

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

  fill.draw(mask, blendMode = MaskBlend)
  image.draw(fill, blendMode = paint.blendMode)

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
    mask = newImage(image.width, image.height)
    fill = newImage(image.width, image.height)

  mask.strokePath(
    path,
    color(1, 1, 1, 1),
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

  fill.draw(mask, blendMode = MaskBlend)
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

  sortHits(hits, hits.len)

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
