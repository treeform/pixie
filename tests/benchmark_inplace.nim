import pixie, chroma, vmath, fidget/opengl/perf, pixie/fileformats/bmp

proc inPlaceDraw*(destImage: Image, srcImage: Image, mat: Mat3, blendMode = bmNormal) =
  ## Draws one image onto another using matrix with color blending.
  for y in 0 ..< destImage.width:
    for x in 0 ..< destImage.height:
      let srcPos = mat * vec2(x.float32, y.float32)
      let destRgba = destImage.getRgbaUnsafe(x, y)
      var rgba = destRgba
      var srcRgba = rgba(0, 0, 0, 0)
      if srcImage.inside(srcPos.x.floor.int, srcPos.y.floor.int):
        srcRgba = srcImage.getRgbaSmooth(srcPos.x - 0.5, srcPos.y - 0.5)
      if blendMode.hasEffect(srcRgba):
        rgba = blendMode.mix(destRgba, srcRgba)
      destImage.setRgbaUnsafe(x, y, rgba)

proc inPlaceDraw*(destImage: Image, srcImage: Image, pos = vec2(0, 0), blendMode = bmNormal) =
  destImage.inPlaceDraw(srcImage, translate(-pos), blendMode)

proc drawStepperInPlace*(a: Image, b: Image, mat: Mat3, blendMode: BlendMode) =
  ## Draws one image onto another using matrix with color blending.

  type Segment = object
    ## A math segment from point "at" to point "to"
    at*: Vec2
    to*: Vec2

  proc segment(at, to: Vec2): Segment =
    result.at = at
    result.to = to

  proc intersects(a, b: Segment, at: var Vec2): bool =
    ## Checks if the a segment intersects b segment.
    ## If it returns true, at will have point of intersection
    var s1x, s1y, s2x, s2y: float32
    s1x = a.to.x - a.at.x
    s1y = a.to.y - a.at.y
    s2x = b.to.x - b.at.x
    s2y = b.to.y - b.at.y

    var s, t: float32
    s = (-s1y * (a.at.x - b.at.x) + s1x * (a.at.y - b.at.y)) /
        (-s2x * s1y + s1x * s2y)
    t = (s2x * (a.at.y - b.at.y) - s2y * (a.at.x - b.at.x)) /
        (-s2x * s1y + s1x * s2y)

    if s >= 0 and s < 1 and t >= 0 and t < 1:
      at.x = a.at.x + (t * s1x)
      at.y = a.at.y + (t * s1y)
      return true
    return false

  var
    matInv = mat.inverse()
    # compute movement vectors
    h = 0.5.float32
    start = matInv * vec2(0 + h, 0 + h)
    stepX = matInv * vec2(1 + h, 0 + h) - start
    stepY = matInv * vec2(0 + h, 1 + h) - start
    minFilterBy2 = max(stepX.length, stepY.length)
    b = b

  let corners = [
    mat * vec2(0, 0),
    mat * vec2(b.width.float32, 0),
    mat * vec2(b.width.float32, b.height.float32),
    mat * vec2(0, b.height.float32)
  ]

  let lines = [
    segment(corners[0], corners[1]),
    segment(corners[1], corners[2]),
    segment(corners[2], corners[3]),
    segment(corners[3], corners[0])
  ]

  while minFilterBy2 > 2.0:
    b = b.minifyBy2()
    start /= 2
    stepX /= 2
    stepY /= 2
    minFilterBy2 /= 2

  template forBlend(
    mixer: proc(a, b: ColorRGBA): ColorRGBA,
    getRgba: proc(a: Image, x, y: float32): ColorRGBA {.inline.},
  ) =
    for y in 0 ..< a.height:
      var
        xMin = 0
        xMax = 0
        hasIntersection = false
      for yOffset in [0.float32, 1]:
        var scanLine = segment(
          vec2(-100000, y.float32 + yOffset),
          vec2(10000, y.float32 + yOffset)
        )
        for l in lines:
          var at: Vec2
          if intersects(l, scanLine, at):
            if hasIntersection:
              xMin = min(xMin, at.x.floor.int)
              xMax = max(xMax, at.x.ceil.int)
            else:
              hasIntersection = true
              xMin = at.x.floor.int
              xMax = at.x.ceil.int

      xMin = xMin.clamp(0, a.width)
      xMax = xMax.clamp(0, a.width)

      # for x in 0 ..< xMin:
      #   result.setRgbaUnsafe(x, y, a.getRgbaUnsafe(x, y))
      # if xMin > 0:
      #   copyMem(a.getAddr(0, y), a.getAddr(0, y), 4*xMin)

      for x in xMin ..< xMax:
        let srcV = start + stepX * float32(x) + stepY * float32(y)
        var rgba = a.getRgbaUnsafe(x, y)
        if b.inside((srcV.x - h).int, (srcV.y - h).int):
          let rgba2 = b.getRgba(srcV.x - h, srcV.y - h)
          rgba = mixer(rgba, rgba2)
        a.setRgbaUnsafe(x, y, rgba)

      #for x in xMax ..< a.width:
      #  result.setRgbaUnsafe(x, y, a.getRgbaUnsafe(x, y))
      # if a.width - xMax > 0:
      #   copyMem(result.getAddr(xMax, y), a.getAddr(xMax, y), 4*(a.width - xMax))

  proc getRgba(a: Image, x, y: float32): ColorRGBA {.inline.} =
    a.getRgbaUnsafe(x.int, y.int)

  if stepX.length == 1.0 and stepY.length == 1.0:
    case blendMode
    of bmNormal: forBlend(blendNormal, getRgba)
    of bmDarken: forBlend(blendDarken, getRgba)
    of bmMultiply: forBlend(blendMultiply, getRgba)
    of bmLinearBurn: forBlend(blendLinearBurn, getRgba)
    of bmColorBurn: forBlend(blendColorBurn, getRgba)
    of bmLighten: forBlend(blendLighten, getRgba)
    of bmScreen: forBlend(blendScreen, getRgba)
    of bmLinearDodge: forBlend(blendLinearDodge, getRgba)
    of bmColorDodge: forBlend(blendColorDodge, getRgba)
    of bmOverlay: forBlend(blendOverlay, getRgba)
    of bmSoftLight: forBlend(blendSoftLight, getRgba)
    of bmHardLight: forBlend(blendHardLight, getRgba)
    of bmDifference: forBlend(blendDifference, getRgba)
    of bmExclusion: forBlend(blendExclusion, getRgba)
    of bmHue: forBlend(blendHue, getRgba)
    of bmSaturation: forBlend(blendSaturation, getRgba)
    of bmColor: forBlend(blendColor, getRgba)
    of bmLuminosity: forBlend(blendLuminosity, getRgba)
    of bmMask: forBlend(blendMask, getRgba)
    of bmOverwrite: forBlend(blendOverwrite, getRgba)
    of bmSubtractMask: forBlend(blendSubtractMask, getRgba)
    of bmIntersectMask: forBlend(blendIntersectMask, getRgba)
    of bmExcludeMask: forBlend(blendExcludeMask, getRgba)
  else:
    case blendMode
    of bmNormal: forBlend(blendNormal, getRgbaSmooth)
    of bmDarken: forBlend(blendDarken, getRgbaSmooth)
    of bmMultiply: forBlend(blendMultiply, getRgbaSmooth)
    of bmLinearBurn: forBlend(blendLinearBurn, getRgbaSmooth)
    of bmColorBurn: forBlend(blendColorBurn, getRgbaSmooth)
    of bmLighten: forBlend(blendLighten, getRgbaSmooth)
    of bmScreen: forBlend(blendScreen, getRgbaSmooth)
    of bmLinearDodge: forBlend(blendLinearDodge, getRgbaSmooth)
    of bmColorDodge: forBlend(blendColorDodge, getRgbaSmooth)
    of bmOverlay: forBlend(blendOverlay, getRgbaSmooth)
    of bmSoftLight: forBlend(blendSoftLight, getRgbaSmooth)
    of bmHardLight: forBlend(blendHardLight, getRgbaSmooth)
    of bmDifference: forBlend(blendDifference, getRgbaSmooth)
    of bmExclusion: forBlend(blendExclusion, getRgbaSmooth)
    of bmHue: forBlend(blendHue, getRgbaSmooth)
    of bmSaturation: forBlend(blendSaturation, getRgbaSmooth)
    of bmColor: forBlend(blendColor, getRgbaSmooth)
    of bmLuminosity: forBlend(blendLuminosity, getRgbaSmooth)
    of bmMask: forBlend(blendMask, getRgbaSmooth)
    of bmOverwrite: forBlend(blendOverwrite, getRgbaSmooth)
    of bmSubtractMask: forBlend(blendSubtractMask, getRgbaSmooth)
    of bmIntersectMask: forBlend(blendIntersectMask, getRgbaSmooth)
    of bmExcludeMask: forBlend(blendExcludeMask, getRgbaSmooth)

timeIt "inPlaceDraw":
  var tmp = 0
  for i in 0 ..< 1000:
    var a = newImageFill(1000, 1000, rgba(0, 255, 0, 255))
    var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
    a.inPlaceDraw(b, pos=vec2(25, 25))
    tmp += a.width * a.height
  echo tmp

timeIt "drawStepper":
  var tmp = 0
  for i in 0 ..< 1000:
    var a = newImageFill(1000, 1000, rgba(255, 0, 0, 255))
    var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
    var c = a.drawStepper(b, translate(vec2(25, 25)), bmNormal)
    tmp += c.width * c.height
  echo tmp

timeIt "drawStepperInPlace":
  var tmp = 0
  for i in 0 ..< 1000:
    var a = newImageFill(1000, 1000, rgba(0, 255, 0, 255))
    var b = newImageFill(100, 100, rgba(0, 255, 0, 255))
    drawStepperInPlace(a, b, translate(vec2(25, 25)), bmNormal)
    tmp += a.width * a.height
  echo tmp
