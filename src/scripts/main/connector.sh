#!/bin/bash

# Command name provided from sourced passed-in argument.
if [[ -n "$1" ]] && type complete &>/dev/null; then
	# Bash general purpose CLI auto completion script.
	function _nodecliac() {
		# Get command name from sourced passed-in argument.
		local maincommand="$1"

		# Return if nodecliac is disabled but allow nodecliac completions.
		if [[ -e "$HOME/.nodecliac/.disable"
			&& "$maincommand" != "nodecliac" ]]; then
			return
		fi

		# Built-in auto completion vars.
		# local cur="${COMP_WORDS[COMP_CWORD]}" # Currently typed in word.
		# local prev="${COMP_WORDS[COMP_CWORD-1]}" # Word before current word.
		# local input="${COMP_WORDS[@]}" # All CLI input.
		# local line="$COMP_LINE" # CLI input line.
		# local caretpos="$COMP_POINT" # Index of caret position.
		# local index="$COMP_CWORD" # Index of current word.

		local last=""
		local type=""
		local cline="$COMP_LINE" # Original (unmodified) CLI input.
		local cpoint="$COMP_POINT" # Caret index when [tab] key was pressed.
		local output=""

		# Get acdef file contents.
		# local acdef="$(<~/.nodecliac/registry/$maincommand/$maincommand*)"
		local acdefpath=~/.nodecliac/registry/$maincommand/$maincommand.acdef
		# Check once more if the acdef file exists for the following case:
		# If in the incident that nodecliac gets deleted (i.e. like running
		# '$ nodecliac uninstall'), if the acdef file does not exist bash
		# will output an error. Therefore, return when file is not found.
		if [[ ! -e "$acdefpath" ]]; then return; fi;
		local acdef
		acdef="$(<"$acdefpath")"

		# Default to Nim ac script for completion logic.
		acpl_script=~/.nodecliac/src/bin/ac."$(e=$(uname);e=${e,,};echo ${e/darwin/macosx})"
		# If Nim script does not exist fallback to Perl script.
		if [[ ! -e "$acpl_script" ]]; then acpl_script=~/.nodecliac/src/ac/ac.pl; fi

		# Run completion script if it exists.
		if [[ -e "$acpl_script" ]]; then
			# Run pre-parse hook script if it exists.
			preparse_script=~/.nodecliac/registry/$1/hooks/pre-parse.sh
			if [[ -e "$preparse_script" ]]; then
				# [https://stackoverflow.com/questions/16217064/change-environment-variable-in-child-process-bash]
				# [https://stackoverflow.com/questions/192292/how-best-to-include-other-scripts]
				# [https://www.daveeddy.com/2010/09/20/import-source-files-in-bash/]
				# [https://tecadmin.net/include-bash-script-in-other-bash-script/]
				source "$preparse_script"
			fi

			output=$("$acpl_script" "$COMP_LINE" "$cline" "$cpoint" "$maincommand" "$acdef")
			# "$acpl_script" "$COMP_LINE" "$cline" "$cpoint" "$maincommand" "$acdef"

			# First line is meta info (completion type, last word, etc.).
			# [https://stackoverflow.com/a/2440685]
			read -r firstline <<< "$output"
			type="${firstline%%:*}"
			last="${firstline#*:}"

			# Inline printer logic:

			# Finally, add words to COMPREPLY.
			if [[ "$type" == "command" ]]; then
				# Set completions string.
				# [https://stackoverflow.com/a/18551488], [https://stackoverflow.com/a/35164798]
				COMPREPLY=($(echo -e "$(awk 'NR>1' <<< "$output")"))
				__ltrim_colon_completions "$last"

				# When COMPREPLY is empty, meaning no autocompletion values
				# are in COMPREPLY array, the command was registered with
				# the '-o' flag, and the config setting 'filedir' is set then
				# run bash completion's _filedir function.
				if [[ "${#COMPREPLY[@]}" -eq 0 ]]; then

					# '-o' option had to have been used when registered else
					# if not then we do not resort to using _filedir.
					registry=$(LC_ALL=C grep -F "_nodecliac $maincommand" <<< "$(complete -p)")
					if [[ "$registry" != *" -o "* ]]; then return; fi

					# Get 'filedir' config setting.
					# local filedirvalue=`"$HOME/.nodecliac/src/main/config.pl" "filedir" "$maincommand"`
					local filedirvalue
					filedirvalue=$("$HOME/.nodecliac/src/main/config.pl" "filedir" "$maincommand")

					# Run function with or without arguments.
					if [[ -n "$filedirvalue" && "$filedirvalue" != "false" ]]; then
						# Reset value if no pattern was provided.
						if [[ "$filedirvalue" == "true" ]]; then filedirvalue=""; fi

						# [https://github.com/gftg85/bash-completion/blob/bb0e3a1777e387e7fd77c3abcaa379744d0d87b3/bash_completion#L549]
						# [https://unix.stackexchange.com/a/463342]
						# [https://unix.stackexchange.com/a/463336]
						# [https://github.com/scop/bash-completion/blob/master/completions/java]
						# [https://stackoverflow.com/a/23999768]
						# [https://unix.stackexchange.com/a/190004]
						# [https://unix.stackexchange.com/a/198025]
						local cur="$last"
						_filedir "$filedirvalue"
					fi
				fi

			elif [[ "$type" == *"flag"* ]]; then
				# Note: Disable bash's default behavior of adding a trailing space
				# to completions when hitting the [tab] key. This will be handled
				# manually. Only leave on when completing a quoted flag value.
				# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
				# [https://github.com/llvm-mirror/clang/blob/master/utils/bash-autocomplete.sh#L59]
				if [[ "$type" != *"quoted"* ]]; then
					compopt -o nospace 2> /dev/null
				fi

				# Use mapfile/readarray command to populate COMPREPLY w/ flags.
				# [https://stackoverflow.com/a/30988704]
				# [https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#index-mapfile]
				# [http://mywiki.wooledge.org/BashFAQ/001]
				# [http://mywiki.wooledge.org/BashFAQ/005?highlight=%28readarray%29#Loading_lines_from_a_file_or_stream]
				mapfile -t COMPREPLY < <(awk 'NR>1' <<< "$output")
			fi
		fi
	}

	# Get 'compopt' and 'disable' config settings.
	settings=$("$HOME/.nodecliac/src/main/config.pl" "compopt;disable" "$1")
	config_compopt="${settings%%:*}"
	config_disable="${settings#*:}"

	# Don't register script to command if disable setting set to true.
	if [[ "$config_disable" == "true" ]]; then return; fi

	# Register autocompletion script with command.
	if [[ "$config_compopt" == "false" ]]; then
		# Disable bash defaults when no completions are provided.
		complete -F _nodecliac "$1"
	else
		# The default registration.
		complete -o "$config_compopt" -F _nodecliac "$1"
		# complete -o default -F _nodecliac "$1"

		# [https://www.linuxjournal.com/content/more-using-bash-complete-command]
		# complete -d -X '.[^./]*' -F _nodecliac "$1"
	fi
fi
