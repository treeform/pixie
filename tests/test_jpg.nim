when defined(pixieUseStb):
  import pixie/fileformats/jpg

  let
    original = readFile("tests/fileformats/jpg/jpeg420exif.jpg")
    stbDecoded = decodeJpg(original)
