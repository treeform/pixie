import ./common

when defined(linux) or defined(nimdoc): # BSD?

  {.passC: staticExec("pkg-config --cflags fontconfig").}
  {.passL: staticExec("pkg-config --libs fontconfig").}

  {.pragma: fcHeader, header: "<fontconfig/fontconfig.h>".}
  {.pragma: importFc, fcHeader, importc: "Fc$1".}

  const
    FcFalse = cint 0

    FC_FAMILY = "family"
    FC_STYLE = "style"
    FC_WEIGHT = "weight"
    FC_SIZE = "size"
    FC_FILE = "file"

  type
    FcChar8* = uint8
    FcBool* = cint

    FcResult {.importc.} = enum
      FcResultMatch, FcResultNoMatch, FcResultTypeMismatch, FcResultNoId,
      FcResultOutOfMemory

    FcPattern = distinct pointer

    FcConfig = distinct pointer

  proc Init(): FcBool {.importFc.} ## Initialize fontconfig library
  proc Fini() {.importFc.} ## Finalize fontconfig library.

  proc PatternCreate(): FcPattern {.importFc.}
  proc PatternDestroy(p: FcPattern) {.importFc.}

  proc PatternAddInteger(p: FcPattern; obj: cstring; i: cint): FcBool {.importFc.}
  proc PatternAddDouble(p: FcPattern; obj: cstring; d: cdouble): FcBool {.importFc.}
  proc PatternAddString(p: FcPattern; obj, s: cstring): FcBool {.importFc.}
  proc DefaultSubstitute(p: FcPattern) {.importFc.}
  proc PatternPrint(p: FcPattern) {.importFc.}

  proc FontMatch(cfg: FcConfig; p: FcPattern; r: var FcResult): FcPattern {.importFc.}

  proc PatternGetString(p: FcPattern; obj: cstring; n: cint;
      s: ptr cstring): FcResult {.importFc.}

  proc findSystemTypeface*(family = ""; style = ""; weight = 0; size = 0.0): string =
    ## Find a path to an appropriate system typeface for the given parameters.
    ## This proc always returns a path to a typeface file, results may vary.
    # TODO: only return font in supported formats
    if Init() == FcFalse:
      raise newException(PixieError, "Failed to initialize FontConfig")

    var pat = PatternCreate()
    DefaultSubstitute(pat)
    if family != "":
      discard PatternAddString(pat, FC_FAMILY, family);
    if style != "":
      discard PatternAddString(pat, FC_STYLE, style);
    if weight != 0:
      discard PatternAddInteger(pat, FC_WEIGHT, cint weight);
    if size != 0.0:
      discard PatternAddDouble(pat, FC_SIZE, size);

    var
      res = FcResultNoMatch
      font = FontMatch(nil, pat, res)
    if res == FcResultMatch:
      # PatternPrint(font);
      var path: cstring
      if PatternGetString(font, FC_FILE, 0, addr path) == FcResultMatch:
        result = $path
      PatternDestroy(font)

    PatternDestroy(pat)
    Fini()
    if result == "":
      raise newException(PixieError, "Failed to find a system typeface")

else:

  proc findSystemTypeface*(family = ""; style = ""; weight=""; size = 0): string =
    raise newException(PixieError, "findSystemTypeface not implemented for this platform")
