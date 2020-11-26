import chroma, blends, vmath, common, images

proc drawUberTemplate(
  a: Image,
  b: Image,
  c: Image,
  mat: Mat3,
  lines: array[4, Segment],
  blendMode: BlendMode,
  inPlace: bool,
  smooth: bool,
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
      if xMin > 0:
        copyMem(c.getAddr(0, y), a.getAddr(0, y), 4*xMin)

      for x in xMin ..< xMax:
        let srcPos = start + stepX * float32(x) + stepY * float32(y)
        #let srcPos = matInv * vec2(x.float32 + h, y.float32 + h)
        var rgba = a.getRgbaUnsafe(x, y)
        let rgba2 = b.getRgbaFn(srcPos.x - h, srcPos.y - h)
        rgba = mixer(rgba, rgba2)
        c.setRgbaUnsafe(x, y, rgba)

      #for x in xMax ..< a.width:
      #  result.setRgbaUnsafe(x, y, a.getRgbaUnsafe(x, y))
      if a.width - xMax > 0:
        copyMem(c.getAddr(xMax, y), a.getAddr(xMax, y), 4*(a.width - xMax))

proc drawUber*(a: Image, b: Image, c: Image, mat: Mat3, blendMode: BlendMode, inPlace: bool) =
  ## Draws one image onto another using matrix with color blending.

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
    matInv = matInv * scale(vec2(0.5, 0.5))

  proc getRgbaUnsafe(a: Image, x, y: float32): ColorRGBA {.inline.} =
    a.getRgbaUnsafe(x.round.int, y.round.int)

  if stepX.length == 1.0 and stepY.length == 1.0 and
      mat[2, 0].fractional == 0.0 and mat[2, 1].fractional == 0.0:
    #echo "copy non-smooth"
    case blendMode
    of bmNormal: forBlend(blendNormal, getRgbaUnsafe)
    of bmDarken: forBlend(blendDarken, getRgbaUnsafe)
    of bmMultiply: forBlend(blendMultiply, getRgbaUnsafe)
    of bmLinearBurn: forBlend(blendLinearBurn, getRgbaUnsafe)
    of bmColorBurn: forBlend(blendColorBurn, getRgbaUnsafe)
    of bmLighten: forBlend(blendLighten, getRgbaUnsafe)
    of bmScreen: forBlend(blendScreen, getRgbaUnsafe)
    of bmLinearDodge: forBlend(blendLinearDodge, getRgbaUnsafe)
    of bmColorDodge: forBlend(blendColorDodge, getRgbaUnsafe)
    of bmOverlay: forBlend(blendOverlay, getRgbaUnsafe)
    of bmSoftLight: forBlend(blendSoftLight, getRgbaUnsafe)
    of bmHardLight: forBlend(blendHardLight, getRgbaUnsafe)
    of bmDifference: forBlend(blendDifference, getRgbaUnsafe)
    of bmExclusion: forBlend(blendExclusion, getRgbaUnsafe)
    of bmHue: forBlend(blendHue, getRgbaUnsafe)
    of bmSaturation: forBlend(blendSaturation, getRgbaUnsafe)
    of bmColor: forBlend(blendColor, getRgbaUnsafe)
    of bmLuminosity: forBlend(blendLuminosity, getRgbaUnsafe)
    of bmMask: forBlend(blendMask, getRgbaUnsafe)
    of bmOverwrite: forBlend(blendOverwrite, getRgbaUnsafe)
    of bmSubtractMask: forBlend(blendSubtractMask, getRgbaUnsafe)
    of bmIntersectMask: forBlend(blendIntersectMask, getRgbaUnsafe)
    of bmExcludeMask: forBlend(blendExcludeMask, getRgbaUnsafe)
  else:
    #echo "copy smooth"
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
