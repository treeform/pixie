const
  allowSimd* = not defined(pixieNoSimd) and not defined(tcc)
  allowSse2* = allowSimd and defined(amd64)
  allowAvx* = allowSse2 and not defined(pixieNoAvx)
  allowNeon* = allowSimd and defined(arm64)

when allowSse2:
  import simd/sse2
  export sse2

  import nimsimd/sse2 as nimsimdsse2
  export nimsimdsse2

when allowAvx:
  import simd/avx, simd/avx2
  export avx, avx2

  when defined(pixieAvx2):
    # The target CPU is known to have AVX2, skip the runtime check.
    const
      cpuHasAvx* = true
      cpuHasAvx2* = true
  else:
    import nimsimd/runtimecheck

    let
      cpuHasAvx* = checkInstructionSets({AVX})
      cpuHasAvx2* = checkInstructionSets({AVX, AVX2})

when allowNeon:
  import simd/neon
  export neon

  import nimsimd/neon as nimsimdneon
  export nimsimdneon
