import pixie, strformat, unicode, pixie/fontformats/opentype

block:
  var font = readFont("/Windows/Fonts/simsun.ttc")
  font.size = 72
  let image = newImage(220, 100)
  image.fill(rgba(255, 255, 255, 255))
  image.fillText(font, "大目鳥")
  image.writeFile("ttc.png")

block:
  var fonts = parseOpenTypeCollection(readFile("/Windows/Fonts/simsun.ttc"))
  for font in fonts:
    echo font.fullName

block:
  let files = @[
    "/Windows/Fonts/batang.ttc",
    "/Windows/Fonts/BIZ-UDGothicB.ttc",
    "/Windows/Fonts/BIZ-UDGothicR.ttc",
    "/Windows/Fonts/BIZ-UDMinchoM.ttc",
    "/Windows/Fonts/cambria.ttc",
    "/Windows/Fonts/gulim.ttc",
    "/Windows/Fonts/meiryo.ttc",
    "/Windows/Fonts/meiryob.ttc",
    "/Windows/Fonts/mingliub.ttc",
    "/Windows/Fonts/msgothic.ttc",
    "/Windows/Fonts/msjh.ttc",
    "/Windows/Fonts/msjhbd.ttc",
    "/Windows/Fonts/msjhl.ttc",
    "/Windows/Fonts/msmincho.ttc",
    "/Windows/Fonts/msyh.ttc",
    "/Windows/Fonts/msyhbd.ttc",
    "/Windows/Fonts/msyhl.ttc",
    "/Windows/Fonts/simsun.ttc",
    "/Windows/Fonts/Sitka.ttc",
    "/Windows/Fonts/SitkaB.ttc",
    "/Windows/Fonts/SitkaI.ttc",
    "/Windows/Fonts/SitkaZ.ttc",
    "/Windows/Fonts/UDDigiKyokashoN-B.ttc",
    "/Windows/Fonts/UDDigiKyokashoN-R.ttc",
    "/Windows/Fonts/YuGothB.ttc",
    "/Windows/Fonts/YuGothL.ttc",
    "/Windows/Fonts/YuGothM.ttc",
    "/Windows/Fonts/YuGothR.ttc",
  ]
  for file in files:
    echo file
    var fonts = parseOpenTypeCollection(readFile(file))
    for i, font in fonts:
      echo "  ", i, ": ", font.fullName
