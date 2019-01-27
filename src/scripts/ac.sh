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
		local lastchar=
		local usedflags=""
		local completions=()
		local commandchain=""
		local cline="$COMP_LINE" # Full CLI input.
		local cpoint="$COMP_POINT" # Caret index when [tab] key was pressed.
		# Get the acmap definitions file.
		local acmap="$(<~/.nodecliac/maps/$maincommand)"
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
		# function __join() {
		# 	local IFS="$1"; shift; echo "$*"
		# }

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
			# _get_comp_words_by_ref -n = -n @ -n : -w words -i cword
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
				if [[ "$i" -ge "${#input}" ]]; then
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
				# # End parsing at "--"??
				# elif [[ "$c" == "-" ]]; then
				# 	if [[ "$quote_char"  == "" ]]; then
				# 		# Prev char must be a space. With the next two chars
				# 		# need to be a a hyphen and a space or just a hyphen
				# 		# ending the string.
				# 		# if [[ "$p" == " " && "${cline:$i + 1:1}" == "-" &&  ]]; then
				# 		if [[ "${cline:$i - 1:4}" =~ " "?"--"" " ]]; then
				# 			# # Reset vars.
				# 			# cline="$COMP_LINE"
				# 			# cpoint="$COMP_POINT"
				# 			# cline="$cline"

				# 			# echo "Reset mane"

				# 			lastchar="$c"
				# 			break
				# 		else
				# 			current+="$c"
				# 		fi
				# 	else
				# 		current+="$c"
				# 	fi
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
		function __extracter() {
			local l="${#args[@]}"
			local stopflags=false

			for ((i = "${#args[@]}" - 1 ; i >= 0 ; i--)) ; do
				# Cache current loop item.
				local item="${args[i]}"
				local pitem="${args[i - 1]}"

				# Once we hit the last item (the main command) stop loop.
				if [[ "$i" == 0 ]]; then
					# Prepend main command to chain.
					if [[ -z "$commandchain" ]]; then
						commandchain="$maincommand"
					else
						commandchain="$maincommand.$commandchain"
					fi

					# Stop loop.
					break
				fi

				# Current word is a flag.
				if [[ "$item" == -* ]]; then

					# Store the flag.
					if [[ "$stopflags" == false ]]; then
						usedflags+=" $item "
					fi

				else
				# Current word is not a flag.

					# If the previous word is a flag
					if [[ "$pitem" == -* ]]; then
						# Check if flag contains "="
						if [[ "$pitem" == *"="* ]]; then
							# If the previous word contains an "=" then the current
							# word is not a value to the previous flag word.

							# Word must be a command/subcommand.
							if [[ -z "$commandchain" ]]; then
								commandchain="$item"
							else
								commandchain="$item.$commandchain"
							fi

							# Stop loop.
							# break
							stopflags=true
						else
							# cur + prev = --flag=value

							# Store the flag.
							# if [[ -z "$stopflags" ]]; then
							if [[ "$stopflags" == false ]]; then
								usedflags+=" $pitem=$item "
							fi

							# If previous word does not contain a "=" then the current
							# word is the value to the previous word (flag).
							# Reset the index to skip the next word.
							(( i-- ))
						fi
					else
						# If the previous word is not a hyphen then the current word
						# is a command and the cur/prev words have no flag relation.

						# Word must be a command/subcommand.
						if [[ -z "$commandchain" ]]; then
							# Set flag to stop collecting used flags. As the used
							# flags should only pertain to highest level command.
							stopflags=true

							commandchain="$item"
						else
							commandchain="$item.$commandchain"
						fi
					fi
				fi
			done

			# Set last word.
			last="${args[${#args[@]}-1]}"
		}

		# Lookup command/subcommand/flag definitions from the acmap to return
		#     possible completions list.
		function __lookup() {
			# Flag ReGex test patterns.
			# Regex → "--flag="
			local flgopt="--?[a-z0-9-]*="
			# Regex → "--flag=value"
			local flgoptvalue="^\-{1,2}[a-zA-Z0-9]([a-zA-Z0-9\-]{1,})?=[^*]{1,}$"

			# If current word starts with a hyphen lookup flag completions.
			if [[ "$last" == -* ]]; then
				# Set type to flag.
				type="flag"

				# Lookup flag definitions from acmap.
				local rows=`grep "^$commandchain[[:space:]]\-\-" <<< "$acmap"`

				# If no rows, reset values.
				if [[ -z "$rows" ]]; then
					completions=()
					rows=()
				else
					# Split rows by lines: [https://stackoverflow.com/a/11746174]
					local list=()
					while read -r row; do list+=("$row"); done <<< "$rows"

					# Loop over rows to get the flags.
					for ((i = 0; i < "${#list[@]}"; i++)); do
						# Cache current line match.
						local line="${list[i]}"

						# Get flags from pattern. Get substring after space.
						local flags="${line#* }"

						# If no flags exist skip line.
						if [[ "$flags" == "--" ]]; then
							continue
						fi

						# Get individual flags.
						IFS=$'|' read -ra flags <<< "$flags"

						# Loop over and process flags. Remove used flags and keep
						# stared-multi "--flag=*".
						for ((j = 0; j < "${#flags[@]}"; j++)); do
							# Cache current flag.
							local flag="${flags[j]}"

							# Flag must start with the last word.
							if [[ "$flag" == "$last"* ]]; then

								# Note: If the last word is "--" or if the last word
								# is not in the form "--form= + a character", don't
								# showing flags with values like "--flag=value".
								if [[ "$last" != *"="* && "$flag" =~ $flgoptvalue ]]; then
									continue
								fi

								# Flag cannot be used already. Or it must be a multi-
								# starred flag.
								if [[ ! "$usedflags" =~ "$flag"(=| ) || "$flag" == *"*"* ]]; then

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
								fi
							fi
						done
					done
				fi
			else
				# Last word is a command.
				type="command"

				# Get the character before the caret.
				local char_b4_caret="${cline:$cpoint-1:1}"

				# Make sure the command tree exists.
				local row=`grep "^$commandchain " <<< "$acmap"`

				# Get the second to last argument.
				local slast="${args[${#args[@]}-2]}"

				# If the second to last word is a flag and it does not end
				# with an eq sign...we skip completions as the current word
				# is a value of the flag. So no completions necessary.
				if [[ "$slast" == -* && "$slast" != *= ]]; then
					completions=()
					return
				fi

				# When user decides to type in a command, this will ensure
				# that hitting tab after said command will add a space.
				if [[ "$char_b4_caret" != " " && ! -z "$row" ]]; then
					# Get last command in command tree.
					# i.e "maincommand.subcomm1.subcomm2" → "subcomm2"
					row="${row%% *}"
					# Get next level in command chain.
					row="${row##*.}"
					completions=("$row")
				else
					# Lookup command tree rows from acmap.
					local rows=`grep "^$commandchain.[a-z\-]* " <<< "$acmap"`

					# If no rows, reset values.
					if [[ -z "$rows" ]]; then
						completions=()
						rows=()
					else
						# Split rows by lines: [https://stackoverflow.com/a/11746174]
						local list=()
						while read -r row; do list+=("$row"); done <<< "$rows"

						# Loop over rows to get the last commands.
						for ((i = 0; i < "${#list[@]}"; i++)); do
							# Cache current line.
							local row="${list[i]}"

							# Get last command in command tree.
							# i.e "maincommand.subcomm1.subcomm2" → "subcomm2"
							row="${row%% *}"
							# Get next level in command chain.
							row="${row##*.}"
							completions+=("$row")
						done
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

				# Add trailing space to all completions except to flag
				# completions that end with a trailing eq sign and commands
				# that have trailing characters (commands that are being
				# completed in the middle).
				if [[ "$word" != *"=" && -z "$lastchar" ]]; then
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
	complete -o default -F _nodecliac "$1"
fi
