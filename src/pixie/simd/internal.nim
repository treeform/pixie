import std/macros, std/tables

var simdProcs* {.compiletime.}: Table[string, NimNode]

proc procName(procedure: NimNode): string =
  ## Given a procedure signature returns only name string.
  let nameNode = procedure[0]
  if nameNode.kind == nnkPostfix:
    nameNode[1].strVal
  else:
    nameNode.strVal

proc procArguments(procedure: NimNode): seq[NimNode] =
  ## Given a procedure signature gets the arguments as a list.
  for i, arg in procedure[3]:
    if i > 0:
      for j in 0 ..< arg.len - 2:
        result.add(arg[j])

proc procReturnType(procedure: NimNode): NimNode =
  ## Given a procedure signature gets the return type.
  procedure[3][0]

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
  let name = procedure.procName()
  simdProcs[name] = procedure.copy()
  return procedure

macro hasSimd*(procedure: untyped) =
  let
    name = procedure.procName()
    originalBody = procedure[6]
    nameSse2 = name & "Sse2"
    nameAvx = name & "Avx"
    nameAvx2 = name & "Avx2"
    callAvx = callAndReturn(ident(nameAvx), procedure)
    callAvx2 = callAndReturn(ident(nameAvx2), procedure)

  var body = newStmtList()

  when not defined(pixieNoAvx):
    if nameAvx2 in simdProcs:
      body.add quote do:
        if cpuHasAvx2:
          `callAvx2`

    if nameAvx in simdProcs:
      body.add quote do:
        if cpuHasAvx2:
          `callAvx`

  if nameSse2 in simdProcs:
    let bodySse2 = simdProcs[nameSse2][6]
    body.add quote do:
      `bodySse2`
  else:
    body.add quote do:
      `originalBody`

  procedure[6] = body

  return procedure
