#!/bin/bash

# Command name provided from sourced passed-in argument.
if [[ ! -z "$1" ]] && type complete &>/dev/null; then
	# Bash general purpose CLI auto completion script.
	function _nodecliac() {
		# Get command name from sourced passed-in argument.
		local maincommand="$1"

		# Built-in auto completion vars.
		# local cur="${COMP_WORDS[COMP_CWORD]}" # Currently typed in word.
		# local prev="${COMP_WORDS[COMP_CWORD-1]}" # Word before current word.
		# local input="${COMP_WORDS[@]}" # All CLI input.
		# local line="$COMP_LINE" # CLI input line.
		# local caretpos="$COMP_POINT" # Index of caret position.
		# local index="$COMP_CWORD" # Index of current word.

		# Vars.
		local args=()
		local last=""
		local type=""
		local usedflags=""
		local completions=()
		local commandchain=""
		local cline="$COMP_LINE" # Original (complete) CLI input.
		local cpoint="$COMP_POINT" # Caret index when [tab] key was pressed.
		local lastchar="${cline:$cpoint-1:1}" # Character before caret.
		local nextchar="${cline:$cpoint:1}" # Character after caret.
		local cline_length="${#cline}" # Original input's length.
		local isquoted=false
		local autocompletion=true

		# Boolean indicating whether to escape/unescape flags. Setting it to
		# true does incur a performance hit. As a result, completions might
		# not 'feel' as fast.
		local cleaninput=false

		# Get the acmap definitions file.
		local acmap="$(<~/.nodecliac/defs/$maincommand*)"
# [https://serverfault.com/questions/72476/clean-way-to-write-complex-multi-line-string-to-a-variable/424601#424601]
# local acmap=`cat <<EOF
# # [[__acmap__]]
# EOF
# `

		# # Join array items into a string.
		# #
		# # @param {array} 1) - Array to join.
		# # @return {string} - The joined string.
		# #
		# # @resource [https://stackoverflow.com/a/17841619]
		function __join() {
			# Delimiter type is based on the provided delimiters
			# character length.
			# 1 - Single Character Delimiter
			# 2 - Multi Character Delimiter

			# Use a single char delimiter.
			if [[ "${#1}" == 1 ]]; then
				local IFS="$1"; shift; echo "$*"
			# Use multiple char delimiter method.
			else
				local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"
			fi
		}

		# Remove array item by its index.
		#
		# @param {array} 1) - The array to remove item from.
		# @return {undefined} - Noting is returned.
		#
		# @resource [https://stackoverflow.com/a/25436989]
		function __rm_aitem() {
			eval "$1=( \"\${$1[@]:0:$2}\" \"\${$1[@]:$(($2+1))}\" )"
		}

		# # Trim left/right whitespace from string.
		# #
		# # @param {string} 1) - String to trim.
		# # @return {string} - The trimmed string.
		# function __trim() {
		# 	echo -e "$1" | sed -e "s/\(^ *\| *\$\)//g"
		# }

		# # Echoes supplied input (echo wrapper).
		# #
		# # @param {*} 1) - Value to echo out.
		# # @return {string} - The supplied input.
		# function __retval() {
		# 	echo "$1"
		# }

		# # Log local variables and their values.
		# #
		# function __debug() {
		# 	local inp="${cline:0:$cpoint}"
		# 	echo ""
		# 	echo "  commandchain: '$commandchain'"
		# 	echo "     usedflags: '$usedflags'"
		# 	echo "          last: '$last'"
		# 	echo "         input: '$inp'"
		# 	echo "  input length: '$cline_length'"
		# 	echo "   caret index: '$cpoint'"
		# 	echo "      lastchar: '$lastchar'"
		# 	echo "      nextchar: '$nextchar'"
		# 	echo "      isquoted: '$isquoted'"
		# 	echo "autocompletion: '$autocompletion'"
		# }

		# Unescape all backslash escaped characters in double quotes flags.
		#
		# @param {string} 1) - The string to unescape.
		# @return {string} - The unescaped string.
		#
		# @resource [https://stackoverflow.com/a/22261454]
		# @resource [https://stackoverflow.com/a/5659672]
		function __unescape() {
			# Get provided string.
			local s="$1"

			# Only continue if flag is set to true.
			if [[ "$cleaninput" == true ]]; then
				# String cannot be empty.
				if [[ -z "$s" ]]; then echo ""; fi

				# Regex → --flag="
				local r="^\-{1,2}[a-zA-Z0-9]([a-zA-Z0-9\-]{1,})?=\"{1,}$"

				# Only unescape if string is in the format --flag=".
				if [[ "$s" =~ $r ]]; then
					# Backslash regex.
					r='^(.*)\\(.)(.*)$'

					# Replace all until no more backslashes exist.
					while [[ "$s" =~ $r ]]; do
					  s="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
					done

					# Finally, remove any leftover singleton backslashes.
					s="${s//\\/}"
				fi
			fi

			# Return string.
			echo "$s"
		}

		# Escape special characters in double quoted strings.
		#
		# @param {string} 1) - The string to escape.
		# @return {string} - The escaped string.
		#
		# @resource [https://unix.stackexchange.com/a/170168]
		# @resource [https://unix.stackexchange.com/a/141323]
		# @resource [https://stackoverflow.com/a/6697781]
		# @resource [https://stackoverflow.com/a/42082956]
		# @resource [https://scriptingosx.com/2017/08/special-characters/]
		function __escape() {
			# Get provided string.
			local s="$1"

			# Only continue if flag is set to true.
			if [[ "$cleaninput" == true ]]; then
				# String cannot be empty.
				if [[ -z "$s" ]]; then echo ""; fi

				# Only escape if string starts with double quote.
				if [[ "$s" =~ ^\" ]]; then
					# Remove the starting quote from value.
					s="${s:1}"

					local ending_quote=false
					# Check for ending quote.
					if [[ "$s" =~ \"$ ]]; then
						# Remove ending character from value.
						# [https://unix.stackexchange.com/a/170168]
						s="${s%?}"

						# Set flag.
						ending_quote=true
					fi

					# Escape string: [https://unix.stackexchange.com/a/141323]
					s="`printf '%q\n' "$s"`"

					# Rebuild string with escaped value.
					s="\"${s}"

					# If ending quote existed, re-add it.
					if [[ "$ending_quote" == true ]]; then
						s+="\""
					fi
				fi
			fi

			# Return string.
			echo "$s"
		}

		# Global flag only to be used for __dupecheck function.
		local __dc_multiflags=""

		# Check whether provided flag is already used or not.
		#
		# @param {string} 1) - The flag to check.
		# @return {boolean} - True if duplicate. Else false.
		function __dupecheck() {
			# Get provided flag arg.
			local flag="$1"

			# Var boolean.
			local dupe=false
			local d="}|{" # Delimiter.

			# Get individual components from flag.
			local ckey="${flag%%=*}"

			# If its a multi-flag then let it through.
			if [[ "$__dc_multiflags" == *" $ckey "* ]]; then
				dupe=false

			# Valueless flag dupe check.
			elif [[ "$flag" != *"="* ]]; then
				if [[ " ${d} $usedflags " =~ " ${d} ${ckey} " ]]; then
					dupe=true
				fi

			# Flag with value dupe check.
			else
				# Count substring occurrences:
				# [https://unix.stackexchange.com/a/442353]
				ckey+="="
				remove=${usedflags//"$ckey"}
				count="$(((${#usedflags} - ${#remove}) / ${#ckey}))"

				# More than 1 occurrence flag has been used.
				if [[ $count -ge 1 ]]; then
				# if [[ $count -ge 1 && "$rows" != *"${ckey}*|"* ]]; then
					dupe=true
				fi

				# If there is exactly 1 occurrence and the flag matches the
				# ReGex pattern we undupe flag as the 1 occurrence is being
				# completed (i.e. a value is being completed).
				if [[ $count -eq 1 && "$flag" =~ $flgoptvalue ]]; then
					dupe=false
				fi
			fi

			# Return dupe boolean result.
			echo "$dupe"
		}

		# Global flag only to be used for __escaped_chars function.
		# local escape_chars=""

		# # Get list of characters that need escaping.
		# #
		# # @return {string} - Nothing is returned.
		# #
		# # @resource [https://stackoverflow.com/a/44581064]
		# function __escaped_chars() {
		# 	# Character list.
		# 	local chars=$'~`!@#$%^&*()-_+={}|[]\\;\':",.<>/? '

		# 	# Loop over each character to see whether it needs escaping.
		# 	for ((i=0; i < ${#chars}; i++)); do
		# 		# Get current iteration char.
		# 		local char="${chars:i:1}"

		# 		# Use printf to determine character escaping.
		# 		printf -v q_char '%q' "$char"

		# 		# Store chars needed escaping.
		# 		if [[ "$char" != "$q_char" ]]; then
		# 			escape_chars+=" $char "
		# 		fi
		# 	done
		# }; __escaped_chars # Immediately run function.

		# Check whether string is left quoted (i.e. starts with a quote).
		#
		# @param {string} 1) - The string to check.
		# @return {boolean} - True means it's left quoted.
		function __is_lquoted() {
			# Default to false.
			check=false

			# Check for left quote.
			if [[ "$1" =~ ^(\"|\') ]]; then
				check=true
			fi

			# Return check output.
			echo "$check"
		}

		# Get last command in chain: 'mc.sc1.sc2' → 'sc2'
		#
		# @param {string} 1) - The row to extract command from.
		# @param {number} 2) - The chain replacement type.
		# @return {string} - The last command in chain.
		function __last_command() {
			# Extract command chain from row.
			local row="${1%% *}"

			# Chain replacement depends on completion type.
			if [[ "$2" -eq 1 ]]; then
				row="${row/$commandchain\./}"
			else
				row="${row/"${row%.*}"\./}"
			fi

			# Extract next command in chain.
			echo "${row%%.*}"
		}

		# Parses CLI input. Returns input similar to that of process.argv.slice(2).
		#     Adapted from argsplit module.
		#
		# @resource [https://github.com/evanlucas/argsplit]
		# @resource - Other CLI input parsers:
		#     [https://github.com/elgs/splitargs]
		#     [https://github.com/vladimir-tikhonov/string-to-argv#readme]
		#     [https://github.com/astur/arrgv]
		#     [https://github.com/mccormicka/string-argv]
		#     [https://github.com/adarqui/argparser-js]
		function __parser() {
			# Note: Single quotes cannot be escaped inside single quotes.
			# [https://stackoverflow.com/a/6697781]
			# [https://stackoverflow.com/a/42082956]
			# [https://stackoverflow.com/a/20053121]

			# Handle COMP_WORDBREAKS without modifying global variable.
			# [https://github.com/npm/npm/issues/5820]
			# [https://github.com/npm/npm/issues/4530]
			# [https://stackoverflow.com/questions/10528695/how-to-reset-comp-wordbreaks-without-affecting-other-completion-script/12495480#12495480]
			# [https://github.com/npm/npm/commit/7e4d15f3039ae5bd6f659fb9ec684621f25e13f0]
			# [https://github.com/npm/npm/commit/d7271b8226712479cdd339bf85faf7e394923e0d]
			# _get_comp_words_by_ref -n = -n @ -n : -w completions -i last
			# _get_comp_words_by_ref -n = -n @ -n : -i last
			# ^^Parse CLI to circumvent COMP_WORDBREAKS issues. This also allows
			# one to have total control how the CLI input is parsed. CLI parsing
			# is meant to mimic that of Node.js CLI input parsing.

			# Vars.
			local current=""
			local input="$1"
			local quote_char=""
			local l="${#input}" # Input length.

			# Return empty array when input is empty.
			if [[ -z "$input" ]]; then
				return
			fi

			# Loop over every input char: [https://stackoverflow.com/a/10552175]
			for ((i = 0; i < "$cline_length"; i++ )); do
				# Cache current/previous/next chars.
				local c="${cline:$i:1}"
				local p="${cline:$i - 1:1}"
				local n="${cline:$i + 1:1}"
				# Reset prev word for 1st char as bash gets the last char.
				if [[ "$i" == 0 ]]; then
					p=""
				# Reset next word for last char as bash gets the first char.
				elif [[ "$i" == $(( $cline_length - 1  )) ]]; then
					n=""
				fi

				# Stop loop once it hits the caret position character.
				if [[ "$i" -ge $(( $l - 1 )) ]]; then
					# Only add if not a space character.
					if [[ "$c" != " " ]] || [[ "$c" == " " && "$p" == "\\" ]]; then
						current+="$c"
					fi

					# Store last char.
					lastchar="$c"
					# If last char is an escaped space then reset lastchar.
					if [[ "$c" == " " && "$p" == "\\" ]]; then lastchar=""; fi

					break
				fi

				# If char is a space.
				if [[ "$c" == " " && "$p" != "\\" ]]; then
					if [[ "${#quote_char}" != "0" ]]; then
						current+="$c"
					else
						if [[ "$current" != "" ]]; then
							args+=("`__unescape "$current"`")
							current=""
						fi
					fi
				# Non space chars.
				elif [[ "$c" == '"' || "$c" == "'" ]] && [[ "$p" != "\\" ]]; then
					if [[ "$quote_char"  != "" ]]; then
						# To end the current string encapsulation, the next
						# char must be a space or nothing (meaning) the end
						# if the input string. This is done to prevent
						# this edge case: 'myapp run "some"--'. Without this
						# check the following args get parsed:
						# args=(myapp run "some" --). What we actually want
						# is args=(myapp run "some"--).
						#
						if [[ "$quote_char" == "$c" ]] && [[ "$n" == "" || "$n" == " " ]]; then
							current+="$c"
							args+=("`__unescape "$current"`")
							quote_char=""
							current=""
						elif [[ "$quote_char" == '"' || "$quote_char" == "'" ]] && [[ "$p" != "\\" ]]; then
							current+="$c"
						else
							current+="$c"
							quote_char="$c"
						fi
					else
						current+="$c"
						quote_char="$c"
					fi
				else
					current+="$c"
				fi
			done

			# Add the remaining word.
			if [[ "$current" != "" ]]; then
				args+=("`__unescape "$current"`")
			fi
		}

		# Lookup command/subcommand/flag definitions from the acmap to return
		#     possible completions list.
		#
		# Test input:
		# myapp run example go --global-flag value
		# myapp run example go --global-flag value subcommand
		# myapp run example go --global-flag value --flag2
		# myapp run example go --global-flag value --flag2 value
		# myapp run example go --global-flag value --flag2 value subcommand
		# myapp run example go --global-flag value --flag2 value subcommand --flag3
		# myapp run example go --global-flag --flag2
		# myapp run example go --global-flag --flag value subcommand
		# myapp run example go --global-flag --flag value subcommand --global-flag --flag value
		# myapp run example go --global-flag value subcommand
		# myapp run "some" --flagsin command1 sub1 --flag1 val
		# myapp run -rd '' -a config
		# myapp --Wno-strict-overflow= config
		function __extracter() {
			# Vars.
			local l="${#args[@]}"
			local oldchains=()
			local foundflags=()

			# Loop over CLI arguments.
			for ((i = 1; i < "${#args[@]}"; i++)); do
				# Cache current loop item.
				local item="${args[i]}"
				local nitem="${args[i + 1]}"

				# Skip quoted (string) items.
				if [[ `__is_lquoted "$item"` == true ]]; then
					continue
				fi

				# Reset next item if it's the last iteration.
				if [[ "$i" == $(( $l - 1 )) ]]; then
					nitem=
				fi

				# If a command.
				if [[ "$item" != -* ]]; then
					# Store command.
					commandchain+=".$item"
					# Reset used flags.
					foundflags=()
				else # We have a flag.
					# Store commandchain to revert to it if needed.
					oldchains+=("$commandchain")
					commandchain=""

					# If the flag contains a n eq sign don't look ahead.
					if [[ "$item" == *"="* ]]; then
						foundflags+=("$item")
						continue
					fi

					# Look ahead to check if next item exists. If a word
					# exists then we need to check whether is a value option
					# for the current flag or if it's another flag and do
					# the proper actions for both.
					if [[ ! -z "$nitem" ]]; then
						# If the next word is a value...
						if [[ "$nitem" != -* ]]; then
							# Check whether flag is a boolean:
							# Get the first non empty command chain.
							local oldchain=
							local skipflagval=false
							for ((j = "${#oldchains[@]}" - 1 ; j >= 0 ; j--)) ; do
								local chain="${oldchains[j]}"
								if [[ ! -z "$chain" ]]; then
									oldchain="$chain"

									# Lookup flag definitions from acmap.
									local rows=`grep "^$maincommand$oldchain[[:space:]]\-\-" <<< "$acmap"`
									local flags="${rows#* }"

									if [[ "$flags" =~ "${item}?"(\||$) ]]; then
										skipflagval=true
									fi

									break
								fi
							done

							# If the flag is not found then simply add the
							# next item as its value.
							if [[ "$skipflagval" == false ]]; then
								foundflags+=("$item=$nitem")

								# Increase index to skip added flag value.
								(( i++ ))
							else
								# It's a boolean flag. Add boolean marker (?).
								args[$i]="${args[i]}?"

								foundflags+=("$item")
							fi

						else # The next word is a another flag.
							foundflags+=("$item")
						fi

					else
						# Check whether flag is a boolean
						# Get the first non empty command chain.
						local oldchain=
						local skipflagval=false
						for ((j = "${#oldchains[@]}" - 1 ; j >= 0 ; j--)) ; do
							local chain="${oldchains[j]}"
							if [[ ! -z "$chain" ]]; then
								oldchain="$chain"

								# Lookup flag definitions from acmap.
								local rows=`grep "^$maincommand$oldchain[[:space:]]\-\-" <<< "$acmap"`
								local flags="${rows#* }"

								if [[ "$flags" =~ "${item}?"(\||$) ]]; then
									skipflagval=true
								fi

								break
							fi
						done

						# If the flag is found then add marker to item.
						if [[ "$skipflagval" != false ]]; then
							# It's a boolean flag. Add boolean marker (?).
							args[$i]="${args[i]}?"
						fi
						foundflags+=("$item")

					fi
				fi

			done

			# Get the first non empty command chain.
			local oldchain=
			for ((i = "${#oldchains[@]}" - 1 ; i >= 0 ; i--)) ; do
				local chain="${oldchains[i]}"
				if [[ ! -z "$chain" ]]; then
					oldchain="$chain"
					break
				fi
			done

			# Revert commandchain to old chain if empty.
			if [[ -z "$commandchain" ]]; then
				commandchain="$oldchain"
			else
				commandchain="$commandchain"
			fi
			# Prepend main command to chain.
			commandchain="$maincommand$commandchain"

			# Build used flags strings.
			# Switch statement: [https://stackoverflow.com/a/22575299]
			case "${#foundflags[@]}" in
			0)
				usedflags=""
				;;
			*)
				usedflags="`__join $' }|{ ' "${foundflags[@]}"`"
				;;
			esac

			# Determine whether to turn off autocompletion or not.
			# Get the last word item.
			local lword="${args[${#args[@]}-1]}"
			if [[ "$lastchar" == " " ]]; then
				if [[ "$lword" == -* ]]; then
					if [[ "$lword" == *"?"* || "$lword" == *"="* ]]; then
						autocompletion=true
					else
						autocompletion=false
					fi
				fi
			else
				if [[ "$lword" != -* ]]; then
					# Check if the second to last word is a flag.
					local sword="${args[${#args[@]}-2]}"
					if [[ "$sword" == -* ]]; then
						if [[ "$sword" == *"?"* || "$sword" == *"="* ]]; then
							autocompletion=true
						else
							autocompletion=false
						fi
					fi
				fi
			fi

			# Remove boolean indicator from flags.
			for ((i = 0; i < "${#args[@]}"; i++)); do
				# Check for valid flag pattern?
				if [[ "${args[i]}" == -* ]]; then
					# Remove boolean marker from flag.
					if [[ "${args[i]}" == *\? ]]; then
						args[$i]="${args[i]%?}"
					fi
				fi
			done

			# Set last word. If the last char is a space then the last word
			# will be empty. Else set it to the last word.
			# Switch statement: [https://stackoverflow.com/a/22575299]
			case "$lastchar" in
			' ')
				last=""
				;;
			*)
				last="${args[${#args[@]}-1]}"
				;;
			esac

			# Check whether last word is quoted or not.
			if [[ `__is_lquoted "$last"` == true ]]; then
				isquoted=true
			fi
		}

		# Lookup command/subcommand/flag definitions from the acmap to return
		#     possible completions list.
		function __lookup() {
			# Flag ReGex test patterns.
			# Regex → "--flag="
			local flgopt="--?[a-z0-9-]*="
			# Regex → "--flag=value"
			local flgoptvalue="^\-{1,2}[a-zA-Z0-9]([a-zA-Z0-9\-]{1,})?\=\*?.{1,}$"

			# Skip logic if last word is quoted or completion variable is off.
			if [[ "$isquoted" == true || "$autocompletion" == false ]]; then
				return
			fi

			# Flag completion (last word starts with a hyphen):
			if [[ "$last" == -* ]]; then
				# Lookup flag definitions from acmap.
				local rows=`grep "^$commandchain[[:space:]]\-\-" <<< "$acmap"`

				# Continue if rows exist.
				if [[ ! -z "$rows" ]]; then
					local used=()

					# Set completion type:
					type="flag"

					# # Split rows by lines: [https://stackoverflow.com/a/11746174]
					# while read -r row; do
					# # ^ Note: Since there is to be only a single row for
					# # a command which includes all it's flags, looping over
					# # the found 'rows' is not really needed. Leave/remove??

					# Extract flags (everything after space) from row.
					local flags="${rows#* }"

					# If no flags exist skip line.
					if [[ "$flags" == "--" ]]; then continue; fi

					# Loop over flags to process.
					while IFS= read -r flag; do
						# Remove boolean indicator from flag if present.
						if [[ "$flag" =~ \?$ ]]; then
							flag="${flag/\?/}"
						fi

						# Track multi-starred flags.
						if [[ "$flag" == *\=\* ]]; then
							__dc_multiflags+=" ${flag/\=\*/} "
						fi

						# Unescape flag.
						flag="`__unescape "$flag"`"

						# Flag must start with the last word.
						if [[ "$flag" == "$last"* ]]; then

							# Note: If the last word is "--" or if the last
							# word is not in the form "--form= + a character",
							# don't show flags with values (--flag=value).
							if [[ "$last" != *"="* && "$flag" =~ $flgoptvalue && "$flag" != *\* ]]; then
								continue
							fi

							# No dupes unless it's a multi-starred flag.
							if [[ `__dupecheck "$flag"` == false ]]; then
								# Remove "*" multi-flag marker from flag.
								flag="${flag/\=\*/=}"

								# If last word is in the form → "--flag=" then we
								# need to remove the last word from the flag to
								# only return its options/values.
								if [[ "$last" =~ $flgopt ]]; then
									# Copy flag to later reset flag key if no
									# option was provided for it.
									flagcopy="$flag"

									# Reset flag to its option. If option is empty
									# (no option) then default to flag's key.
									# flag+="value"
									flag="${flag#*=}"
									if [[ -z "$flag" ]]; then
										flag="$flagcopy"
									fi
								fi

								# Note: This is more of a hack check.
								# Values with special characters will
								# sometime by-pass the previous checks
								# so do one file check. If the flag
								# is in the following form:
								# ----flags="value-string" then we do
								# not add is to the completions list.
								# Final option/value check.
								local __isquoted=false
								if [[ "$flag" == *"="* ]]; then
									local ff="${flag#*=}"
									if [[ `__is_lquoted "${ff:0:1}"` == true ]]; then
										__isquoted=true
									fi
								fi

								# Add flag/options if all checks pass.
								if [[ "$__isquoted" == false && "$flag" != "$last" ]]; then
									if [[ ! -z "$flag" ]]; then
										completions+=("$flag")
									fi
								fi
							else
								# If flag exits and is already used then add a space after it.
								# if [[ "$last" != *"="* && "$flag" == "$last" ]]; then
								if [[ "$flag" == "$last" ]]; then
									if [[ "$last" != *"="* ]]; then
										used+="$last"
									else
										flag="${flag#*=}"
										if [[ ! -z "$flag" ]]; then
											completions+=("$flag")
										fi
									fi
								fi
							fi
						fi
					# Split by unescaped pipe '|' characters:
					# [https://stackoverflow.com/a/37270949]
					# [https://stackoverflow.com/a/2376059]
					# [https://unix.stackexchange.com/a/17111]
					done < <(sed 's/\([^\]\)|/\1\n/g' <<< "$flags")
					# done <<< "$rows"

					# Note: If the last word (the flag in this case) is an
					# options flag (i.e. --flag=val) we need to remove the
					# possible already used value. For example take the
					# following scenario. Say we are completing the following
					# flag '--flag=7' and our two options are '7' and '77'.
					# Since '7' is already used we remove that value to leave
					# '77' so that on the next tab it can be completed to
					# '--flag=77'.
					local l="${#completions[@]}"
					# Get the value from the last word.
					local val="${last#*=}"

					# Note: Account for quoted strings. If the last value is
					# quoted, then add closing quote.
					if [[ `__is_lquoted "$val"` == true ]]; then
						local ll="${#val}"
						# Get starting quote (i.e. " or ').
						quote="${val:0:1}"
						if [[ "${val:ll-1:1}" != "$quote" ]]; then
							val+="${val:0:1}"
						fi

						# Escape for double quoted strings.
						type="flag;quoted"
						if [[ "$quote" == "\"" ]]; then
							type+=";noescape"
						fi

						# If the value is empty return.
						if [[ "${#val}" -eq 2 ]]; then
							completions+=("${quote}${quote}")
							return
						fi
					fi

					# If the last word contains an eq sign, it has a value
					# option, and there are more than 2 possible completions
					# we remove the already used option.
					if [[ "$last" == *"="* && ! -z "$val" && "$l" -ge 2 ]]; then
						for ((i = l - 1 ; i >= 0 ; i--)) ; do
							if [[ "${#completions[i]}" == "${#val}" ]]; then
								# Remove item from array.
								unset "completions[i]"
								__rm_aitem completions $i
							fi
						done
					fi

					# Note: If there are no completions but there is a single
					# used flag, this means no completions exist and the
					# current flag exist. Therefore, add the current word (the
					# used flag) so that bash appends a space to it.
					if [[ "${#completions[@]}" == 0 && "${#used[@]}" == 1 ]]; then
						completions+=("${used[0]}")
					fi
				fi
			else # Command completion:

				# Set completion type:
				type="command"

				# If command chain and used flags exits, don't complete.
				if [[ ! -z "$usedflags" && ! -z "$commandchain" ]]; then
					# Reset commandchain and usedflags.
					commandchain="$maincommand.$last"
					usedflags=""
				fi

				# Lookup command tree rows from acmap.
				local rows=
				# Replacement type.
				local rtype=
				# Switch statement: [https://stackoverflow.com/a/22575299]
				case "$lastchar" in
				' ')
					rows=`grep "^$commandchain\." <<< "$acmap"`
					rtype=1
					;;
				*)
					rows=`grep "^$commandchain.[-:a-zA-Z0-9]* " <<< "$acmap"`
					rtype=2
					;;
				esac

				# If no upper level exists for the commandchain check that
				# the current chain is valid. If valid, add the last command
				# to the completions array to bash can append a space when
				# the user presses the [tab] key to show the completion is
				# complete for that word.
				if [[ -z "$rows" ]]; then
					local row=`grep "^$commandchain " <<< "$acmap"`
					if [[ ! -z "$row" && "$lastchar" != " " ]]; then
						# Add last command in chain.
						completions=(`__last_command "$row" "$rtype"`)
					fi
				else
					# If caret is in the last position, the command tree
					# exists, and the command tree does not contains any
					# upper levels then we simply add the last word so
					# that bash can add a space to it.
					if [[ ! -z `grep -m1 "^$commandchain " <<< "$acmap"`
						&& -z `grep -m1 "^$commandchain[-:a-zA-Z0-9]* " <<< "$rows"`
						&& "$lastchar" != " " ]]; then
						completions=("$last")
					else
						# Split rows by lines: [https://stackoverflow.com/a/11746174]
						while read -r row; do
							# Get last command in chain.
							row=`__last_command "$row" "$rtype"`

							# Add last command if it exists.
							if [[ ! -z "$row" ]]; then
								# If the character before the caret is not a
								# space then we assume we are completing a
								# command. (should we check that the character
								# is one of the allowed command chars,
								# i.e. [a-zA-Z-:]).
								if [[ "$lastchar" != " " ]]; then
									# Since we are completing a command we only
									# want words that start with the current
									# command we are trying to complete.
									if [[ "$row" == "$last"* ]]; then
										completions+=("$row")
									fi
								else
									# If we are not completing a command then
									# we return all possible word completions.
									completions+=("$row")
								fi
							fi
						done <<< "$rows"
					fi
				fi
			fi
		}

		# Send all possible completions to bash.
		function __printer() {
			if [[ "$type" == "command" ]]; then
				COMPREPLY=($(compgen -W  "`__join ' ' "${completions[@]}"`" -- ""))
				__ltrim_colon_completions "$last"
			elif [[ "$type" == *"flag"* ]]; then
				# Note: Disable bash's default behavior of adding a trailing space
				# to completions when hitting the [tab] key. This will be handle
				# manually. Unless completing a quoted flag value. Then it is
				# left on.
				# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
				# [https://github.com/llvm-mirror/clang/blob/master/utils/bash-autocomplete.sh#L59]
				if [[ "$type" != *"quoted"* ]]; then
					compopt -o nospace 2> /dev/null
				fi

				# Print and add right pad spacing to possibilities where necessary.
				for ((i = 0; i < "${#completions[@]}"; i++)); do
					local word="${completions[i]}"

					if [[ "$type" != *"noescape"* ]]; then
						# Escape word.
						word="`__escape "$word"`"
					fi

					# # Note: bash-completion handles colons in a weird manner.
					# # When a word completion contains a colon it will append
					# # the current completion word with the last word. For,
					# # example: say the last word is "js:" and the completion
					# # word is "js:bundle". Bash will output to console:
					# # "js:js:bundle". Therefore, we need to left trim the
					# # 'coloned' part of the completion word. In other words,
					# # we turn the completion word, for example, "js:bundle" to
					# # "bundle" so that bash could then properly complete the word.
					# # [https://github.com/scop/bash-completion/blob/master/bash_completion#L498]
					# if [[ "$word" == *":"* ]]; then
					# 	# Remove colon-word prefix from COMPREPLY items
					# 	# Example: 'js:build'
					# 	colon_prefix=${word%"${word##*:}"} # 'js:'
					# 	word="${word#"$colon_prefix"}" # 'build'

					# 	# # Remove colon-word prefix from COMPREPLY items
					# 	# local colon_word=${word%"${word##*:}"}
					# 	# word="${word#"$colon_word"}"
					# fi

					# Add trailing space to all completions except to flag
					# completions that end with a trailing eq sign, commands
					# that have trailing characters (commands that are being
					# completed in the middle), and flag string completions
					# (i.e. --flag="some-word...).
					if [[ "$word" != *"="
						&& `__is_lquoted "$word"` == false
						&& -z "$nextchar" ]]; then
						word+=" "
					fi

					# Log possibility for bash.
					COMPREPLY+=("$word")
				done
			fi
		}

		# Completion logic:
		# <cli_input> → parser → extracter → lookup → printer
		# Note: Supply CLI input from start to caret index.
		__parser "${cline:0:$cpoint}";__extracter;__lookup;__printer
	}

	# complete -d -X '.[^./]*' -F _nodecliac "$1"
	# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
	complete -o default -F _nodecliac "$1"
	# complete -F _nodecliac "$1"
fi
