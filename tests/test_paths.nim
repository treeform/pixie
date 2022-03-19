
block:
  echo "??? stroke zero polygon ???"
  try:
    echo "inside the try"
    raise newException(ValueError, "Just the exception please")
    echo "no exception wut?"
  except ValueError:
    echo "getCurrentExceptionMsg"
    echo getCurrentExceptionMsg()

echo "test completed"
