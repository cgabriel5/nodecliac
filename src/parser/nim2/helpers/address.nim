# Return memory address of given data.
#
# @param {any} t - The given data type.
# @return {string} - The memory address.
# @resource [https://forum.nim-lang.org/t/5405]
# @resource [https://forum.nim-lang.org/t/6865]
proc address*(t: any): string =
    result = repr(t.addr)

# To hex: [https://forum.nim-lang.org/t/5405#34197]
# fmt"{cast[int](addr(OBJ)):#x}"
