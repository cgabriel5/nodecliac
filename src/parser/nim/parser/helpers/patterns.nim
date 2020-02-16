from strutils import Digits, Letters, Newlines

# Start-of-line characters.
const c_sol_chars* = Letters + {'-', '@', ')', '\\', ']', '$', ';', '#'}
const c_nl* = Newlines
const c_letters* = Letters
const c_spaces* = {' ', '\t'} # Whitespace.
const c_quotes* = {'"', '\''}
const c_setting_chars* = Letters + {'-', '_'}
const c_setting_value* = c_quotes + Letters + Digits
const c_flag_chars* = Letters + Digits + {'-', '.'}
const c_command_fchars* = Letters + {':'}
const c_command_chars* = Letters + Digits + {'-', '_', '.', ':', '+', '\\', '/'}
const c_command_vchars* = {'-', 'd', '['}
