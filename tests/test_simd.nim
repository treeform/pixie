import pixie/simd

when allowSimd and defined(amd64):
  import chroma, pixie/blends, pixie/common

  proc coveragePixel(
    backdrop, color: ColorRGBX, coverage: uint8, mode: static BlendMode
  ): ColorRGBX =
    when mode == OverwriteBlend:
      if coverage == 0: backdrop
      else: color * coverage
    elif mode == MaskBlend:
      blendMask(backdrop, color * coverage)
    else:
      blendNormal(backdrop, color * coverage)

  proc testCoverage(name: string, blender: auto, mode: static BlendMode) =
    ## Compares vector coverage with scalar pixels across every alignment.
    let background = rgbx(90, 110, 130, 255)
    var
      pixels: array[104, ColorRGBX]
      coverages: array[80, uint8]
    for color in [rgbx(240, 144, 72, 255), rgbx(13, 97, 151, 201),
      rgbx(255, 255, 255, 255), rgbx(0, 0, 0, 0)]:
        for coverage in 0 .. 255:
          for value in coverages.mitems:
            value = coverage.uint8
          let expected = coveragePixel(background, color, coverage.uint8, mode)
          for shift in 0 .. 7:
            let start = 8 + shift
            for pixel in pixels.mitems:
              pixel = background
            blender(
              cast[ptr UncheckedArray[ColorRGBX]](pixels[start].addr),
              cast[ptr UncheckedArray[uint8]](coverages[0].addr),
              color,
              coverages.len
            )
            for i, pixel in pixels:
              let wanted =
                if i >= start and i < start + coverages.len:
                  expected
                else:
                  background
              doAssert pixel == wanted,
                name & " coverage=" & $coverage & " shift=" & $shift &
                " color=" & $color & " pixel=" & $(i - start)
    echo name, " coverage rounding passed"

  proc testCoverageSpans(name: string, blender: auto, mode: static BlendMode) =
    let original = rgbx(120, 80, 40, 255)
    var cases: int
    for color in [rgbx(255, 255, 255, 255), rgbx(13, 97, 151, 201),
      rgbx(1, 0, 1, 1), rgbx(0, 0, 0, 0)]:
        for length in 0 .. 160:
          for shift in 0 .. 7:
            for pattern in 0 .. 3:
              var pixels = newSeq[ColorRGBX](length + 96)
              for pixel in pixels.mitems:
                pixel = original

              # Exercise every pixel alignment, with sentinels on both sides.
              var start: int
              while (cast[uint](pixels[start].addr) and 31) != 0:
                inc start
              start += 16 + shift

              # Vary coverage alignment independently of pixel alignment.
              # Padding keeps an overread safe while excess stores still
              # corrupt the sentinels, regardless of the allocator's layout.
              let coverageStart = (length + shift) mod 32
              var coverages = newSeq[uint8](length + 64)
              for coverage in coverages.mitems:
                coverage = 93
              for i in 0 ..< length:
                coverages[coverageStart + i] = case pattern
                  of 0: 0'u8
                  of 1: 255'u8
                  of 2: 128'u8
                  else: ((i * 73 + 19) mod 256).uint8

              blender(
                cast[ptr UncheckedArray[ColorRGBX]](pixels[start].addr),
                cast[ptr UncheckedArray[uint8]](coverages[coverageStart].addr),
                color,
                length
              )

              for i, pixel in pixels:
                let expected =
                  if i >= start and i < start + length:
                    coveragePixel(
                      original, color, coverages[coverageStart + i - start], mode
                    )
                  else:
                    original
                doAssert pixel == expected,
                  name & " length=" & $length & " shift=" & $shift &
                  " pattern=" & $pattern & " color=" & $color &
                  " pixel=" & $(i - start)
              inc cases
    echo name, " coverage spans: ", cases, " cases passed"

  template testCoverageBlender(name, blender, mode: untyped) =
    testCoverage(name, blender, mode)
    testCoverageSpans(name, blender, mode)

  testCoverageBlender("SSE2 normal", blendLineCoverageNormalSse2, NormalBlend)
  testCoverageBlender("SSE2 overwrite", blendLineCoverageOverwriteSse2, OverwriteBlend)
  testCoverageBlender("SSE2 mask", blendLineCoverageMaskSse2, MaskBlend)
  when not defined(pixieNoAvx):
    if cpuHasAvx2:
      testCoverageBlender("AVX2 normal", blendLineCoverageNormalAvx2, NormalBlend)
      testCoverageBlender("AVX2 overwrite", blendLineCoverageOverwriteAvx2, OverwriteBlend)
      testCoverageBlender("AVX2 mask", blendLineCoverageMaskAvx2, MaskBlend)
    else:
      echo "AVX2 coverage tests skipped: CPU does not support AVX2"
