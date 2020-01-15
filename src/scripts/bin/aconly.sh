#!/bin/bash

if [[ "$#" -eq 0 ]]; then exit; fi # Exit if no arguments provided.

# CLI arg flags.
rcfilepath=""
prcommand=""
enablencliac=""
disablencliac=""
rcfilepath=""
command=""

# [https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f]
# [http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_09_07.html]
params=""
paramsargs=()
while (( "$#" )); do
 case "$1" in
  	# Custom `print` command flags.
	--command=*)
		flag="${1%%=*}"; value="${1#*=}"
		if [[ -n "$value" ]]; then prcommand="$value"; fi; shift ;;
	--command)
		if [[ -n "$2" && "$2" != *"-" ]]; then prcommand="$2"; fi; shift ;;

  	# Custom `status` command flags.
	--enable) enablencliac="1"; shift ;;
	--disable) disablencliac="1"; shift ;;

  	# Custom `uninstall` command flags.
	--rcfilepath=*)
		flag="${1%%=*}"; value="${1#*=}"
		if [[ -n "$value" ]]; then rcfilepath="$value"; fi; shift ;;
	--rcfilepath)
		if [[ -n "$2" && "$2" != *"-" ]]; then rcfilepath="$2"; fi; shift ;;

	--) shift; break ;; # End argument parsing.
	-*|--*=)
		# echo "Error: Unsupported flag $1" >&2; exit 1
		shift ;; # Unsupported flags.
	*)

		# Get main nodecliac command and the
		# provided positional arguments.

		if [[ "$command" == "" ]]; then command="$1"
		else
			if [[ "$params" == "" ]]; then params="$1";
			else params+=" $1"; fi
			paramsargs+=("$1") # Also store in array for later looping.
		fi

		shift; ;; # Preserve positional arguments.

  esac
done
eval set -- "$params" # Set positional arguments in their proper place

command="$1" # Get action command.
shift # Remove command from arguments array.
commands=" print registry setup status uninstall " # Allowed commands.

if [[ "$commands" != *"$command"* ]]; then exit; fi # Exit if invalid command.

case "$command" in
	format) ;; # No-operation.

	make) ;; # No-operation.

	print)

		# If no command name is provided exit and error.
		if [[ -z "$prcommand" ]]; then exit; fi

		filepaths=""
		# Build acdef file paths string.
		for f in ~/.nodecliac/registry/*/*.acdef; do filepaths="$filepaths$f\n"; done
		list=" $(echo -e "$filepaths" | LC_ALL=C perl -ne "print \"\$1 \" while /(?! \/)([^\/]*)\.acdef$/g")"
		# readarray -t list <<< "$(echo -e "$filepaths" | LC_ALL=C perl -ne "print \"\$1\n\" while /(?! \/)([^\/]*)\.acdef$/g")"

		# If files exists print their contents.
		if [[ "$list" == *" $prcommand "* ]]; then
			acdefpath=~/.nodecliac/registry/"$prcommand/$prcommand.acdef"
			acdefconfigpath=~/.nodecliac/registry/"$prcommand/.$prcommand.config.acdef"
			if [[ -e "$acdefpath" ]]; then
				echo -e "\033[1m[$prcommand.acdef]\033[0m\n$(cat "$acdefpath")"
			fi
			if [[ -e "$acdefconfigpath" ]]; then
				echo -e "\033[1m[$prcommand.config.acdef]\033[0m\n$(cat "$acdefconfigpath")"
			fi
		fi

		;;

	registry)

		count=0; filepaths=""; output=""
		# Build acdef file paths string. [https://unix.stackexchange.com/a/96904]
		# for f in ~/.nodecliac/registry/*/*.acdef ~/.nodecliac/registry/*/.*.acdef; do
		for f in ~/.nodecliac/registry/*/*.acdef; do
			filepaths="$filepaths$f\n"
			filename=$(basename "$f")
			maincommand="${filename%%.*}"
			# dirname=$(dirname "$f")

			if [[ -e ~/.nodecliac/registry/"$maincommand/.$maincommand.config.acdef" ]]; then
				output+=" ─ \033[1;34m$maincommand\033[0m*\n"
			else output+=" ─ $maincommand\n"; fi

			((count=count+1)) # Increment counter.
		done

		header=" \033[1m.acdef files: ($count)\033[0m\n"
		# Remove trailing newline: [https://unix.stackexchange.com/a/140738]
		echo -e "$(echo -e "$header$output" | perl -0 -pe 's/\n\Z//')"

		;;

	setup) ;; # No-operation.

	status)

		dotfile=~/.nodecliac/.disable # Path to disabled dot file.

		if [[ "$enablencliac" || "$disablencliac" ]]; then
			# If --enable flag is used remove dot file.
			if [[ -n "$enablencliac" ]]; then
				if [[ -e "$dotfile" ]]; then rm "$dotfile"; fi
				echo -e "\033[0;32mEnabled.\033[0m"
			fi
			# If --disable flag ensure dot file exist.
			if [[ -n "$disablencliac" ]]; then
				touch "$dotfile"
				echo -e "\033[0;31mDisabled.\033[0m"
			fi
		else
			if [[ ! -e "$dotfile" ]]; then
				echo -e "nodecliac: \033[0;32menabled\033[0m"
			else
				echo -e "nodecliac: \033[0;31mdisabled\033[0m"
			fi
		fi

		;;

	uninstall)

		# Prompt password early on. Also ensures user really wants to uninstall.
		sudo echo > /dev/null 2>&1

		# Only continue with uninstall if nodecliac was installed for 'aconly'.
		if [[ -z "$(grep -o "aconly" "$HOME/.nodecliac/.setup.db.json")" ]]; then exit; fi

		# Confirm bashrcfile exists else default to ~/.bashrc.
		if [[ -z "$rcfilepath" ]] ||
			[[ ! -e "$rcfilepath" && ! -f "$rcfilepath" ]]; then rcfilepath=~/.bashrc; fi

		# Remove nodecliac from ~/.bashrc.
		if [[ -n "$(grep -o "ncliac=~/.nodecliac/src/main/init.sh" "$rcfilepath")" ]]; then
			# [https://stackoverflow.com/a/57813295]
			perl -0pi -e 's/ncliac=~\/.nodecliac\/src\/main\/init.sh;if \[ -f "\$ncliac" \];then source "\$ncliac";fi;//;s/\n+(\n)$/\1/gs' "$rcfilepath"
			# perl -pi -e "s/ncliac=~\/.nodecliac\/src\/main\/init.sh;if \[ -f \"\\\$ncliac\" \];then source \"\\\$ncliac\";fi;// if /^ncliac/" "$rcfilepath"
			echo -e "\033[32mSuccessfully\033[0m reverted \033[1m"$rcfilepath"\033[0m changes."
		fi

		# Delete main folder.
		if [[ -e ~/.nodecliac ]]; then rm -rf ~/.nodecliac; fi

		# Remove bin file.
		binfilepath=/usr/local/bin/nodecliac
		if [[ -f "$binfilepath" && -n "$(grep -o "\#\!/bin/bash" "$binfilepath")" ]]; then
			sudo rm -f "$binfilepath"
			echo -e "\033[32mSuccessfully\033[0m removed nodecliac bin file."
		fi

		;;

	*) ;;
esac
