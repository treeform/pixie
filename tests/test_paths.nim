import chroma, pixie, pixie/fileformats/png, strformat

block:
  echo "fillOverlaps 1"
  let path = newPath()
  path.rect(0, 0, 10, 10)

  doAssert path.fillOverlaps(vec2(5, 5))
  doAssert path.fillOverlaps(vec2(0, 0))
  doAssert path.fillOverlaps(vec2(9, 0))
  doAssert path.fillOverlaps(vec2(0, 9))
  doAssert not path.fillOverlaps(vec2(10, 10))

block:
  echo "??? stroke zero polygon ???"

  try:
    echo "inside the try"
    raise newException(PixieError, "Just the exception please")
    echo "no exception wut?"
  except PixieError:
    echo "getCurrentExceptionMsg"
    echo getCurrentExceptionMsg()

echo "test completed"
