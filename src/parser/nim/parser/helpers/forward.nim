import types

# Increase loop index/column.
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc forward*(S: State) =
    inc(S.i)
    inc(S.column)
