from sets import toHashSet
from strutils import Digits, Letters, Newlines

const C_NL* = Newlines
const C_LETTERS* = Letters
const C_QUOTES* = {'"', '\''}
const C_SPACES* = {' ', '\t'}
const C_SOL* = Letters + {'-', '@', ')', '\\', ']', '$', ';', '#'}
const C_SET_IDENT* = Letters + {'-', '_'}
const C_SET_VALUE* = C_QUOTES + Letters + Digits
const C_VAR_IDENT* = C_SET_IDENT
const C_VAR_VALUE* = C_SET_VALUE
const C_FLG_IDENT* = Letters + Digits + {'-', '.'}
const C_CMD_IDENT_START* = Letters + {':'}
const C_CMD_IDENT* = Letters + Digits + {'-', '_', '.', ':', '+', '\\'}
const C_CMD_VALUE* = {'-', 'c', 'd', 'f', '['}
const C_KW_ALL* = ["context", "default", "filedir"]
const C_KD_STR* = ["context", "filedir"]
const C_CTX_MUT* = Letters + Digits + {'-', '}', '|'}
const C_CTX_CON* = Letters + Digits + {'#', '-', '!', ','}
const C_CTX_ALL* = Letters + Digits + {'#', '-','{', '}', '|', '!', ':', ';', ','}
const C_CTX_FLG* = Letters + Digits + {'-', '!', ',', ':'}
const C_CTX_OPS* = toHashSet(["eq", "ne", "gt", "ge", "lt", "le"])
const C_CTX_CAT* = {'a', 'A', 'f', 'F'} # Conditional argument-count type.
