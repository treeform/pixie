
type
  Mask* = ref object
    ## Main mask object that holds the mask data.
    width*, height*: int
    data*: seq[uint8]

proc newMask*(width, height: int): Mask =
  ## Creates a new mask with appropriate dimensions.
  result = Mask()
  result.width = width
  result.height = height
  result.data = newSeq[uint8](width * height)

proc inside*(mask: Mask, x, y: int): bool {.inline.} =
  ## Returns true if (x, y) is inside the mask.
  x >= 0 and x < mask.width and y >= 0 and y < mask.height

proc copy*(mask: Mask): Mask =
  ## Copies an mask creating a new mask.
  result = newMask(mask.width, mask.height)
  result.data = mask.data

proc `$`*(mask: Mask): string =
  ## Display the mask size and channels.
  "<Mask " & $mask.width & "x" & $mask.height & ">"

proc getUnsafe*(mask: Mask, x, y: int): uint8 {.inline.} =
  ## Gets a value from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory reads.
  result = mask.data[mask.width * y + x]

proc `[]`*(mask: Mask, x, y: int): uint8 {.inline.} =
  ## Gets the value at (x, y) or returns transparent black if outside of bounds.
  if mask.inside(x, y):
    return mask.getUnsafe(x, y)

proc setUnsafe*(mask: Mask, x, y: int, value: uint8) {.inline.} =
  ## Sets the value from (x, y) coordinates.
  ## * No bounds checking *
  ## Make sure that x, y are in bounds.
  ## Failure in the assumptions will case unsafe memory writes.
  mask.data[mask.width * y + x] = value

proc `[]=`*(mask: Mask, x, y: int, value: uint8) {.inline.} =
  ## Sets the value at (x, y) or does nothing if outside of bounds.
  if mask.inside(x, y):
    mask.setUnsafe(x, y, value)

proc fill*(mask: Mask, value: uint8) =
  ## Fills the mask with the paramter value.
  for i in 0 ..< mask.data.len:
    mask.data[i] = value

proc invert*(mask: Mask) =
  ## Inverts the entire mask value.
  for value in mask.data.mitems:
    value = 255 - value
