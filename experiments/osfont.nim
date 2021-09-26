{.
  passC: "-D_GLFW_COCOA",
  passL: "-framework Cocoa -framework OpenGL -framework IOKit -framework CoreVideo -framework AppKit",
  compile: "osfont.m",
.}

import print, pixie, pixie/fileformats/png

proc drawText(
  text: cstring,
  fontName: cstring,
  size: cint,
  width: cint,
  height: cint,
  rawData: ptr[char]
) {.cdecl, importc.}

proc getBounds(
  text: cstring,
  fontName: cstring,
  size: cint,
  width: ptr[cfloat],
  height: ptr[cfloat],
) {.cdecl, importc.}


echo "calling"

#var text = "خَرَجَ الوردُ من حَوْضِهِ لمُلاقاتها"
let
  text = "hello world 😜"
  fontName = "Times New Roman"
  fontSize = 40

var
  w: cfloat
  h: cfloat
getBounds(text, fontName, fontSize.cint, w.addr, h.addr)

var image = newImage(w.ceil.int, h.ceil.int)

drawText(
  text,
  fontName,
  fontSize.cint,
  image.width.cint,
  image.height.cint,
  cast[ptr[char]](image.data[0].addr)
)

image.writeFile("out2.png")
