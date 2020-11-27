import pixie/fileformats/jpgstb

let original = readFile("tests/images/jpg/jpeg420exif.jpg")

discard decodeJpg(original)
