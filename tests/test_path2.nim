import chroma, pixie, pixie/fileformats/png, strformat

block:
  let
    image = newImage(100, 100)
    pathStr = """
        M 40 40 L 40 80 L 80 80 L 80 40 C 80 -20 40 100 40 40
    """
    color = rgba(0, 0, 0, 255)
  image.fill(rgba(255, 255, 255, 255))
  image.fillPath(pathStr, color)
  image.writeFile("tests/paths/pathSwish.png")
