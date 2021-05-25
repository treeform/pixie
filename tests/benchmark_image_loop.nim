import benchy, pixie

let image = newImage(2560, 1440)
image.fill(rgba(50, 100, 150, 200))

timeIt "x then y":
  var sum: uint64
  for x in 0 ..< image.width:
    for y in 0 ..< image.height:
      let pixel = image.getRgbaUnsafe(x, y)
      sum += pixel.r + pixel.g + pixel.b + pixel.a
  if sum == 0:
    echo "0"
  keep sum

timeIt "y then x":
  var sum: uint64
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let pixel = image.getRgbaUnsafe(x, y)
      sum += pixel.r + pixel.g + pixel.b + pixel.a
  if sum == 0:
    echo "0"
  keep sum
