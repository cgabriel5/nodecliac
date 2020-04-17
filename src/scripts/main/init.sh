#!/bin/bash

vmajor=${BASH_VERSINFO[0]}
vminor=${BASH_VERSINFO[1]}
if [[ "$vmajor" -ge 4 ]]; then
	if [[ "$vmajor" -eq 4 && "$vminor" -le 2 ]]; then return; fi
	mkdir -p ~/.nodecliac/.cache
	cachefile=~/.nodecliac/.cache-level
	if [[ ! -e "$cachefile" ]]; then echo "1" > "$cachefile"; fi
	# [https://superuser.com/a/352387]
	# [https://askubuntu.com/a/427290]
	# [https://askubuntu.com/a/1137769]
	# [https://superuser.com/a/1404146]
	# [https://superuser.com/a/999448]
	# [https://stackoverflow.com/a/9612232]
	# [https://askubuntu.com/a/318211]
	# Ignore parent dir: [https://stackoverflow.com/a/11071654]
	registrypath=~/.nodecliac/registry
	dirlist="$(find "$registrypath" -maxdepth 1 -mindepth 1 -type d -name "[!.]*")"
	# Registry can't be empty.
	if [[ "$registrypath" == "$dirlist" ]]; then return; fi

	for filepath in $dirlist; do
		# dir=${filepath%/*}
		filename="${filepath##*/}"
		command="${filename%%.*}"

		if [[ -z "$command" || ! -e "$filepath/$command.acdef" ]]; then
			continue
		fi

		command="${command##*/}"
		# Skip if command has invalid chars.
		if [[ "$filename" != "$command" ]]; then continue; fi

		settings=$(~/.nodecliac/src/main/config.pl "compopt;disable" "$command")
		config_compopt="${settings%%:*}" # Defaults to 'default'.
		config_disable="${settings#*:}"

		# Don't register if command is disable.
		if [[ "$config_disable" == "true" ]]; then return; fi

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
			m=$(date -r "$xcachefile" "+%s")
			c=$(date +"%s")
			if [[ $(($c-$m)) -lt 3 ]]; then
				usecache=1
				output=$(<$xcachefile)
			fi

		elif [[ -e "$cachefile" ]]; then
			usecache=1
			output=$(<$cachefile)
		fi

		rm -rf ~/.nodecliac/.cache/x*
	fi

	if [[ "$usecache" == 0 ]]; then
		local acdef=$(<"$acdefpath")
		local os=$(uname); os=${os,,}
		local ac=~/.nodecliac/src/ac/ac.pl
		if [[ " linux darwin " == *" $os "* ]]; then
			ac=~/.nodecliac/src/bin/ac."${os/darwin/macosx}"
		fi

		if [[ -e "$prehook" ]]; then . "$prehook"; fi

		output=$("$ac" "$COMP_LINE" "$cline" "$cpoint" "$command" "$acdef")
		# "$ac" "$COMP_LINE" "$cline" "$cpoint" "$command" "$acdef"
	fi

	# 1st line is meta info (completion type, last word, etc.).
	# [https://stackoverflow.com/a/2440685]
	read -r firstline <<< "$output"
	local type="${firstline%%:*}"
	local last="${firstline#*:}"
	local nlpos=$((${#firstline} + 1))
	local items="${output:$nlpos:${#output}-2}"
	local cacheopt=1; if [[ "$type" == *"nocache"* ]]; then cacheopt=0; fi
	if [[ -z "$items" ]]; then return; fi

	if [[ "$clevel" != 0 && "$usecache" == 0 ]]; then
		if [[ "$cacheopt" == 0 && "$clevel" == 1 ]]; then sum="x$sum"; fi
		echo "$output" > ~/.nodecliac/.cache/"$sum"
	fi

	if [[ "$type" == "command"* ]]; then
		# [https://stackoverflow.com/a/18551488]
		# [https://stackoverflow.com/a/35164798]
		# COMPREPLY=($(echo -e "$(awk 'NR>1' <<< "$items")"))
		COMPREPLY=($(echo -e "$items"))
		__ltrim_colon_completions "$last"

		# When COMPREPLY is empty (no completions), the command was
		# registered with the '-o' flag, and config setting 'filedir'
		# is set, run bash completion's _filedir function.
		if [[ "${#COMPREPLY[@]}" -eq 0 ]]; then
			registry=$(LC_ALL=C grep -F "_nodecliac $command" <<< "$(complete -p)")
			if [[ "$registry" != *" -o "* ]]; then return; fi

			local fdirval=$(~/.nodecliac/src/main/config.pl "filedir" "$command")
			if [[ -n "$fdirval" && "$fdirval" != "false" ]]; then
				if [[ "$fdirval" == "true" ]]; then fdirval=""; fi

				# [https://github.com/gftg85/bash-completion/blob/bb0e3a1777e387e7fd77c3abcaa379744d0d87b3/bash_completion#L549]
				# [https://unix.stackexchange.com/a/463342]
				# [https://unix.stackexchange.com/a/463336]
				# [https://github.com/scop/bash-completion/blob/master/completions/java]
				# [https://stackoverflow.com/a/23999768]
				# [https://unix.stackexchange.com/a/190004]
				# [https://unix.stackexchange.com/a/198025]
				local cur="$last"
				_filedir "$fdirval"
			fi
		fi

	elif [[ "$type" == "flag"* ]]; then
		# Disable bash's default behavior of adding a trailing space to
		# completions when hitting the [tab] key. This will be handled
		# manually. Only leave on when completing a quoted flag value.
		# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
		# [https://github.com/llvm-mirror/clang/blob/master/utils/bash-autocomplete.sh#L59]
		if [[ "$type" != *"quoted"* ]]; then compopt -o nospace 2> /dev/null; fi

		# Use mapfile/readarray to populate COMPREPLY.
		# [https://stackoverflow.com/a/30988704]
		# [https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#index-mapfile]
		# [http://mywiki.wooledge.org/BashFAQ/001]
		# [http://mywiki.wooledge.org/BashFAQ/005?highlight=%28readarray%29#Loading_lines_from_a_file_or_stream]
		# mapfile -t COMPREPLY < <(awk 'NR>1' <<< "$items")
		mapfile -t COMPREPLY < <(echo -e "$items")
	fi
}
