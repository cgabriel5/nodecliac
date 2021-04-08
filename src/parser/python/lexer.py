#!/usr/bin/env python3

from pathlib import Path # [https://stackoverflow.com/a/66195538]

hdir = str(Path.home())
acmappath = hdir + "/.nodecliac/registry/nodecliac/nodecliac.acmap"

f = open(acmappath, "r")
text = f.read()
# f = open("../../../resources/packages/nodecliac/nodecliac.acmap", "r")
# acmap = f.read()

# text = """a.{b,c} = --d|e $('${f}')"""

# text = """
# @setting="value"
# @setting = "value"

# nodecliac.print = --command=*$('${commands}') # comment

# 		  $var="123

# 		  "


# 		  $ var =      "
# 		  456  "
# """

# # Test .acmap string.
# text = """


# # Available settings.
# @compopt   = "default"
# @filedir   = ""
# @disable   = false
# @placehold = true

# # This is a comment.
#     # Whitespace can precede comment.
# program.command= !--flag # A trailing comment.
# program.SUBCOMMAND= --XXXX|--XXX-X2? # A trailing comment.

# program\\.command =[ *--flag # This is a trailing comment after flag

#       @setting = "123"
#       ;

# 	     	# This == a comment.

#       @setting = "456

# fsdpoifspdoif" # Trailing comment

# 	   		$var = "value.

# \\"

# 	   		     ";

# 		$var = 'not us\\'ing "'

# """

C_DOT = '.'
C_NL = '\n'
C_TAB = '\t'
C_PIPE = '|'
C_COMMA = ','
C_COLON = ':'
C_QMARK = '?'
C_SPACE = ' '
C_ATSIGN = '@'
C_HYPHEN = '-'
C_DQUOTE = '"'
C_SQUOTE = '\''
C_ESCAPE = '\\'
C_NUMSIGN = '#'
C_ASTERISK = '*'
C_EQUALSIGN = '='
C_SEMICOLON = ';'
C_DOLLARSIGN = '$'

C_LBRACE = '['
C_RBRACE = ']'
C_LPAREN = '('
C_RPAREN = ')'
C_LCURLY = '{'
C_RCURLY = '}'

SOT = { # Start-of-token chars.
	"#": "tkCMT",
	"@": "tkSTN",
	"$": "tkVAR",
	"-": "tkFLG",
	"?": "tkQMK",
	"*": "tkMTL",
	".": "tkDDOT",
	"\"": "tkSTR",
	"'": "tkSTR",
	"=": "tkAST",
	"|": "tkDPPE",
	",": "tkDCMA",
	":": "tkDCLN",
	";": "tkTRM",
	"(": "tkBRC",
	")": "tkBRC",
	"[": "tkBRC",
	"]": "tkBRC"
	# "{": "tkBRC",
	# "}": "tkBRC",
}

KEYWORDS = ["default", "filedir", "exclude"]

# Adds the token to tokens array.
def add_node():
	# Kind resets.
	if len(tokens):
		if cmd_chain:
			if kind("tkSTR") and tokens[-1]["kind"] == "tkCMD":
				if text[tokens[-1]["start"] : tokens[-1]["end"] + 1] in KEYWORDS:
					tokens[-1]["kind"] = "tkKYW"
			elif kind("tkCMD") and tokens[-1]["kind"] == "tkFLG":
				if text[tokens[-1]["start"] : tokens[-1]["end"] + 1] == C_HYPHEN:
					tokens[-1]["kind"] = "tkFOPT"
					S["kind"] = "tkFVAL"

		elif flag_options:
			if kind("tkCMD") and flag_options:
				S["kind"] = "tkFVAL"

	copy = dict(S)
	del copy["i"]
	tokens.append(copy)
	S["kind"] = ""

# Checks whether current tokens is at needed char index.
def charpos(position):
	return S["i"] - S["start"] == position - 1

# Checks state object kind matches provided kind.
def kind(s):
	return S["kind"] == s

# Forward loop x amount.
def forward(amount):
	S["i"] += amount

# Rollback loop x amount.
def rollback(amount):
	S["i"] -= amount

# Get previous iteration char.
def prevchar():
	return text[S["i"] - 1]

tokens = []

S = {"i": 0, "line": 1, "kind": "", "start": -1, "end": -1}
rolledback = False
cmd_chain = False
flag_options = False
l = len(text)
c = ''
while S["i"] < l:
	c = text[S["i"]]

	if S["kind"] or rolledback:
		if rolledback:
			rolledback = False
			S["start"] = S["i"]
			S["kind"] = SOT.get(c, "tkTBD")
			if S["kind"] == "tkTBD":
				if c.isalnum(): S["kind"] = "tkCMD"

		if kind("tkSTN") or kind("tkVAR") or kind("tkFLG"):
			if S["i"] - S["start"] > 0 and not (c.isalnum() or c == C_HYPHEN):
				rollback(1)
				S["end"] = S["i"]
				add_node()

		elif kind("tkCMD"):
			if not (c.isalnum() or (c == C_DOT and prevchar() == C_ESCAPE)
					or c == C_HYPHEN or c == C_ESCAPE or
					(prevchar() == C_ESCAPE)): # Allow escaped chars.
				rollback(1)
				S["end"] = S["i"]
				add_node()

		elif kind("tkCMT"):
			if c == C_NL:
				rollback(1)
				S["end"] = S["i"]
				add_node()

		elif kind("tkSTR"):
			if (not charpos(1) and c == text[S["start"]] and
					prevchar() != C_ESCAPE):
				S["end"] = S["i"]
				add_node()

		elif kind("tkTBD"): # Undetermined.
			S["end"] = S["i"]
			if c == C_SPACE or c == C_TAB or c == C_NL: S["end"] -= 1
			add_node()

		elif kind("tkBRC"):
			if c == C_LPAREN: flag_options = True
			elif c == C_RPAREN: flag_options = False
			elif c == C_LBRACE: cmd_chain = True
			elif c == C_RBRACE: cmd_chain = False
			S["end"] = S["i"]
			add_node()

		# All else (assignment, multi, delimiters, qmarks, terminator...).

		else:
			S["end"] = S["i"]
			add_node()

	else:
		if c == C_SPACE or c == C_NL or c == C_TAB:
			if c == C_NL: S["line"] += 1
			S["i"] += 1
			continue
		else:
			rolledback = True
			rollback(1)

	forward(1)

f = open("output.text", "r")
assert str(tokens) == f.read(), "Strings should match"
f.close()

print("Node_Count: [" + str(len(tokens)) + "]")
for node in tokens:
	kind = node["kind"]
	start = node["start"]
	end = node["end"]
	line = node["line"]
	print("L: " + str(line) + ", K: [" + kind + "] V: [" + text[start : end + 1] + "]")
