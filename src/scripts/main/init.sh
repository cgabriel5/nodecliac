#!/bin/bash

vmajor=${BASH_VERSINFO[0]}
vminor=${BASH_VERSINFO[1]}
if [[ "$vmajor" -ge 4 ]]; then
	[[ "$vmajor" -eq 4 && "$vminor" -le 2 ]] && return
	root=~/.nodecliac
	mkdir -p "$root/.cache"
	config="$root/.config"
	[[ ! -e "$config" || ! -s "$config" ]] && echo "1101" > "$config"

	# shopt -s nullglob # [https://stackoverflow.com/a/7702334]
	config_script="$root"/src/main/config.pl
	while read -r cpkgpath; do # [https://stackoverflow.com/a/28927847]
		# dir=${cpkgpath%/*}
		filename="${cpkgpath##*/}"
		command="${filename%%.*}"

		[[ -z "$command" || ! -e "$cpkgpath/$command.acdef" ]] && continue

		command="${command##*/}" # Skip if command has invalid chars.
		[[ "$filename" != "$command" ]] && continue

		read settings < <($config_script "compopt;disable" "$command")
		config_compopt="${settings%%:*}" # Defaults to 'default'.
		config_disable="${settings#*:}"

		# Don't register if command is disable.
		[[ "$config_disable" == "true" ]] && return

		# Register completion function with command.
		# [https://www.linuxjournal.com/content/more-using-bash-complete-command]
		# complete -d -X '.[^./]*' -F _nodecliac "$command" # Ignore hidden.
		params=(-X '.[^./]*' -F _nodecliac "$command")
		[[ "$config_compopt" != "false" ]] && params+=(-o "$config_compopt")
		complete "${params[@]}"
	# [https://superuser.com/a/352387]
	# [https://askubuntu.com/a/427290]
	# [https://askubuntu.com/a/1137769]
	# [https://superuser.com/a/1404146]
	# [https://superuser.com/a/999448]
	# [https://stackoverflow.com/a/9612232]
	# [https://askubuntu.com/a/318211]
	# Ignore parent dir: [https://stackoverflow.com/a/11071654]
	# [https://superuser.com/a/701822]
	# [https://unix.stackexchange.com/a/158044]
	# [https://unix.stackexchange.com/a/50613]
	# [https://stackoverflow.com/q/20260247]
	done < <(find "$root"/registry -maxdepth 1 -mindepth 1 \( -type d -o -type l \) -name "[!.]*")

	# Unset to allow bash-completion to continue to work properly.
	# shopt -u nullglob # [https://unix.stackexchange.com/a/434213]
fi

function _nodecliac() {
	local command="$1"
	local name="nodecliac"
	local root=~/.nodecliac

	local config="$root/.config"
	if ! command -v "$name" > /dev/null || [ ! -e "$config" ]; then return; fi
	local cstring
	read -n 4 cstring < "$config"
	local status="${cstring:0:1}"
	[[ "$status" == 0 && "$command" != "$name" ]] && return

	local sum=""
	local output=""
	local cline="$COMP_LINE"
	local cpoint="$COMP_POINT"
	local acdefpath="$root"/registry/"$command/$command.acdef"
	local prehook="$root"/registry/"$command"/hooks/pre-parse.sh
	local cache="${cstring:1:1}"
	local debug="${cstring:2:1}"
	local singletons="${cstring:3:1}"
	local cachefile=""
	local xcachefile=""
	local usecache=0
	local m c

	if [[ "$cache" != 0 ]]; then
		# [https://stackoverflow.com/a/28844659]
		read -n 7 sum < <(cksum <<< "$cline$PWD")
		cachefile="$root"/.cache/"$sum"
		xcachefile="$root"/.cache/"x$sum"

		if [[ -e "$xcachefile" ]]; then
			read m < <(date -r "$xcachefile" "+%s")
			# [https://stackoverflow.com/a/54054553]
			printf -v c '%(%s)T' # [https://stackoverflow.com/a/14802843]
			if [[ $((c-m)) -lt 3 ]]; then
				usecache=1
				output=$(<"$xcachefile")
			fi

		elif [[ -e "$cachefile" ]]; then
			usecache=1
			output=$(<"$cachefile")
		fi

		rm -f "$root"/.cache/x*
	fi

	if [[ "$usecache" == 0 ]]; then
		local acdef=$(<"$acdefpath")
		local os=$(uname); os=${os,,}
		local pac="$root"/src/ac/ac.pl
		local nac="$root"/src/bin/ac."${os/darwin/macosx}"
		local ac="$pac"
		[[ " linux darwin " == *" $os "* ]] && ac="$nac"
		case "$debug" in
			1) ac="${ac/ac./ac_debug.}" ;;
			2) ac="${pac/ac./ac_debug.}" ;;
			3) ac="${nac/ac./ac_debug.}" ;;
		esac

		[[ -e "$prehook" ]] && . "$prehook"

		# shopt -s nullglob # [https://stackoverflow.com/a/7702334]
		local posthook="" # [https://stackoverflow.com/a/23423835]
		posthooks=("$root/registry/$command/hooks/post-hook."*)
		phscript="${posthooks[0]}"
		[[ -n "$phscript" && -x "$phscript" ]] && posthook="$phscript"
		# Unset to allow bash-completion to continue to work properly.
		# shopt -u nullglob # [https://unix.stackexchange.com/a/434213]

		output=$("$ac" "$COMP_LINE" "$cline" "$cpoint" "$command" "$acdef" "$posthook" "$singletons")
		# "$ac" "$COMP_LINE" "$cline" "$cpoint" "$command" "$acdef" "$posthook" "$singletons"
	fi

	[[ "$debug" != "0" ]] && echo -e "$output" && return

	# 1st line is meta info (completion type, last word, etc.).
	# [https://stackoverflow.com/a/2440685]
	read -r firstline <<< "$output"
	local meta="${firstline%%+*}"
	local filedir="${firstline#*+}"
	local type="${meta%%:*}"
	local last="${meta#*:}"
	mapfile -ts1 COMPREPLY < <(echo -e "$output")
	local cacheopt=1; [[ "$type" == *"nocache"* ]] && cacheopt=0
	local gfdir

	if [[ "$cache" != 0 && "$usecache" == 0 ]]; then
		[[ "$cacheopt" == 0 && "$cache" == 1 ]] && sum="x$sum"
		echo "$output" > "$root"/.cache/"$sum"
	fi

	# If the word-to-complete contains a colon (:), left-trim COMPREPLY items with
	# word-to-complete.
	# With a colon in COMP_WORDBREAKS, words containing
	# colons are always completed as entire words if the word to complete contains
	# a colon.  This function fixes this, by removing the colon-containing-prefix
	# from COMPREPLY items.
	# The preferred solution is to remove the colon (:) from COMP_WORDBREAKS in
	# your .bashrc:
	#
	#    # Remove colon (:) from list of word completion separators
	#    COMP_WORDBREAKS=${COMP_WORDBREAKS//:}
	#
	# See also: Bash FAQ - E13) Why does filename completion misbehave if a colon
	# appears in the filename? - https://tiswww.case.edu/php/chet/bash/FAQ
	# @param $1 current word to complete (cur)
	# @modifies global array $COMPREPLY
	#
	# [https://github.com/scop/bash-completion/blob/master/bash_completion]
	nltrim_colon_completions() {
		if [[ "$last" == *:* && $COMP_WORDBREAKS == *:* ]]; then
			# Remove colon-word prefix from COMPREPLY items
			local colon_word=${last%"${last##*:}"}
			local i=${#COMPREPLY[*]}
			while ((i-- > 0)); do
				COMPREPLY[i]=${COMPREPLY[i]#"$colon_word"}
			done
		fi
	}

	# Modified version of bash-completion's _filedir helper function.
	#
	# This function performs file and directory completion. It's better than
	# simply using 'compgen -f', because it honours spaces in filenames.
	# @param $1  If `-d', complete only on directories.  Otherwise filter/pick only
	#            completions with `.$1' and the uppercase version of it as file
	#            extension.
	# [https://github.com/scop/bash-completion/blob/master/bash_completion]
	nfiledir() {
		local quoted
		local IFS=$'\n'
		local -a items
		local reset arg=${1-}

		reset=$(shopt -po noglob)
		set -o noglob
		if [[ $arg == -d ]]; then
			items=($(compgen -d -- "${last-}"));
		else
			_quote_readline_by_ref "${last-}" quoted
			items=($(compgen -f -X "${arg:+"!*.@($arg|${arg^^})"}" -- "$quoted"))
			# Try without filter if no completions were generated.
			[[ "${#items[@]}" == 0 ]] && items=($(compgen -f -o plusdirs -- "$quoted"))
		fi
		IFS=' '
		$reset
		IFS=$'\n'

		[[ "${#items[@]}" != 0 ]] && \
		compopt -o filenames 2>/dev/null && COMPREPLY=("${items[@]}")
	}

	# If no completions default to directory folder/file names.
	if [[ "${#COMPREPLY}" -eq 0 ]]; then
		# If value exists reset var to it. [https://stackoverflow.com/a/20460402]
		[[ -z "${last##*=*}" ]] && last="${last#*=}"

		# If filedir is empty check for the (global) setting filedir.
		if [[ -z "$filedir" ]]; then
			read gfdir < <("$root"/src/main/config.pl "filedir" "$command")
			[[ -n "$gfdir" && "$gfdir" != "false" ]] && filedir="$gfdir"
		fi

		# [https://unix.stackexchange.com/a/463342]
		# [https://unix.stackexchange.com/a/463336]
		# [https://github.com/scop/bash-completion/blob/master/completions/java]
		# [https://stackoverflow.com/a/23999768]
		# [https://unix.stackexchange.com/a/190004]
		# [https://unix.stackexchange.com/a/198025]
		nfiledir "$filedir"
	else
		if [[ "$type" == "command"* ]]; then
			# [https://stackoverflow.com/a/18551488]
			# [https://stackoverflow.com/a/35164798]
			# COMPREPLY=($(echo -e "$(awk 'NR>1' <<< "$items")"))
			# COMPREPLY=($(echo -e "$items"))
			nltrim_colon_completions
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
			# mapfile -t COMPREPLY < <(echo -e "$items")
		fi
	fi
}

# # If on Linux, create a ramdisk for caching:
# # [https://www.techrepublic.com/article/how-to-use-a-ramdisk-on-linux/]
# if [[ ! $(grep -F "/.nodecliac/.cache" <<< $(df -lht tmpfs)) ]]; then
# 	sudo mount -t tmpfs -o rw,size=20M tmpfs ~/.nodecliac/.cache
# 	# sudo umount ~/.nodecliac/.cache # Remove ramdisk.
# fi
