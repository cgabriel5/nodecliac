from typetraits import name

# Return name of given data type.
#
# @param {any} t - The given data type.
# @return {string} - The type's name.
# @resource [https://forum.nim-lang.org/t/4734]
# @resource [https://forum.nim-lang.org/t/4734#29536]
proc dtype*(t: any): string =
    result = name(type(t)) # Or simply 'type(t)'?
