version     = "4.0.4"
author      = "Andre von Houck and Ryan Oldenburg"
description = "Full-featured 2d graphics library for Nim."
license     = "MIT"

srcDir = "src"

requires "nim >= 1.4.8"
requires "vmath >= 1.1.0"
requires "chroma >= 0.2.5"
requires "zippy >= 0.9.7"
requires "flatty >= 0.2.4"
requires "nimsimd >= 1.0.0"
requires "bumpy >= 1.0.3"

task bindings, "Generate bindings":

  proc compile(libName: string, flags = "") =
    exec "nim c -f " & flags & " -d:release --app:lib --gc:arc --tlsEmulation:off --out:" & libName & " --outdir:bindings/generated bindings/bindings.nim"

  when defined(windows):
    compile "pixie.dll"

  elif defined(macosx):
    compile "libpixie.dylib.arm", "--cpu:arm64 -l:'-target arm64-apple-macos11' -t:'-target arm64-apple-macos11'"
    compile "libpixie.dylib.x64", "--cpu:amd64 -l:'-target x86_64-apple-macos10.12' -t:'-target x86_64-apple-macos10.12'"
    exec "lipo bindings/generated/libpixie.dylib.arm bindings/generated/libpixie.dylib.x64 -output bindings/generated/libpixie.dylib -create"

  else:
    compile "libpixie.so"
