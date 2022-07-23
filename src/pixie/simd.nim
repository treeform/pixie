import simd/internal

export internal

const allowSimd* = not defined(pixieNoSimd) and not defined(tcc)

when allowSimd:
  when defined(amd64):
    import simd/sse2, simd/avx, simd/avx2
    export sse2, avx, avx2

    when not defined(pixieNoAvx):
      import nimsimd/runtimecheck
      let
        cpuHasAvx* = checkInstructionSets({AVX})
        cpuHasAvx2* = checkInstructionSets({AVX, AVX2})

    import nimsimd/sse2 as nimsimdsse2
    export nimsimdsse2

  elif defined(arm64):
    import simd/neon
    export neon

    import nimsimd/neon as nimsimdneon
    export nimsimdneon
