extends RefCounted
## Call with the GLOBAL logical32 cell, not the local rectangle coordinate.
const MASKS = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 23, 27, 31, 38, 39, 46, 47, 55, 63, 76, 77, 78, 79, 95, 110, 111, 127, 137, 139, 141, 143, 155, 159, 175, 191, 205, 207, 223, 239, 255]
static func atlas_coords(cell:Vector2i, raw_mask:int)->Vector2i:
    var mask=raw_mask & 15
    for row in [[16,1,2],[32,4,2],[64,4,8],[128,1,8]]:
        if raw_mask & row[0] and mask & row[1] and mask & row[2]:mask|=row[0]
    return Vector2i(MASKS.find(mask),posmod(cell.x,8)+posmod(cell.y,8)*8)
