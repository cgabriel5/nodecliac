from tables import Table, `[]`, `$`, pairs
from types import State, Node

# Add node object to tree.
#
# @param  {object} S - State object.
# @param  {object} N - Node object.
# @return - Nothing is returned.
proc add*(S: var State, N: Node) =
    S.tables.tree["nodes"].add(N)
