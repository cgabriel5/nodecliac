import std/[sets, strutils]

# [Bug, Notice]: Compiler gives a warning importing constants.
# [https://github.com/nim-lang/Nim/issues/13673]

# Chars

const C_NULLB* = '\0'
const C_ESCAPE* = '\\'

const C_N0* = '0'

const C_LA* = 'a'
const C_LC* = 'c'
const C_LD* = 'd'
const C_LF* = 'f'
const C_UA* = 'A'
const C_UC* = 'C'
const C_UF* = 'F'

const C_LPAREN* = '('
const C_RPAREN* = ')'
const C_LCURLY* = '{'
const C_RCURLY* = '}'
const C_LBRACKET* = '['
const C_RBRACKET* = ']'

const C_DOT* = '.'
const C_PIPE* = '|'
const C_COMMA* = ','
const C_COLON* = ':'
const C_SPACE* = ' '
const C_SPTAB* = '\t'
const C_QMARK* = '?'
const C_ATSIGN* = '@'
const C_DQUOTE* = '"'
const C_HYPHEN* = '-'
const C_SQUOTE* = '\''
const C_EXPOINT* = '!'
const C_NUMSIGN* = '#'
const C_PLUSSIGN* = '+'
const C_ASTERISK* = '*'
const C_EQUALSIGN* = '='
const C_SEMICOLON* = ';'
const C_DOLLARSIGN* = '$'
const C_UNDERSCORE* = '_'

# Sets

const C_NL* = Newlines
const C_LETTERS* = Letters
const AlphaNum* = Letters + Digits
const C_QUOTES* = { C_DQUOTE, C_SQUOTE }
const C_SPACES* = { C_SPACE, C_SPTAB }
const C_SOL* = Letters + { C_HYPHEN, C_ATSIGN, C_RPAREN, C_ESCAPE,
        C_RBRACKET, C_DOLLARSIGN, C_SEMICOLON, C_NUMSIGN, C_ASTERISK }
const C_SET_IDENT* = Letters + { C_HYPHEN, C_UNDERSCORE }
const C_SET_VALUE* = C_QUOTES + AlphaNum
const C_VAR_IDENT* = C_SET_IDENT
const C_VAR_VALUE* = C_SET_VALUE
const C_FLG_IDENT* = AlphaNum + { C_HYPHEN, C_DOT }
const C_CMD_IDENT_START* = Letters + { C_COLON, C_ASTERISK }
const C_CMD_GRP_IDENT_START* = AlphaNum + { C_COLON, C_ASTERISK }
const C_CMD_IDENT* = AlphaNum + { C_HYPHEN, C_UNDERSCORE,
        C_DOT, C_COLON, C_PLUSSIGN, C_ESCAPE }
const C_CMD_VALUE* = { C_HYPHEN, C_LC, C_LD, C_LF, C_LBRACKET }
const C_KW_ALL* = ["context", "default", "filedir", "exclude"]
const C_KD_STR* = ["context", "filedir", "exclude"]
const C_CTX_MUT* = AlphaNum + { C_HYPHEN, C_RCURLY, C_PIPE }
const C_CTX_CON* = AlphaNum + { C_NUMSIGN, C_HYPHEN, C_EXPOINT, C_COMMA }
const C_CTX_ALL* = AlphaNum + { C_NUMSIGN, C_HYPHEN, C_LCURLY, C_RCURLY,
        C_PIPE, C_EXPOINT, C_COLON, C_SEMICOLON, C_COMMA }
const C_CTX_FLG* = AlphaNum + { C_HYPHEN, C_EXPOINT, C_COMMA, C_COLON }
const C_CTX_OPS* = toHashSet(["eq", "ne", "gt", "ge", "lt", "le"])
const C_CTX_CAT* = { C_LA, C_UA, C_LF, C_UF} # Conditional argument-count type.
const C_CTX_CTT* = { C_LC, C_UC} # Conditional test-count type.
