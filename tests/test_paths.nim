import pixie

block:
  echo "??? stroke zero polygon ???"

  try:
    echo "inside the try"
    raise newException(PixieError, "Just the exception please")
    echo "no exception wut?"
  except PixieError:
    echo "getCurrentExceptionMsg"
    echo getCurrentExceptionMsg()
