version     = "2.1.0"
author      = "Andre von Houck and Ryan Oldenburg"
description = "Full-featured 2d graphics library for Nim."
license     = "MIT"

srcDir = "src"

requires "nim >= 1.2.6"
requires "vmath >= 1.0.8"
requires "chroma >= 0.2.5"
requires "zippy >= 0.5.12"
requires "flatty >= 0.1.3"
requires "nimsimd >= 1.0.0"
requires "bumpy >= 1.0.3"

task docs, "Generate API documents":
  exec "nim doc --index:on --project --out:docs --hints:off src/pixie.nim"
