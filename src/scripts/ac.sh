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
			local IFS="$1"; shift; echo "$*"
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
		# 	echo "commandchain: '$commandchain'"
		# 	echo "   usedflags: '$usedflags'"
		# 	echo "        last: '$last'"
		# 	echo "       input: '$inp'"
		# 	echo "input length: '$cline_length'"
		# 	echo " caret index: '$cpoint'"
		# 	echo "    lastchar: '$lastchar'"
		# 	echo "    nextchar: '$nextchar'"
		# 	echo "    isquoted: '$isquoted'"
		# }

		# Get last command in chain: 'mc.sc1.sc2' → 'sc2'
		#
		# @param {string} 1) - The row to extract command from.
		# @return {string} - The last command in chain.
		function __last_command() {
			# Extract command chain from row.
			local row="${1%% *}"
			# Extract last command from chain and return.
			echo "${row##*.}"
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

			# Return empty array when input is empty.
			if [[ -z "$input" ]]; then
				return
			fi

			# Loop over every input char: [https://stackoverflow.com/a/10552175]
			for ((i = 0; i < "${#cline}"; i++ )); do
				# Cache current/previous chars.
				local c="${cline:$i:1}"
				local p="${cline:$i - 1:1}"
				# Reset prev word for 1st char as bash gets the last char.
				if [[ "$i" == 0 ]]; then
					p=""
				fi

				# Stop loop once it hits the caret position character.
				if [[ "$i" -ge $(( ${#input} - 1 )) ]]; then
					# Only add if not a space character.
					if [[ "$c" != " " ]]; then
						current+="$c"
					fi
					lastchar="$c"
					break
				fi

				# If char is a space.
				if [[ "$c" == " " ]]; then
					if [[ "${#quote_char}" != "0" ]]; then
						current+="$c"
					else
						if [[ "$current" != "" ]]; then
							args+=("$current")
							current=""
						fi
					fi
				# Non space chars.
				elif [ "$c" == '"' -o "$c" == "'" ] && [ "$p" != "\\" ]; then
					if [[ "$quote_char"  != "" ]]; then
						if [[ "$quote_char" == "$c" ]]; then
							current+="$c"
							args+=("$current")
							quote_char=""
							current=""
						elif [ "$quote_char" == '"' -o "$quote_char" == "'" ] && [ "$p" != "\\" ]; then
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
				args+=("$current")
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

				if [[ "$item" =~ ^(\"|\') ]]; then
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
							foundflags+=("$item=$nitem")

							# Increase index to skip added flag value.
							(( i++ ))
						else # The next word is a another flag.
							foundflags+=("$item")
						fi

					else
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
			commandchain="${maincommand}$([[ -z "$commandchain" ]] && echo "$oldchain" || echo "$commandchain")"
			# Build used flags strings.
			usedflags="$([[ "${#foundflags[@]}" -eq 0 ]] && echo "" || echo " `__join " " "${foundflags[@]}"` ")"

			# Set last word. If the last char is a space then the last word
			# will be empty. Else set it to the last word.
			last=`[[ "$lastchar" == " " ]] && echo "" || echo "${args[${#args[@]}-1]}"`

			# Check whether the last word is quoted or not.
			isquoted=`[[ "$last" =~ ^(\"|\') ]] && echo "true" || echo "false"`
		}

		# Lookup command/subcommand/flag definitions from the acmap to return
		#     possible completions list.
		function __lookup() {
			# Flag ReGex test patterns.
			# Regex → "--flag="
			local flgopt="--?[a-z0-9-]*="
			# Regex → "--flag=value"
			local flgoptvalue="^\-{1,2}[a-zA-Z0-9]([a-zA-Z0-9\-]{1,})?=[^*]{1,}$"

			# If the last word is quoted we don't do any completions.
			if [[ "$isquoted" == true ]]; then return; fi

			# If current word starts with a hyphen and the character before
			# the caret is not a space lookup flag completions.
			if [[ "$last" == -* ]]; then
				# Set type to flag.
				type="flag"

				# Lookup flag definitions from acmap.
				local rows=`grep "^$commandchain[[:space:]]\-\-" <<< "$acmap"`

				# Continue if rows exist.
				if [[ ! -z "$rows" ]]; then
					local used=()

					# Split rows by lines: [https://stackoverflow.com/a/11746174]
					while read -r row; do
						# Extract flags (everything after space) from row.
						local flags="${row#* }"

						# If no flags exist skip line.
						if [[ "$flags" == "--" ]]; then continue; fi

						# Get individual flags and turn to an array.
						IFS=$'|' read -ra flags <<< "$flags"

						# Loop over flags to process.
						for ((i = 0; i < "${#flags[@]}"; i++)); do
							# Cache current flag.
							local flag="${flags[i]}"

							# Flag must start with the last word.
							if [[ "$flag" == "$last"* ]]; then

								# Note: If the last word is "--" or if the last
								# word is not in the form "--form= + a character",
								# don't show flags with values (--flag=value).
								if [[ "$last" != *"="* && "$flag" =~ $flgoptvalue ]]; then
									continue
								fi

								# No dupes unless it's a multi-starred flag.
								if [[ ! "$usedflags" =~ "${flag/\=/}"(=| ) || "$flag" == *"*"* ]]; then
									# Remove "*" multi-flag marker from flag.
									flag="${flag//\*/}"

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

									# Add flag/options if all checks pass.
									if [[ "$flag" != "$last" ]]; then
										completions+=("$flag")
									fi
								else
									# If flag exits and is already used then add a space after it.
									if [[ "$last" != *"="* && "$flag" == "$last" ]]; then
										used+="$last"
									fi
								fi
							fi
						done
					done <<< "$rows"

					if [[ "${#completions[@]}" == 0 && "${#used[@]}" == 1 ]]; then
						completions+=("${used[0]}")
					fi
				fi
			else
				# Last word is a command.
				type="command"

				# If prev word is a flag skip auto completions as the word
				# is a value of the flag.
				local slast="${args[${#args[@]}-2]}"
				local flast="${args[${#args[@]}-1]}"
				if [[ -z "$last" && "$flast" == -* && "$flast" != *"="* ]] || [[ "$slast" == -* && "$slast" != *"="* && "$usedflags" == *" $slast=$last "* ]]; then
					return
				fi

				# If a command chain exits + there are used flags then we
				# dont complete.
				if [[ ! -z "$usedflags" && ! -z "$commandchain" ]]; then
					# Reset commandchain and usedflags.
					commandchain="$maincommand.$last"
					usedflags=""
				fi
				# myapp run example go --global-flag sime ne

				# Lookup command tree rows from acmap.
				local rows=`grep "^$commandchain.[-:a-zA-Z0-9]* " <<< "$acmap"`

				# If no upper level exists for the commandchain check that
				# the current chain is valid. If valid, add the last command
				# to the completions array to bash can append a space when
				# the user presses the [tab] key to show the completion is
				# complete for that word.
				if [[ -z "$rows" ]]; then
					local row=`grep "^$commandchain " <<< "$acmap"`
					if [[ ! -z "$row" && "$lastchar" != " " ]]; then
						# Add last command in chain.
						completions=(`__last_command "$row"`)
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
							row=`__last_command "$row"`

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
			# Note: Disable bash's default behavior of adding a trailing space
			# to completions when hitting the [tab] key. This will be handle
			# manually.
			# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
			# [https://github.com/llvm-mirror/clang/blob/master/utils/bash-autocomplete.sh#L59]
			compopt -o nospace 2> /dev/null

			# Print and add right pad spacing to possibilities where necessary.
			for ((i = 0; i < "${#completions[@]}"; i++)); do
				local word="${completions[i]}"

				# Note: bash-completion handles colons in a weird manner.
				# When a word completion contains a colon it will append
				# the current completion word with the last word. For,
				# example: say the last word is "js:" and the completion
				# word is "js:bundle". Bash will output to console:
				# "js:js:bundle". Therefore, we need to left trim the
				# 'coloned' part of the completion word. In other words,
				# we turn the completion word, for example, "js:bundle" to
				# "bundle" so that bash could then properly complete the word.
				# [https://github.com/scop/bash-completion/blob/master/bash_completion#L498]
				# local ll=`__join ' ' "${completions[@]}"`
				# COMPREPLY=($(compgen -W  "$ll" -- "$last"))
				# __ltrim_colon_completions "$last"
				if [[ "$word" == *":"* ]]; then
					# Remove colon-word prefix from COMPREPLY items
					# word="js:build"
					colon_prefix=${word%"${word##*:}"} # js:
					word="${word#"$colon_prefix"}" # build

					# # Add colon if the last word does not contain it to give
					# # user colon completion context.
					# if [[ "${last:${#last} - 1:1}" != ":" ]]; then
					# 	word=":$word"
					# fi
				fi

				# Add trailing space to all completions except to flag
				# completions that end with a trailing eq sign and commands
				# that have trailing characters (commands that are being
				# completed in the middle).
				if [[ "$word" != *"=" && -z "$nextchar" ]]; then
					word+=" "
				fi

				# Log possibility for bash.
				# COMPREPLY=($(compgen -W "$completions" -- "$last"))
				COMPREPLY+=("$word")
			done
		}

		# Completion logic:
		# <cli_input> → parser → extracter → lookup → printer
		# Note: Supply CLI input from start to caret index.
		__parser "${cline:0:$cpoint}";__extracter;__lookup;__printer
	}

	# complete -d -X '.[^./]*' -F _nodecliac "$1"
	# complete -o default -F _nodecliac "$1"
	complete -F _nodecliac "$1"
fi
