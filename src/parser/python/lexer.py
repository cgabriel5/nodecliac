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
	"#": "comment",
	"@": "setting",
	"$": "variable",
	"-": "flag",
	"*": "multi",
	",": "delcomma",
	"|": "delpipe",

	";": "terminator",

	"(": "brace",
	")": "brace",
	"[": "brace",
	"]": "brace",

	"=": "assignment",
	"\"": "string",
	"'": "string"
}

# Adds the token to tokens array.
def add_node():
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

tokens = []

S = {"i": 0, "line": 1, "kind": "", "start": -1, "end": -1}
rolledback = False
l = len(text)
c = ''
while S["i"] < l:
	c = text[S["i"]]

	if S["kind"] or rolledback:
		if rolledback:
			rolledback = False
			S["start"] = S["i"]
			S["kind"] = SOT.get(c, "-----")

		if kind("setting"):
			if charpos(1):
				if c != C_ATSIGN:
					print("Err: invalid sigil.")
			elif charpos(2):
				if not c.isalpha():
					print("Err: invalid char.")
			else:
				if not c.isalnum():
					rollback(1)
					S["end"] = S["i"]
					add_node()

		elif kind("variable"):
			if charpos(1):
				if c != C_DOLLARSIGN:
					print("Err: invalid sigil.")
			elif charpos(2):
				if not c.isalpha():
					if c == C_LPAREN:
						S["kind"] = "dollarsign"
						rollback(1)

						S["end"] = S["i"]
						add_node()

			else:
				if not c.isalnum():
					rollback(1)

					S["end"] = S["i"]
					add_node()

		elif kind("comment"):
			if charpos(1):
				if c != C_NUMSIGN:
					print("Err: invalid sigil.")
			else:
				if c == C_NL:
					rollback(1)

					S["end"] = S["i"]
					add_node()

		elif kind("flag"):
			if charpos(1):
				if c != C_HYPHEN:
					print("Err: invalid sigil (not -).")
			else:
				if not (c.isalnum() or c == C_HYPHEN):
					rollback(1)

					S["end"] = S["i"]
					add_node()

		elif kind("-----"): # Undetermined.
			if not (c.isalnum() or c == C_DOT or c == C_ESCAPE):
				if (c == C_LPAREN or c == C_RPAREN or
					c == C_LCURLY or c == C_RCURLY):
					S["start"] = S["i"]
					rollback(1)
					S["kind"] = "brace"

				elif c == C_COMMA:
					S["start"] = S["i"]
					rollback(1)
					S["kind"] = "delcomma"

				elif c == C_COLON:
					S["start"] = S["i"]
					rollback(1)
					S["kind"] = "delcolon"

				elif c == C_QMARK:
					S["start"] = S["i"]
					rollback(1)
					S["kind"] = "qmark"

				else:
					S["end"] = S["i"]
					if c == C_SPACE or c == C_TAB or c == C_NL: S["end"] -= 1
					add_node()

		elif kind("string"):
			if charpos(1):
				if not (c == C_DQUOTE or c == C_SQUOTE):
					print("Err: invalid char (not a quote).", "[" + c + "]")
			elif c == text[S["start"]] and text[S["i"] - 1] != C_ESCAPE:
				S["end"] = S["i"]
				add_node()

		# Punctuation characters.

		elif kind("assignment"):
			S["end"] = S["i"]
			add_node()

		elif kind("multi"):
			S["end"] = S["i"]
			add_node()

		elif kind("delpipe"):
			S["end"] = S["i"]
			add_node()

		elif kind("delcomma"):
			S["end"] = S["i"]
			add_node()

		elif kind("delcolon"):
			S["end"] = S["i"]
			add_node()

		elif kind("qmark"):
			S["end"] = S["i"]
			add_node()

		elif kind("brace"):
			S["end"] = S["i"]
			add_node()

		elif kind("terminator"):
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
