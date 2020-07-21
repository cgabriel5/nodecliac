#!/bin/bash

vmajor=${BASH_VERSINFO[0]}
vminor=${BASH_VERSINFO[1]}
if [[ "$vmajor" -ge 4 ]]; then
	[[ "$vmajor" -eq 4 && "$vminor" -le 2 ]] && return
	mkdir -p ~/.nodecliac/.cache
	cachefile=~/.nodecliac/.cache-level
	debugfile=~/.nodecliac/.debugmode
	[[ ! -e "$cachefile" ]] && echo 1 > "$cachefile"
	[[ ! -e "$debugfile" ]] && echo 0 > "$debugfile"
	# [https://superuser.com/a/352387]
	# [https://askubuntu.com/a/427290]
	# [https://askubuntu.com/a/1137769]
	# [https://superuser.com/a/1404146]
	# [https://superuser.com/a/999448]
	# [https://stackoverflow.com/a/9612232]
	# [https://askubuntu.com/a/318211]
	# Ignore parent dir: [https://stackoverflow.com/a/11071654]
	registrypath=~/.nodecliac/registry
	# [https://superuser.com/a/701822]
	# [https://unix.stackexchange.com/a/158044]
	# [https://unix.stackexchange.com/a/50613]
	# [https://stackoverflow.com/q/20260247]
	dirlist="$(find "$registrypath" -maxdepth 1 -mindepth 1 \( -type d -o -type l \) -name "[!.]*")"
	# Registry can't be empty.
	[[ "$registrypath" == "$dirlist" ]] && return

	for filepath in $dirlist; do
		# dir=${filepath%/*}
		filename="${filepath##*/}"
		command="${filename%%.*}"

		[[ -z "$command" || ! -e "$filepath/$command.acdef" ]] && continue

		command="${command##*/}"
		# Skip if command has invalid chars.
		[[ "$filename" != "$command" ]] && continue

		settings=$(~/.nodecliac/src/main/config.pl "compopt;disable" "$command")
		config_compopt="${settings%%:*}" # Defaults to 'default'.
		config_disable="${settings#*:}"

		# Don't register if command is disable.
		[[ "$config_disable" == "true" ]] && return

		# Register completion function with command.
		if [[ "$config_compopt" == "false" ]]; then
			complete -F _nodecliac "$command" # No bash defaults.
		else
			complete -o "$config_compopt" -F _nodecliac "$command"

			# [https://www.linuxjournal.com/content/more-using-bash-complete-command]
			# complete -d -X '.[^./]*' -F _nodecliac "$command"
		fi
	done
fi

function _nodecliac() {
	local command="$1"

	[[ ! "$(command -v nodecliac)" || ! -e ~/.nodecliac ]] && return
	# If disabled, only allow nodecliac completion.
	[[ -e ~/.nodecliac/.disable && "$command" != "nodecliac" ]] && return

	local sum=""
	local output=""
	local cline="$COMP_LINE"
	local cpoint="$COMP_POINT"
	local acdefpath=~/.nodecliac/registry/"$command/$command.acdef"
	local prehook=~/.nodecliac/registry/"$command"/hooks/pre-parse.sh
	read -r -n 1 clevel < ~/.nodecliac/.cache-level
	read -r -n 1 DEBUGMODE < ~/.nodecliac/.debugmode
	local cachefile=""
	local xcachefile=""
	local usecache=0

	if [[ "$clevel" != 0 ]]; then
		# [https://stackoverflow.com/a/28844659]
		sum="$(cksum <<< "$cline$PWD")"
		sum="${sum:0:7}"
		cachefile=~/.nodecliac/.cache/"$sum"
		xcachefile=~/.nodecliac/.cache/"x$sum"

		if [[ -e "$xcachefile" ]]; then
			local m=$(date -r "$xcachefile" "+%s")
			local c=$(date +"%s")
			if [[ $((c-m)) -lt 3 ]]; then
				usecache=1
				output=$(<"$xcachefile")
			fi

		elif [[ -e "$cachefile" ]]; then
			usecache=1
			output=$(<"$cachefile")
		fi

		rm -rf ~/.nodecliac/.cache/x*
	fi

	if [[ "$usecache" == 0 ]]; then
		local acdef=$(<"$acdefpath")
		local os=$(uname); os=${os,,}
		local pac=~/.nodecliac/src/ac/ac.pl
		local nac=~/.nodecliac/src/bin/ac."${os/darwin/macosx}"
		local ac="$pac"
		[[ " linux darwin " == *" $os "* ]] && ac="$nac"
		case "$DEBUGMODE" in
			1) ac="${ac/ac./ac_debug.}" ;;
			2) ac="${pac/ac./ac_debug.}" ;;
			3) ac="${nac/ac./ac_debug.}" ;;
		esac

		[[ -e "$prehook" ]] && . "$prehook"

		output=$("$ac" "$COMP_LINE" "$cline" "$cpoint" "$command" "$acdef")
		# "$ac" "$COMP_LINE" "$cline" "$cpoint" "$command" "$acdef"
	fi

	[[ "$DEBUGMODE" != "0" ]] && echo -e "$output" && return

	# 1st line is meta info (completion type, last word, etc.).
	# [https://stackoverflow.com/a/2440685]
	read -r firstline <<< "$output"
	local meta="${firstline%%+*}"
	local filedir="${firstline#*+}"
	local type="${meta%%:*}"
	local last="${meta#*:}"
	local nlpos=$((${#firstline} + 1))
	local items="${output:$nlpos:${#output}-2}"
	local cacheopt=1; [[ "$type" == *"nocache"* ]] && cacheopt=0

	if [[ "$clevel" != 0 && "$usecache" == 0 ]]; then
		[[ "$cacheopt" == 0 && "$clevel" == 1 ]] && sum="x$sum"
		echo "$output" > ~/.nodecliac/.cache/"$sum"
	fi

	# If no completions default to directory folder/file names.
	if [[ -z "$items" ]]; then
		# If value exists reset var to it. [https://stackoverflow.com/a/20460402]
		[[ -z "${last##*=*}" ]] && last="${last#*=}"

		# If filedir is empty check for the (global) setting filedir.
		if [[ -z "$filedir" ]]; then
			local gfdir=$(~/.nodecliac/src/main/config.pl "filedir" "$command")
			[[ -n "$gfdir" && "$gfdir" != "false" ]] && filedir="$gfdir"
		fi

		# [https://unix.stackexchange.com/a/463342]
		# [https://unix.stackexchange.com/a/463336]
		# [https://github.com/scop/bash-completion/blob/master/completions/java]
		# [https://stackoverflow.com/a/23999768]
		# [https://unix.stackexchange.com/a/190004]
		# [https://unix.stackexchange.com/a/198025]
		local cur="$last"
		_filedir "$filedir"
	else
		if [[ "$type" == "command"* ]]; then
			# [https://stackoverflow.com/a/18551488]
			# [https://stackoverflow.com/a/35164798]
			# COMPREPLY=($(echo -e "$(awk 'NR>1' <<< "$items")"))
			COMPREPLY=($(echo -e "$items"))
			__ltrim_colon_completions "$last"

			# # __ltrim_colon_completions:
			# # [https://github.com/scop/bash-completion/blob/master/bash_completion]
			# if [[ "$last" == *:* && $COMP_WORDBREAKS == *:* ]]; then
			# 	# Remove colon-word prefix from COMPREPLY items
			# 	local colon_word=${last%"${last##*:}"}
			# 	local i=${#COMPREPLY[*]}
			# 	while ((i-- > 0)); do
			# 		COMPREPLY[i]=${COMPREPLY[i]#"$colon_word"}
			# 	done
			# fi

		elif [[ "$type" == "flag"* ]]; then
			# Disable bash's default behavior of adding a trailing space to
			# completions when hitting the [tab] key. This will be handled
			# manually. Only leave on when completing a quoted flag value.
			# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
			# [https://github.com/llvm-mirror/clang/blob/master/utils/bash-autocomplete.sh#L59]
			[[ "$type" != *"quoted"* ]] && compopt -o nospace 2> /dev/null

			# Use mapfile/readarray to populate COMPREPLY.
			# [https://stackoverflow.com/a/30988704]
			# [https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#index-mapfile]
			# [http://mywiki.wooledge.org/BashFAQ/001]
			# [http://mywiki.wooledge.org/BashFAQ/005?highlight=%28readarray%29#Loading_lines_from_a_file_or_stream]
			# mapfile -t COMPREPLY < <(awk 'NR>1' <<< "$items")
			mapfile -t COMPREPLY < <(echo -e "$items")
		fi
	fi
}
