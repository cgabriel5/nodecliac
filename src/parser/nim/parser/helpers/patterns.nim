from strutils import Digits, Letters, Newlines

const C_NL* = Newlines
const C_LETTERS* = Letters
const C_QUOTES* = {'"', '\''}
const C_SPACES* = {' ', '\t'}
const C_SOL_CHARS* = Letters + {'-', '@', ')', '\\', ']', '$', ';', '#'}
const C_SET_IDENT* = Letters + {'-', '_'}
const C_SET_VALUE_CHARS* = C_QUOTES + Letters + Digits
const C_VAR_IDENT_CHARS* = C_SET_IDENT
const C_VAR_VALUE_CHARS* = C_SET_VALUE_CHARS
const C_FLG_IDENT_CHARS* = Letters + Digits + {'-', '.'}
const C_CMD_IDENT_START_CHARS* = Letters + {':'}
const C_CMD_IDENT_CHARS* = Letters + Digits + {'-', '_', '.', ':', '+', '\\', '/'}
const C_CMD_VALUE_CHARS* = {'-', 'd', '['}
