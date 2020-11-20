## Public interface to you library.

import pixie/images, pixie/masks, pixie/paths
export images, masks, paths

proc toMask*(image: Image): Mask =
  ## Converts an Image to a Mask.
  result = newMask(image.width, image.height)
  for i in 0 ..< image.data.len:
    result.data[i] = image.data[i].a

proc toImage*(mask: Mask): Image =
  ## Converts a Mask to Image.
  result = newImage(mask.width, mask.height)
  for i in 0 ..< mask.data.len:
    result.data[i].a = mask.data[i]
