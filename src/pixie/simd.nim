import simd/internal, std/macros, std/tables

const allowSimd* = not defined(pixieNoSimd) and not defined(tcc)

macro hasSimd*(procedure: untyped) =
  let
    name = procedure.procName()
    args = procedure.procArguments()
    originalBody = procedure[6]
    nameSse2 = name & "Sse2"
    nameAvx = name & "Avx"
    nameAvx2 = name & "Avx2"
    callAvx = call(ident(nameAvx), args)
    callAvx2 = call(ident(nameAvx2), args)

  var body = newStmtList()

  when not defined(pixieNoAvx):
    if nameAvx2 in simdProcs:
      body.add quote do:
        if cpuHasAvx2:
          forceReturn `callAvx2`

    if nameAvx in simdProcs:
      body.add quote do:
        if cpuHasAvx:
          forceReturn `callAvx`

  if nameSse2 in simdProcs:
    let bodySse2 = simdProcs[nameSse2][6]
    body.add quote do:
      `bodySse2`
  else:
    body.add quote do:
      echo "using ", `name`, " scalar"
      `originalBody`

  procedure[6] = body

  return procedure

when allowSimd and defined(amd64):
  import simd/sse2, simd/avx, simd/avx2
  export sse2, avx, avx2

  when defined(pixieNoAvx):
    const
      cpuHasAvx* = false
      cpuHasAvx2* = false
  else:
    import nimsimd/runtimecheck
    let
      cpuHasAvx* = checkInstructionSets({AVX})
      cpuHasAvx2* = checkInstructionSets({AVX, AVX2})

  import nimsimd/sse2 as nimsimdsse2
  export nimsimdsse2
