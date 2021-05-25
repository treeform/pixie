import benchy, pixie, pixie/internal

proc blurSlower*(
  image: Image, radius: float32, outOfBounds: SomeColor = ColorRGBX()
) =
  ## Applies Gaussian blur to the image given a radius.
  let radius = round(radius).int
  if radius == 0:
    return

  let
    kernel = gaussianKernel(radius)
    outOfBounds = outOfBounds.asRgbx()

  proc `*`(sample: ColorRGBX, a: uint32): array[4, uint32] {.inline.} =
    [
      sample.r * a,
      sample.g * a,
      sample.b * a,
      sample.a * a
    ]

  template `+=`(values: var array[4, uint32], sample: array[4, uint32]) =
    values[0] += sample[0]
    values[1] += sample[1]
    values[2] += sample[2]
    values[3] += sample[3]

  template rgbx(values: array[4, uint32]): ColorRGBX =
    rgbx(
      (values[0] div 1024 div 255).uint8,
      (values[1] div 1024 div 255).uint8,
      (values[2] div 1024 div 255).uint8,
      (values[3] div 1024 div 255).uint8
    )

  # Blur in the X direction.
  let blurX = newImage(image.width, image.height)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var values: array[4, uint32]
      for xx in x - radius ..< min(x + radius, 0):
        values += outOfBounds * kernel[xx - x + radius]

      for xx in max(x - radius, 0) .. min(x + radius, image.width - 1):
        values += image.getRgbaUnsafe(xx, y) * kernel[xx - x + radius]

      for xx in max(x - radius, image.width) .. x + radius:
        values += outOfBounds * kernel[xx - x + radius]

      blurX.setRgbaUnsafe(x, y, rgbx(values))

  # Blur in the Y direction.
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var values: array[4, uint32]
      for yy in y - radius ..< min(y + radius, 0):
        values += outOfBounds * kernel[yy - y + radius]

      for yy in max(y - radius, 0) .. min(y + radius, image.height - 1):
        values += blurX.getRgbaUnsafe(x, yy) * kernel[yy - y + radius]

      for yy in max(y - radius, image.height) .. y + radius:
        values += outOfBounds * kernel[yy - y + radius]

      image.setRgbaUnsafe(x, y, rgbx(values))

let image = newImage(1920, 1080)

proc reset() =
  var path: Path
  path.rect(100, 100, 1720, 880)
  image.fillPath(path, rgba(255, 255, 255, 255))

reset()

timeIt "blurSlower":
  image.blurSlower(40)

reset()

timeIt "blur":
  image.blur(40)
