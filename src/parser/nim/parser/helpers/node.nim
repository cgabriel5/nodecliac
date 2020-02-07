# import tables
# import "../helpers/state" # / [state]
# import "../helpers" / [state]
# from "../helpers/state" import State
from state import State
include "node-type"

proc node*(S: State, node: string): Node =
    # [https://github.com/nim-lang/Nim/issues/11395]
    # [https://forum.nim-lang.org/t/2799#17448]
    case (node):
    of "COMMENT": result = Node(kind: comment)
    of "NEWLINE": result = Node(kind: newline)
    of "SETTING": result = Node(kind: setting)
    of "VARIABLE": result = Node(kind: variable)
    of "COMMAND": result = Node(kind: command)
    of "FLAG": result = Node(kind: flag)
    of "OPTION": result = Node(kind: option)
    of "BRACE": result = Node(kind: brace)

    result.node = node
    result.line = S.line
    result.start = S.i
    result.end = -1
