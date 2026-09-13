import pixie/simd

when allowSimd and defined(amd64) and not defined(pixieNoAvx):
  import chroma, pixie/blends, pixie/common

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
