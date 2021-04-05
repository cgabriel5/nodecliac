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
C_SPACE = ' '
C_ATSIGN = '@'
C_DQUOTE = '"'
C_SQUOTE = '\''
C_ESCAPE = '\\'
C_NUMSIGN = '#'
C_EQUALSIGN = '='
C_SEMICOLON = ';'
C_DOLLARSIGN = '$'
C_HYPHEN = '-'
C_QMARK = '?'
C_ASTERISK = '*'
C_PIPE = '|'
C_COMMA = ','


C_LBRACE = '['
C_RBRACE = ']'
C_LPAREN = '('
C_RPAREN = ')'

C_LCURLY = '{'
C_RCURLY = '}'

SON = { # Start-of-node chars.
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

nodes = []

S = {"i": 0, "line": 1, "kind": "", "start": -1, "end": -1}
rolledback = False
l = len(text)
c = ''
while S["i"] < l:
	c = text[S["i"]]

	if c == C_NL:
		S["line"] += 1

	# print("---------------------------------", "["+c+"]", S["kind"])


	if S["kind"] or rolledback:
		if rolledback:
			rolledback = False
			S["start"] = S["i"]
			son = SON.get(c, "")
			if son:
				S["kind"] = son
			else:
				# if (c == C_LPAREN or c == C_RPAREN or c == C_LCURLY or c == C_RCURLY):
					# S["kind"] = "brace"
				# else: S["kind"] = "-----"
				S["kind"] = "-----"
				# print("---------------------------------++++++++", "["+c+"]", S["kind"])
				# print("ERROR: invalid SON.", "[" + c + "]")
		# S["kind"] += c
		if S["kind"] == "setting":
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
					# if c == C_SPACE or c == C_NL or c == C_TAB:
					S["i"] -= 1

					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
					# else:
						# print("ERROR: invalid char (not alphanumeric).", c, S["i"])

		elif S["kind"] == "variable":
			if S["i"] - S["start"] == 0:
				if c != C_DOLLARSIGN:
					print("ERROR: invalid sigil (not $).")
			elif S["i"] - S["start"] == 1:
				# Must be a letter.
				if not c.isalpha():
					if c == C_LPAREN:

						S["kind"] = "dollarsign"
						# S["i"] -= 2
						# S["start"] = S["i"]

						S["i"] -= 1

						S["end"] = S["i"]
						copy = dict(S)
						del copy['i']
						nodes.append(copy)
						S["kind"] = ""


					else:
						print("ERROR: invalid char 111 (not alpha).", "["+ c + "]", S["i"])

			else:
				# Can be letters/numbers now.
				if not c.isalnum():
					# if c == C_SPACE or c == C_NL or c == C_TAB:
					S["i"] -= 1

					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
					# else:
						# print("ERROR: invalid char (not alphanumeric).", c, S["i"])

		elif S["kind"] == "comment":
			if S["i"] - S["start"] == 0:
				if c != C_NUMSIGN:
					print("ERROR: invalid sigil (not #).")
			else:
				if c == C_NL:
					S["i"] -= 1

					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""

		elif S["kind"] == "assignment":
			if S["i"] - S["start"] == 0:
				if c == C_EQUALSIGN:
					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
				else:
					print("ERROR: invalid char (not =).")

		elif S["kind"] == "multi":
			if S["i"] - S["start"] == 0:
				if c == C_ASTERISK:
					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
				else:
					print("ERROR: invalid char (not =).")


		elif S["kind"] == "delpipe":
			if S["i"] - S["start"] == 0:
				if c == C_PIPE:
					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
				else:
					print("ERROR: invalid char (not |).")

		elif S["kind"] == "delcomma":
			if S["i"] - S["start"] == 0:
				if c == C_COMMA:
					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
				else:
					print("ERROR: invalid char (not |).")


		# elif S["kind"] == "left-cmd-str":

		# 	if S["i"] - S["start"] == 0:
		# 		if not c == C_DOLLARSIGN:
		# 			print("ERROR: invalid sigil (not $).")
		# 	elif S["i"] - S["start"] == 1:
		# 		if c == C_LPAREN:
		# 			S["end"] = S["i"]
		# 			copy = dict(S)
		# 			del copy['i']
		# 			nodes.append(copy)
		# 			S["kind"] = ""
		# 		else:
		# 			print("ERROR: invalid char (not ().")


		# elif S["kind"] == "dollarsign":

		# 	print("++++++++++++++", c, S["i"] - S["start"])
		# 	if S["i"] - S["start"] == 0:
		# 		if c == C_DOLLARSIGN:
		# 			S["end"] = S["i"]
		# 			copy = dict(S)
		# 			del copy['i']
		# 			nodes.append(copy)
		# 			S["kind"] = ""
		# 		else:
		# 			print("ERROR: invalid sigil (not $).")
		# 	# elif S["i"] - S["start"] == 1:
		# 	# 	if c == C_LPAREN:
		# 	# 		S["end"] = S["i"]
		# 	# 		copy = dict(S)
		# 	# 		del copy['i']
		# 	# 		nodes.append(copy)
		# 	# 		S["kind"] = ""
		# 	# 	else:
		# 	# 		print("ERROR: invalid char (not ().")




		if S["kind"] == "-----":
			# if c == C_SPACE or c == C_NL or c == C_TAB:
			# 	S["i"] -= 1

			# 	S["end"] = S["i"]
			# 	copy = dict(S)
			# 	del copy['i']
			# 	nodes.append(copy)
			# 	S["kind"] = ""

			# print("............", "["+c+"]")

			# print("---------------------------------++++++++=========", "["+c+"]", S["kind"])

# a.{b,c} = --d|e $('${f}')

			# if (c == C_COMMA or c == C_LPAREN or c == C_RPAREN or c == C_LCURLY or c == C_RCURLY):
			# 	S["i"] -= 1
			# 	S["kind"] = "brace"
			# 	# print("$$$$$$$$$", c)


			# 	# S["end"] = S["i"]
			# 	# copy = dict(S)
			# 	# del copy['i']
			# 	# nodes.append(copy)
			# 	# # S["kind"] = "-----"


			if not (c.isalnum() or c == C_DOT or c == C_ESCAPE):
				# S["i"] -= 1

				S["end"] = S["i"] - 1
				copy = dict(S)
				del copy['i']
				# print(copy)
				nodes.append(copy)
				S["kind"] = ""


				if (c == C_LPAREN or c == C_RPAREN or c == C_LCURLY or c == C_RCURLY):
					S["start"] = S["i"]
					# print(">>", S["i"])
					S["i"] -= 1
					S["kind"] = "brace"
					# print("$$$$$$$$$", c)



				elif (c == C_COMMA):
					S["start"] = S["i"]
					# print(">>", S["i"])
					S["i"] -= 1
					S["kind"] = "delcomma"
					# print("$$$$$$$$$", c)


					# S["end"] = S["i"]
					# copy = dict(S)
					# del copy['i']
					# nodes.append(copy)
					# # S["kind"] = "-----"

			# else:
			# 	# print("....1", text[S["i"]])
			# 	# S["i"] -= 1
			# 	# print("....2", text[S["i"]])
			# 	S["kind"] = ""



			# if S["i"] - S["start"] == 0:
			# 	if c != C_ATSIGN:
			# 		print("ERROR: invalid sigil (not @).")
			# elif S["i"] - S["start"] == 1:
			# 	# Must be a letter.
			# 	if not c.isalpha():
			# 		print("ERROR: invalid char (not alpha).")
			# else:
			# 	# Can be letters/numbers now.
			# 	if not c.isalnum():
			# 		# if c == C_SPACE or c == C_NL or c == C_TAB:
			# 		S["i"] -= 1

			# 		S["end"] = S["i"]
			# 		copy = dict(S)
			# 		del copy['i']
			# 		nodes.append(copy)
			# 		S["kind"] = ""
			# 		# else:
			# 			# print("ERROR: invalid char (not alphanumeric).", c, S["i"])




		elif S["kind"] == "brace":


			# print("-----", c)

			# if S["i"] - S["start"] == 0:
			if (
				c == C_LBRACE or c == C_RBRACE or
				c == C_LPAREN or c == C_RPAREN or
				c == C_LCURLY or c == C_RCURLY
			):
				S["end"] = S["i"]
				copy = dict(S)
				del copy['i']
				nodes.append(copy)
				S["kind"] = ""
			else:
				print("ERROR: invalid sigil (not brace).")




		elif S["kind"] == "string":
			if S["i"] - S["start"] == 0:
				if not (c == C_DQUOTE or c == C_SQUOTE):
					print("ERROR: invalid char (not a quote).", "[" + c + "]")
			elif c == text[S["start"]] and text[S["i"] - 1] != C_ESCAPE:
				S["end"] = S["i"]
				copy = dict(S)
				del copy['i']
				nodes.append(copy)
				S["kind"] = ""

		elif S["kind"] == "flag":
			if S["i"] - S["start"] == 0:
				if c != C_HYPHEN:
					print("ERROR: invalid sigil (not -).")
			# elif S["i"] - S["start"] == 1:
			# 	# Must be a letter.
			# 	if not c.isalpha():
			# 		print("ERROR: invalid char (not alpha).")
			else:
				# Can be letters/numbers now.
				if not (c.isalnum() or c == C_HYPHEN or c == C_QMARK):
					# if c == C_SPACE or c == C_NL or c == C_TAB:

					S["i"] -= 1

					S["end"] = S["i"]
					copy = dict(S)
					del copy['i']
					nodes.append(copy)
					S["kind"] = ""
					# else:
						# print("ERROR: invalid char (not alphanumeric).", c, S["i"])

		elif S["kind"] == "terminator":
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

f = open("output.text", "r")
assert str(nodes) == f.read(), "Strings should match"
f.close()

print("Node_Count: [" + str(len(nodes)) + "]")
for node in nodes:
	kind = node["kind"]
	start = node["start"]
	end = node["end"]
	line = node["line"]
	print("L: " + str(line) + ", K: [" + kind + "] V: [" + text[start : end + 1] + "]")
