import pixie/simd

when allowSimd and defined(amd64):
  import chroma, pixie/blends, pixie/common

  proc testCoverage(name: string, blender: auto, overwrite: static bool) =
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
          let expected =
            when overwrite:
              if coverage == 0:
                background
              else:
                color * coverage.uint8
            else:
              blendNormal(background, color * coverage.uint8)
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
                " pixel=" & $(i - start)
    echo name, " coverage rounding passed"

  testCoverage("SSE2 normal", blendLineCoverageNormalSse2, false)
  testCoverage("SSE2 overwrite", blendLineCoverageOverwriteSse2, true)
  when not defined(pixieNoAvx):
    if cpuHasAvx2:
      testCoverage("AVX2 normal", blendLineCoverageNormalAvx2, false)
      testCoverage("AVX2 overwrite", blendLineCoverageOverwriteAvx2, true)

when allowSimd and defined(amd64) and not defined(pixieNoAvx):
  if cpuHasAvx2:
    let
      original = rgbx(120, 80, 40, 255)
      mask = rgbx(255, 255, 255, 255)
    var cases: int
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

          # Padding makes the old overread safe while its extra stores still
          # corrupt the sentinels, independently of the allocator's layout.
          var coverages = newSeq[uint8](length + 32)
          for i in 0 ..< length:
            coverages[i] = case pattern
              of 0: 0'u8
              of 1: 255'u8
              of 2: 128'u8
              else: ((i * 73 + 19) mod 256).uint8

          blendLineCoverageMaskAvx2(
            cast[ptr UncheckedArray[ColorRGBX]](pixels[start].addr),
            cast[ptr UncheckedArray[uint8]](coverages[0].addr),
            mask,
            length
          )

          for i, pixel in pixels:
            let expected =
              if i >= start and i < start + length:
                blendMask(original, mask * coverages[i - start])
              else:
                original
            doAssert pixel == expected,
              "length=" & $length & " shift=" & $shift &
              " pattern=" & $pattern & " pixel=" & $(i - start)
          inc cases
    echo "AVX2 coverage mask: ", cases, " cases passed"
