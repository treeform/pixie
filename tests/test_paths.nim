import pixie

block:
  echo "??? stroke zero polygon ???"
  # let image = newImage(200, 200)
  # image.fill(rgba(255, 255, 255, 255))

  # let ctx = newContext(image)
  # ctx.setLineDash(@[2.0.float32])

  try:
    echo "inside the try"
    raise newException(PixieError, "Just the exception please")
    echo "no exception wut?"
  except PixieError:
    echo "getCurrentExceptionMsg"
    echo getCurrentExceptionMsg()

echo "test completed"
