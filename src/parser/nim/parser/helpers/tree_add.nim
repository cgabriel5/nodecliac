import std/tables

import types

# Add node object to tree.
#
# @param  {object} S - State object.
# @param  {object} N - Node object.
# @return - Nothing is returned.
proc add*(S: State, N: Node) =
    S.tables.tree["nodes"].add(N)
