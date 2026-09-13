## Run with: nim c -r -d:release tests/bench_images_tiled.nim
## Append "negative" to also benchmark the inputs fixed by issue #597.
## On Windows, -d:benchAffinity pins this process to logical CPU 2.
## CSV timings exclude setup and checksums. Compare multiple interleaved runs.
import std/[monotimes, os, strformat, strutils]
import pixie

when defined(windows) and defined(benchAffinity):
  proc GetCurrentProcess(): int {.stdcall, dynlib: "kernel32", importc.}
  proc SetProcessAffinityMask(handle: int, mask: uint64): cint
    {.stdcall, dynlib: "kernel32", importc.}
  doAssert SetProcessAffinityMask(GetCurrentProcess(), 4) != 0

const buildLabel {.strdefine.} = "working_tree"
var checksum: uint64

proc imageChecksum(image: Image): uint64 =
  for c in image.data:
    result = (result xor cast[uint32](c).uint64) * 1099511628211'u64

template measure(name: string, iterations: int, body: untyped) =
  block:
    for warmup in 0 ..< 3:
      body
    let start = getMonoTime().ticks
    for iteration in 0 ..< iterations:
      body
    let milliseconds = (getMonoTime().ticks - start).float64 / 1e6 / iterations.float64
    echo buildLabel, ",", name, ",", iterations, ",",
      formatFloat(milliseconds, ffDecimal, 6)

proc makeTile(width, height: int, stripes = false): Image =
  result = newImage(width, height)
  for y in 0 ..< height:
    for x in 0 ..< width:
      result[x, y] = if stripes:
        (if y == 0: rgba(35, 115, 210, 255) else: rgba(255, 255, 255, 255))
      else:
        rgba(((x * 37 + y * 13) and 255).uint8,
          ((x * 11 + y * 43) and 255).uint8,
          ((x * 23 + y * 17) and 255).uint8, 255)

proc runFill(name: string, width, height, tileWidth, tileHeight, iterations: int,
    negative = false) =
  let
    tile = makeTile(tileWidth, tileHeight, tileWidth == 4)
    image = newImage(width, height)
    paint = newPaint(TiledImagePaint)
  paint.image = tile
  paint.imageMat = rotate(-7.float32 * PI.float32 / 180)
  if not negative:
    # Keep all source coordinates positive so the unfixed build is valid.
    paint.imageMat = paint.imageMat *
      translate(vec2(-tileWidth.float32 * 512, -tileHeight.float32 * 512))
  measure(name, iterations):
    image.fill(paint)
  echo &"checksum,{name},{imageChecksum(image)}"

runFill("fill_4x4_256x160_positive", 256, 160, 4, 4, 160)
runFill("fill_4x4_1024_positive", 1024, 1024, 4, 4, 8)
runFill("fill_63x47_1024_positive", 1024, 1024, 63, 47, 8)

block:
  let
    tile = makeTile(64, 64)
    image = newImage(1024, 1024)
  measure("drawTiled_64x64_identity", 10):
    image.drawTiled(tile, mat3())
  echo &"checksum,drawTiled_64x64_identity,{imageChecksum(image)}"

block:
  let
    source = makeTile(512, 512)
    image = newImage(1024, 1024)
    transform = translate(vec2(256.25, 256.75)) * rotate(-7.float32 * PI.float32 / 180)
  measure("draw_smooth_nonwrapped", 20):
    image.draw(source, transform)
  echo &"checksum,draw_smooth_nonwrapped,{imageChecksum(image)}"

block:
  let tile = makeTile(63, 47)
  measure("sampler_positive_262144", 20):
    var local: uint64
    for y in 0 ..< 512:
      for x in 0 ..< 512:
        let sample = tile.getRgbaSmooth(
          x.float32 + 0.25, y.float32 + 0.75, true
        )
        local += cast[uint32](sample).uint64
    checksum = local
  echo &"checksum,sampler_positive_262144,{checksum}"

if paramCount() > 0 and paramStr(1) == "negative":
  runFill("fill_4x4_256x160_negative", 256, 160, 4, 4, 160, true)
  runFill("fill_63x47_1024_negative", 1024, 1024, 63, 47, 8, true)
