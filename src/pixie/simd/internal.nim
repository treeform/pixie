import std/macros, std/tables

var simdProcs* {.compiletime.}: Table[string, NimNode]

proc procName(procedure: NimNode): string =
  ## Given a procedure this returns the name as a string.
  let nameNode = procedure[0]
  if nameNode.kind == nnkPostfix:
    nameNode[1].strVal
  else:
    nameNode.strVal

proc procArguments(procedure: NimNode): seq[NimNode] =
  ## Given a procedure this gets the arguments as a list.
  for i, arg in procedure[3]:
    if i > 0:
      for j in 0 ..< arg.len - 2:
        result.add(arg[j])

proc procReturnType(procedure: NimNode): NimNode =
  ## Given a procedure this gets the return type.
  procedure[3][0]

proc procSignature(procName: string, procedure: NimNode): string =
  ## Given a procedure this returns the signature as a string.
  result = procName & "("

  for i, arg in procedure[3]:
    if i > 0:
      for j in 0 ..< arg.len - 2:
        result &= arg[^2].repr & ", "

  if procedure[3].len > 1:
    result = result[0 ..^ 3]

  result &= ")"

proc callAndReturn(name: NimNode, procedure: NimNode): NimNode =
  ## Produces a procedure call with arguments.
  let
    retType = procedure.procReturnType()
    call = newNimNode(nnkCall)
  call.add(name)
  for arg in procedure.procArguments():
    call.add(arg)
  if retType.kind == nnkEmpty:
    result = quote do:
      `call`
      return
  else:
    result = quote do:
      return `call`

macro simd*(procedure: untyped) =
  let signature = procSignature(procedure.procName(), procedure)
  simdProcs[signature] = procedure.copy()
  return procedure

macro hasSimd*(procedure: untyped) =
  let
    name = procedure.procName()
    originalBody = procedure[6]
    nameNeon = name & "Neon"
    nameSse2 = name & "Sse2"
    nameAvx = name & "Avx"
    nameAvx2 = name & "Avx2"
    callAvx = callAndReturn(ident(nameAvx), procedure)
    callAvx2 = callAndReturn(ident(nameAvx2), procedure)

  var
    foundSimd: bool
    body = newStmtList()

  when defined(amd64) and not defined(pixieNoAvx):
    if procSignature(nameAvx2, procedure) in simdProcs:
      foundSimd = true
      body.add quote do:
        if cpuHasAvx2:
          `callAvx2`

    if procSignature(nameAvx, procedure) in simdProcs:
      foundSimd = true
      body.add quote do:
        if cpuHasAvx2:
          `callAvx`

  if procSignature(nameSse2, procedure) in simdProcs:
    foundSimd = true
    let bodySse2 = simdProcs[procSignature(nameSse2, procedure)][6]
    body.add quote do:
      `bodySse2`
  elif procSignature(nameNeon, procedure) in simdProcs:
    foundSimd = true
    let bodyNeon = simdProcs[procSignature(nameNeon, procedure)][6]
    body.add quote do:
      `bodyNeon`
  else:
    body.add quote do:
      `originalBody`

  procedure[6] = body

  when not defined(pixieNoSimd):
    if not foundSimd:
      echo "No SIMD found for " & procSignature(name, procedure)

  return procedure
