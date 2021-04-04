#!/usr/bin/env python3

from pathlib import Path # [https://stackoverflow.com/a/66195538]

hdir = str(Path.home())
acmappath = hdir + "/.nodecliac/registry/nodecliac/nodecliac.acmap"

# f = open(acmappath, "r")
# text = f.read()
# f = open("../../../resources/packages/nodecliac/nodecliac.acmap", "r")
# acmap = f.read()

# Test .acmap string.
text = """
      @setting = "123"
      ;

	     	# This == a comment.

      @setting = "456

fsdpoifspdoif" # Trailing comment

	   		$var = "value.

\\"

	   		     ";

		$var = 'not us\\'ing "'

"""

C_NL = '\n'
C_TAB = '\t'
C_SPACE = ' '
C_ATSIGN = '@'
C_DQUOTE = '"'
C_SQUOTE = '\''
C_ESCAPE = '\\'
C_NUMSIGN = '#'
C_EQUALSIGN = '='
C_SEMICOLON = ';'
C_DOLLARSIGN = '$'

SON = { # Start-of-node chars.
	"#": "comment",
	"@": "setting",
	"$": "variable",

	";": "terminator",

	"=": "assignment",
	"\"": "string",
	"'": "string"
}

nodes = []

S = {"i": 0, "line": 1, "kind": "", "start": -1, "end": -1}
rolledback = False
l = len(text)
c = ''
while S["i"] < l:
	c = text[S["i"]]

	if c == C_NL:
		S["line"] += 1

	if S["kind"] or rolledback:
		if rolledback:
			rolledback = False
			S["start"] = S["i"]
			son = SON.get(c, "")
			if son:
				S["kind"] = son
			else:
				print("ERROR: invalid SON.", "[" + c + "]")
		# S["kind"] += c
		son = S["kind"]
		if son == "setting":
			if S["i"] - S["start"] == 0:
				if c != C_ATSIGN:
					print("ERROR: invalid sigil (not @).")
			elif S["i"] - S["start"] == 1:
				# Must be a letter.
				if not c.isalpha():
					print("ERROR: invalid char (not alpha).")
			else:
				# Can be letters/numbers now.
				if not c.isalnum():
					if c == C_SPACE or c == C_NL or c == C_TAB:
						S["end"] = S["i"] - 1
						copy = dict(S)
						del copy['i']
						nodes.append(copy)
						S["kind"] = ""
					else:
						print("ERROR: invalid char (not alphanumeric).", c, S["i"])

		elif son == "variable":
			if S["i"] - S["start"] == 0:
				if c != C_DOLLARSIGN:
					print("ERROR: invalid sigil (not $).")
			elif S["i"] - S["start"] == 1:
				# Must be a letter.
				if not c.isalpha():
					print("ERROR: invalid char (not alpha).")
			else:
				# Can be letters/numbers now.
				if not c.isalnum():
					if c == C_SPACE or c == C_NL or c == C_TAB:
						S["end"] = S["i"] - 1
						copy = dict(S)
						del copy['i']
						nodes.append(copy)
						S["kind"] = ""
					else:
						print("ERROR: invalid char (not alphanumeric).", c, S["i"])

		elif son == "comment":
			if S["i"] - S["start"] == 0:
				if c != C_NUMSIGN:
					print("ERROR: invalid sigil (not #).")
			else:
				if c == C_NL:
					S["end"] = S["i"] - 1
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""

		elif son == "assignment":
			if S["i"] - S["start"] == 0:
				if c == C_EQUALSIGN:
					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
				else:
					print("ERROR: invalid char (not =).")

		elif son == "string":
			if S["i"] - S["start"] == 0:
				if not (c == C_DQUOTE or c == C_SQUOTE):
					print("ERROR: invalid char (not a quote).", "[" + c + "]")
			elif c == text[S["start"]] and text[S["i"] - 1] != C_ESCAPE:
				S["end"] = S["i"]
				copy = dict(S)
				del copy['i']
				nodes.append(copy)
				S["kind"] = ""

		elif son == "terminator":
			if S["i"] - S["start"] == 0:
				if c != C_SEMICOLON:
					print("ERROR: invalid char (not ;).")

				S["end"] = S["i"]
				copy = dict(S)
				del copy['i']
				nodes.append(copy)
				S["kind"] = ""

	else:
		if c == C_SPACE or c == C_NL or c == C_TAB:
			S["i"] += 1
			continue
		else:
			rolledback = True
			S["i"] -= 1

	S["i"] += 1

print("Node_Count: [" + str(len(nodes)) + "]")
for node in nodes:
	kind = node["kind"]
	start = node["start"]
	end = node["end"]
	line = node["line"]
	print("L: " + str(line) + ", K: [" + kind + "] V: [" + text[start : end + 1] + "]")
