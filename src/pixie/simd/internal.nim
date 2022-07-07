import std/macros, std/tables

var simdProcs* {.compiletime.}: Table[string, NimNode]

template forceReturn*(procedure: untyped) =
  ## Produce `return procedure()` when procedure returns something otherwise
  ## `procedure(); return` if it procedure returns nothing.
  when compiles(block: return procedure):
    return procedure
  else:
    procedure
    return

proc procName*(procedure: NimNode): string =
  ## Given a procedure signature returns only name string.
  let nameNode = procedure[0]
  if nameNode.kind == nnkPostfix:
    nameNode[1].strVal
  else:
    nameNode.strVal

proc procArguments*(procedure: NimNode): seq[NimNode] =
  ## Given a procedure signature gets the arguments as a list.
  for i, arg in procedure[3]:
    if i > 0:
      for j in 0 ..< arg.len - 2:
        result.add(arg[j])

proc call*(name: NimNode, args: seq[NimNode]): NimNode =
  ## Produces a procedure call with arguments.
  result = newNimNode(nnkCall)
  result.add(name)
  for arg in args:
    result.add(arg)

macro simd*(procedure: untyped) =
  let name = procedure.procName()
  simdProcs[name] = procedure.copy()
  return procedure
