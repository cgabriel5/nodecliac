from types import State

# Rollback loop index/column to re-run parser at same iteration.
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc rollback*(S: var State) =
    S.i = S.i - 1
    S.column = S.column - 1
