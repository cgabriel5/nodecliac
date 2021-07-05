#!/usr/bin/env ruby

require "set"

C_NL = "\n"
C_DOT = '.'
C_TAB = "\t"
C_PIPE = '|'
C_SPACE = ' '
C_QMARK = '?'
C_HYPHEN = '-'
C_ESCAPE = "\\"
C_LPAREN = '('
C_RPAREN = ')'
C_LCURLY = '{'
C_RCURLY = '}'
C_LBRACE = '['
C_RBRACE = ']'
C_ATSIGN = '@'
C_ASTERISK = '*'
C_DOLLARSIGN = '$'
C_UNDERSCORE = '_'

SOT = {  # Start-of-token chars.
	"#": "tkCMT",
	"@": "tkSTN",
	"$": "tkVAR",
	"-": "tkFLG",
	"?": "tkQMK",
	"*": "tkMTL",
	".": "tkDDOT",
	"\"": "tkSTR",
	"'": "tkSTR",
	"=": "tkASG",
	"|": "tkDPPE",
	",": "tkDCMA",
	":": "tkDCLN",
	";": "tkTRM",
	"(": "tkBRC",
	")": "tkBRC",
	"[": "tkBRC",
	"]": "tkBRC",
	"{": "tkBRC",
	"}": "tkBRC",
	"\n": "tkNL"
}

BRCTOKENS = {
	C_LPAREN => "tkBRC_LP",
	C_RPAREN => "tkBRC_RP",
	C_LCURLY => "tkBRC_LC",
	C_RCURLY => "tkBRC_RC",
	C_LBRACE => "tkBRC_LB",
	C_RBRACE => "tkBRC_RB"
}

$linestarts = {1 => -1}

KEYWORDS = ["default", "context", "filedir", "exclude"]
# Invalid command start-of-token chars.
XCSCOPES = [C_ATSIGN, C_DOT, C_LCURLY, C_RCURLY]

# [https://stackoverflow.com/a/12333839]
# [https://www.geeksforgeeks.org/set-in-cpp-stl/]
SPACES = Set[C_SPACE, C_TAB]
TkCMD_TK_TYPES = Set[C_HYPHEN, C_ESCAPE]
TkTBD_TK_TYPES = Set[
	C_SPACE, C_TAB, C_DOLLARSIGN, C_ATSIGN,
	C_PIPE, C_LCURLY, C_RCURLY, C_LBRACE,
	C_RBRACE, C_LPAREN, C_RPAREN, C_HYPHEN,
	C_QMARK, C_ASTERISK,
]
TkTBD_TK_TYPES2 = Set[C_NL, C_SPACE, C_TAB]
TkEOP_TK_TYPES = Set[C_SPACE, C_TAB, C_NL]
TkTYPES_RESET1 = Set["tkCMD", "tkTBD"]
TkTYPES_RESET2 = Set["tkCMD", "tkFLG", "tkSTN", "tkVAR"]
TkTYPES_RESET3 = Set["tkSTN", "tkVAR"]
TkTYPES_RESET4 = Set["tkCMT", "tkNL", "tkEOP"]

# [https://stackoverflow.com/a/10638425]
# [https://stackoverflow.com/a/13337427]
# [https://ruby-doc.org/core-1.9.3/Regexp.html]
# [https://stackoverflow.com/a/13371783]
def isalnum(s)
	return false if s.empty?
	if s =~ /\A\p{Alnum}+\z/
		return true
	end
	return false

	# puts isalnum("anc")
	# puts isalnum("anc12")
	# puts isalnum("anc12#")
	# puts isalnum("")
end

def isalpha(s)
	return false if s.empty?
	if s =~ /\A\p{Alpha}+\z/
		return true
	end
	return false

	# puts isalpha("abc")
	# puts isalpha("ab123")
	# puts isalpha("")
end

$dtids = {}
$ttids = []
$tokens = []
$ttypes = {}
$token_count = 0
$cmdscope = false
$valuelist = false # Value list.
$brcparens = []

def tokenizer(text)
	c = ''
	s = {"i": 0, "line": 1, "kind": ""}

	s[:start] = -1
	s[:end] = -1
	l = text.length

	# Adds the token to tokens array.
	def add_token(s, text)
		if !$ttids.empty? && !$tokens.empty?
			prevtk = $tokens[$ttids[-1]]

			# Keyword reset.
			if (kind(s, "tkSTR") && (prevtk[:kind] == "tkCMD" ||
				($cmdscope && prevtk[:kind] == "tkTBD")))
				if KEYWORDS.include?(text[prevtk[:start] .. prevtk[:end]])
					prevtk[:kind] = "tkKYW"
				end

			# Reset: default $("cmd-string")
			elsif (kind(s, "tkVAR") && s[:end] - s[:start] == 0 &&
				(prevtk[:kind] == "tkCMD" ||
					($cmdscope && prevtk[:kind] == "tkTBD")))
				if text[prevtk[:start] .. prevtk[:end]] == "default"
					prevtk[:kind] = "tkKYW"
				end

			elsif $valuelist && s[:kind] == "tkFLG" && s[:start] == s[:end]
				s[:kind] = "tkFOPT" # Hyphen.

			# When parsing a value list '--flag=()', that is not a
			# string/command-string should be considered a value.
			elsif $valuelist && TkTYPES_RESET1.include?(s[:kind])
				s[:kind] = "tkFVAL"

			# 'Merge' tkTBD tokens if possible.
			elsif (kind(s, "tkTBD") && prevtk[:kind] == "tkTBD" and
				  prevtk[:line] == s[:line] and
				  s[:start] - prevtk[:end] == 1)
				prevtk[:end] = s[:end]
				s[:kind] = ""
				return

			elsif kind(s, "tkCMD") || kind(s, "tkTBD")
				# Reverse loop to get find first command/flag tokens.
				lastpassed = ""
				# [https://stackoverflow.com/a/19887835]
				for i in ($token_count - 1).downto(0)
					lkind = $ttypes[i]
					if TkTYPES_RESET2.include?(lkind)
						lastpassed = lkind
						break
					end
				end

				# Handle: 'program = --flag::f=123'
				if (prevtk[:kind] == "tkASG" and
					prevtk[:line] == s[:line] and
					lastpassed == "tkFLG")
					s[:kind] = "tkFVAL"
				end

				if s[:kind] != "tkFVAL" && $ttids.length() > 1
					prevtk2 = $tokens[$ttids[-2]][:kind]

					# Flag alias '::' reset.
					if (prevtk[:kind] == "tkDCLN" && prevtk2 == "tkDCLN")
						s[:kind] = "tkFLGA"
					end

					# Setting/variable value reset.
					if prevtk[:kind] == "tkASG" && TkTYPES_RESET3.include?(prevtk2)
						s[:kind] = "tkAVAL"
					end
				end
			end
		end

		# Reset when single '$'.
		if kind(s, "tkVAR") && s[:end] - s[:start] == 0
			s[:kind] = "tkDLS"
		end

		# If a brace token, reset kind to brace type.
		if kind(s, "tkBRC")
			s[:kind] = BRCTOKENS.fetch(text[s[:start]])
		end

		# Universal command multi-char reset.
		if kind(s, "tkMTL") && (!$tokens || $tokens[-1][:kind] != "tkASG")
			s[:kind] = "tkCMD"
		end

		$ttypes[$token_count] = s[:kind]
		if !TkTYPES_RESET4.include?(s[:kind])
			# Track token ids to help with parsing.
			$dtids[$token_count] = $token_count && !$ttids.empty? ? $ttids[-1] : 0
			$ttids.append($token_count)
		end

		copy = s.clone()
		copy.delete(:i)
		if s.key?(:last)
			s.delete(:last)
			copy.delete(:last)
		end
		copy[:tid] = $token_count
		$tokens.append(copy)
		s[:kind] = ""

		if s.key?(:lines)
			s.delete(:lines)
		end

		if s.key?(:list)
			s.delete(:list)
		end

		$token_count += 1
	end

	# Checks if token is at needed char index.
	def charpos(s, pos)
		return s[:i] - s[:start] == pos - 1
	end

	# Checks state object kind matches provided kind.
	def kind(s, k)
		return s[:kind] == k
	end

	# Forward loop x amount.
	def forward(s, amount)
		s[:i] += amount
	end

	# Rollback loop x amount.
	def rollback(s, amount)
		s[:i] -= amount
	end

	# Get previous iteration char.
	def prevchar(s, text)
		return text[s[:i] - 1]
	end

	def tk_eop(s, c, text) # Determine in parser.
		s[:kind] = "tkEOP"
		s[:end] = s[:i]
		if TkEOP_TK_TYPES.include?(c)
			s[:end] -= 1
		end
		add_token(s, text)
	end

	while s[:i] < l do
		c = text[s[:i]]

		# Add 'last' key on last iteration.
		if s[:i] == l - 1
			s[:last] = true
		end

		if s[:kind] == ""
			if Set[C_SPACE, C_TAB].include?(c)
				forward(s, 1)
				next
			end

			if c == C_NL
				s[:line] += 1
				$linestarts[s[:line]] = s[:i]
			end

			s[:start] = s[:i]
			s[:kind] = SOT.fetch(c.to_sym, "tkTBD")
			if s[:kind] == "tkTBD"
				if ((!$cmdscope && isalnum(c)) ||
					($cmdscope && XCSCOPES.include?(c) && isalpha(c)))
					s[:kind] = "tkCMD"
				end
			end
		end

		case s[:kind]
			when "tkSTN"
				if s[:i] - s[:start] > 0 && !isalnum(c)
					rollback(s, 1)
					s[:end] = s[:i]
					add_token(s, text)
				end
			when "tkVAR"
				if s[:i] - s[:start] > 0 && !(isalnum(c) || c == C_UNDERSCORE)
					rollback(s, 1)
					s[:end] = s[:i]
					add_token(s, text)
				end
			when "tkFLG"
				if s[:i] - s[:start] > 0 && !(isalnum(c) || c == C_HYPHEN)
					rollback(s, 1)
					s[:end] = s[:i]
					add_token(s, text)
				end
			when "tkCMD"
				if !(isalnum(c) || TkCMD_TK_TYPES.include?(c) ||
					(prevchar(s, text) == C_ESCAPE)) # Allow escaped chars.
					rollback(s, 1)
					s[:end] = s[:i]
					add_token(s, text)
				end
			when "tkCMT"
				if c == C_NL
					rollback(s, 1)
					s[:end] = s[:i]
					add_token(s, text)
				end
			when "tkSTR"
				# Store initial line where string starts.
				# [https://stackoverflow.com/a/18358357]
				if !s.key?(:lines)
					s[:lines] = [s[:line], -1]
				end

				# Account for '\n's in string to track where string ends
				if c == C_NL
					s[:line] += 1
					$linestarts[s[:line]] = s[:i]
				end

				if !charpos(s, 1) && c == text[s[:start]] &&
					prevchar(s, text) != C_ESCAPE
					s[:end] = s[:i]
					s[:lines][1] = s[:line]
					add_token(s, text)
				end
			when "tkTBD"
				s[:end] = s[:i]
				if (c == C_NL || TkTBD_TK_TYPES.include?(c) &&
					(prevchar(s, text) != C_ESCAPE))
					if !TkTBD_TK_TYPES2.include?(c)
						rollback(s, 1)
						s[:end] = s[:i]
					else
						# Let '\n' pass through to increment line count.
						if c == C_NL
							rollback(s, 1)
						end
						s[:end] -= 1
					end
					add_token(s, text)
				end
			when "tkBRC"
				if c == C_LPAREN
					if $tokens[$ttids[-1]][:kind] != "tkDLS"
						$valuelist = true
						$brcparens.append(0) # Value list.
						s[:list] = true
					else
						$brcparens.append(1)
					end # Command-string.
				elsif c == C_RPAREN
					if $brcparens.pop() == 0
						$valuelist = false
						s[:list] = true
					end
				elsif c == C_LBRACE
					$cmdscope = true
				elsif c == C_RBRACE
					$cmdscope = false
				end
				s[:end] = s[:i]
				add_token(s, text)

			else # tkDEF
				s[:end] = s[:i]
				add_token(s, text)
		end

		# Run on last iteration.
		if s.key?(:last)
			tk_eop(s, c, text)
		end

		forward(s, 1)
	end

	# To avoid post parsing checks, add a special end-of-parsing token.
	s[:kind] = "tkEOP"
	s[:start] = -1
	s[:end] = -1
	add_token(s, text)
end
