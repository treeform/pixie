import benchy, pixie/fileformats/jpeg, os

const
  jpegFiles* = [
    (100, "tests/fileformats/jpeg/masters/red.jpg"),
    (100, "tests/fileformats/jpeg/masters/green.jpg"),
    (100, "tests/fileformats/jpeg/masters/blue.jpg"),
    (100, "tests/fileformats/jpeg/masters/white.jpg"),
    (100, "tests/fileformats/jpeg/masters/black.jpg"),

    (100, "tests/fileformats/jpeg/masters/8x8.jpg"),
    (100, "tests/fileformats/jpeg/masters/8x8_progressive.jpg"),

    (20, "tests/fileformats/jpeg/masters/16x16.jpg"),
    (20, "tests/fileformats/jpeg/masters/16x16_progressive.jpg"),

    (10, "tests/fileformats/jpeg/masters/f1-exif.jpg"),
    (10, "tests/fileformats/jpeg/masters/f2-exif.jpg"),
    (10, "tests/fileformats/jpeg/masters/f3-exif.jpg"),
    (10, "tests/fileformats/jpeg/masters/f4-exif.jpg"),
    (10, "tests/fileformats/jpeg/masters/f5-exif.jpg"),
    (10, "tests/fileformats/jpeg/masters/f6-exif.jpg"),
    (10, "tests/fileformats/jpeg/masters/f7-exif.jpg"),
    (10, "tests/fileformats/jpeg/masters/f8-exif.jpg"),

    (1, "tests/fileformats/jpeg/masters/quality_01.jpg"),
    (1, "tests/fileformats/jpeg/masters/quality_10.jpg"),
    (1, "tests/fileformats/jpeg/masters/quality_25.jpg"),
    (1, "tests/fileformats/jpeg/masters/quality_50.jpg"),
    (1, "tests/fileformats/jpeg/masters/quality_100.jpg"),

    (1, "tests/fileformats/jpeg/masters/cat_4_4_4.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_4_4_4.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_4_2_2.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_4_2_0.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_4_1_1.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_4_2_0_progressive.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_4_4_4_progressive.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_restart_markers_5.jpg"),
    (1, "tests/fileformats/jpeg/masters/cat_restart_markers_5_progressive.jpg"),

    (1, "tests/fileformats/jpeg/masters/mandrill.jpg"),
    (1, "tests/fileformats/jpeg/masters/exif_overrun.jpg"),
    (1, "tests/fileformats/jpeg/masters/grayscale_test.jpg"),
    (1, "tests/fileformats/jpeg/masters/progressive.jpg"),

    (1, "tests/fileformats/jpeg/masters/testimg.jpg"),
    (1, "tests/fileformats/jpeg/masters/testimgp.jpg"),
    (1, "tests/fileformats/jpeg/masters/testorig.jpg"),
    (1, "tests/fileformats/jpeg/masters/testprog.jpg"),
  ]

for (times, file) in jpegFiles:
  let data = readFile(file)
  timeIt "pixie " & file.splitPath.tail & " decode":
    for i in 0 ..< times:
      discard decodeJpeg(data)


# import stb_image/read as stbi
# block:
#   for file in jpegSuiteFiles:
#     let data = readFile(file)
#     var name = file.splitPath.tail

#     timeIt "stb " & file.splitPath.tail & " decode":
#       var width, height, channels: int
#       discard loadFromMemory(
#         cast[seq[byte]](data),
#         width,
#         height,
#         channels,
#         stbi.RGBA
#       )
