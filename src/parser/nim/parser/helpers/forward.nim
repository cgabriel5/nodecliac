from types import State

# Increase loop index/column.
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc forward*(S: var State) =
    inc(S.i)
    inc(S.column)
