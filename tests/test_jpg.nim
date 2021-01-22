when defined(useStb):
  import pixie/fileformats/jpg

  let
    original = readFile("tests/images/jpg/jpeg420exif.jpg")
    stbDecoded = decodeJpg(original)
