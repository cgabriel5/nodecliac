#!/bin/bash

if [[ "$#" -eq 0 ]]; then exit; fi # Exit if no arguments provided.

# Get platform name.
#
# @return {string} - User's platform.
#
# @resource [https://stackoverflow.com/a/18434831]
function __platform() {
	case "$OSTYPE" in
		solaris*) echo "solaris" ;;
		darwin*)  echo "macosx" ;;
		linux*)   echo "linux" ;;
		bsd*)     echo "bsd" ;;
		msys*)    echo "windows" ;;
		*)        echo "unknown" ;;
	esac
}

# CLI arg flags.
rcfilepath=""
prcommand=""
enablencliac=""
disablencliac=""
command=""
version=""
all=""

# [https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f]
# [http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_09_07.html]
params=""
paramsargs=()
args=() # ("${@}")

# Paths.
registrypath=~/.nodecliac/registry

while (( "$#" )); do
	args+=("$1")
	case "$1" in
		--version) version="1"; shift ;;

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
			# Expand `~` in path: [https://stackoverflow.com/a/27485157]
			if [[ -n "$value" ]]; then rcfilepath="${value/#\~/$HOME}"; fi; shift ;;
		--rcfilepath)
			if [[ -n "$2" && "$2" != *"-" ]]; then rcfilepath="$2"; fi; shift ;;

		# Custom `remove|unlink|enable|disable` command flags.
		--all) all="1"; shift ;;

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
shift # Remove command from arguments array.

# If no command given but '--version' flag supplied show version.
setupfilepath=~/.nodecliac/.setup.db.json
if [[ -z "$command" && "$version" == "1" && -f "$setupfilepath" ]]; then
	# Get package.json version number. [https://stackoverflow.com/a/4794172]
	echo "$(perl -ne 'print $1 if /"version":\s*"([^"]+)/' "$setupfilepath")"
fi

# Allowed commands.
commands=" make format print registry setup status uninstall add remove link unlink enable disable "

if [[ "$commands" != *"$command"* ]]; then exit; fi # Exit if invalid command.

case "$command" in
	make|format)

		# Run Nim binary if it exists.
		binfilepath=~/.nodecliac/src/bin/nodecliac.$(__platform)""
		if [[ -f "$binfilepath" ]]; then "$binfilepath" "${args[@]}"; fi

		;;

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

		# Build acdef file paths string. [https://unix.stackexchange.com/a/96904]
		# for f in ~/.nodecliac/registry/*/*.acdef ~/.nodecliac/registry/*/.*.acdef; do
		# for f in ~/.nodecliac/registry/*/*.acdef; do

		# Count items in directory: [https://stackoverflow.com/a/33891876]
		count=$(ls 2>/dev/null -Ubad1 -- ~/.nodecliac/registry/* | wc -l)
		if [[ $count -lt 0 ]]; then ((count=count-1)); fi # Account for 0 base index.
		counter=0

		echo -e "\033[1;30m$registrypath\033[0m ($count)" # Print header.

		# Exit if directory is empty.
		if [[ "$count" == "0" ]]; then exit; fi

		for f in ~/.nodecliac/registry/*; do
			filename=$(basename "$f")
			# dirname=$(dirname "$f")
			# command="${filename%%.*}"
			command=$(basename "$f")

			# Build .acdef file paths.
			filename="$command.acdef"
			configfilename=".$command.config.acdef"
			acdefpath="$registrypath/$command/$filename"
			configpath="$registrypath/$command/$configfilename"

			isdir=0
			hasacdefs=0
			issymlink=0
			issymlinkdir=0
			realpath=""
			issymlink_valid=0
			check=0

			if [[ -f "$acdefpath" ]]; then check=1; fi # Check for .acdef.
			if [[ -f "$configpath" && "$check" == 1 ]]; then hasacdefs=1; fi # Check for config file.

			# If files exists check whether it's a symlink.
			pkgpath="$registrypath/$command"
			if [[ -d "$pkgpath" && ! -L "$pkgpath" ]]; then isdir=1; fi

			if [[ -L "$pkgpath" ]]; then
				issymlink=1

				# Resolve symlink: [https://stackoverflow.com/a/42918]
				# Using Python: [https://apple.stackexchange.com/a/4822]
				if [[ "$(__platform)" == "macosx" ]]; then
					resolved_path=$(readlink "$pkgpath")
				else
					resolved_path=$(readlink -f "$pkgpath")
				fi
				realpath="$resolved_path"

				if [[ -d "$resolved_path" ]]; then issymlinkdir=1; isdir=1; fi

				# Confirm symlink directory contain needed .acdefs.
				sympath="$resolved_path/$command/$filename"
				sympathconf="$resolved_path/$command/$configfilename"

				check=0
				if [[ -f "$sympath" ]]; then check=1; fi # Check for .acdef.
				if [[ -f "$sympathconf" && "$check" == 1 ]]; then issymlink_valid=1; fi # Check for config file.
			fi

				# Remove user name from path: [https://stackoverflow.com/a/22261454]
				re="^$HOME/(.*)"
				[[ "$realpath" =~ $re ]]
				realpath="~/${BASH_REMATCH[1]}"

				bcommand="\033[1;34m$command\033[0m"
				ccommand="\033[1;36m$command\033[0m"
				rcommand="\033[1;31m$command\033[0m"

				# Row declaration.
				decor="├── "; if [[ "$counter" == "$count" ]]; then decor="└── "; fi

				if [[ "$issymlink" == 0 ]]; then
					if [[ "$isdir" == 1 ]]; then
						dcommand=$([ "$hasacdefs" == 1 ] && echo "$bcommand" || echo "$rcommand")
						echo -e "$decor$dcommand/"
					else
						echo -e "$decor$rcommand"
					fi
				else
					if [[ "$issymlinkdir" == 1 ]]; then
						color=$([ "$issymlink_valid" == 1 ] && echo "\033[1;34m" || echo "\033[1;31m")
						linkdir="$color$realpath\033[0m"
						echo -e "$decor$ccommand -> $linkdir/"
					else
						echo -e "$decor$ccommand -> $realpath"
					fi
				fi

				((counter=counter+1)) # Increment counter.

		done

		# # Remove trailing newline: [https://unix.stackexchange.com/a/140738]
		# echo -e "$(echo -e "$header$output" | perl -0 -pe 's/\n\Z//')"

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

		# Only continue with uninstall if nodecliac was installed for 'binary'.
		if [[ -z "$(grep -o "binary" "$HOME/.nodecliac/.setup.db.json")" ]]; then exit; fi

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

	add)

		# Needed paths.
		cwd="$PWD"
		dirname=$(basename "$cwd") # Get package name.
		destination="$registrypath/$dirname"

		# If folder exists give error.
		if [[ -d "$destination" ]]; then
			# Check if folder is a symlink.
			type=$([ -L "$destination" ] && echo "Symlink " || echo "")
			echo -e "$type\033[1m$dirname\033[0m/ exists. First remove and try again."
		fi

		mkdir -p "$destination" # Create needed parent directories.

		# [https://stackoverflow.com/a/14922600]
		cp -r "$cwd" "$destination" # Copy folder to nodecliac registry.

		;;

	remove|unlink)

		# Empty registry when `--all` flag is provided.
		if [[ "$all" == "1" ]]; then
			rm -rf "$registrypath" # Delete directory.
			mkdir -p "$registrypath" # Create registry.
			paramsargs=() # Empty packages array to skip loop.
		fi

		# Loop over packages and remove each if its exists.
		for pkg in "${paramsargs[@]}"; do
			# Needed paths.
			destination="$registrypath/$pkg"

			# If folder does not exist don't do anything.
			if [[ ! -d "$destination" ]]; then continue; fi

			rm -rf "$destination" # Delete directory.
		done

		;;

	link)

		# Needed paths.
		cwd="$PWD"
		dirname=$(basename "$cwd") # Get package name.
		destination="$registrypath/$dirname"

		# If folder exists give error.
		if [[ ! -d "$cwd" ]]; then exit; fi # Confirm cwd exists.

		# If folder exists give error.
		if [[ -d "$destination" || -L "$destination" ]]; then
			# Check if folder is a symlink.
			type=$([ -L "$destination" ] && echo "Symlink " || echo "")
			echo -e "$type\033[1m$dirname\033[0m/ exists. First remove and try again."
		fi

		ln -s "$cwd" "$destination" # Create symlink.

		;;

	enable|disable)

		# Enable all packages when '--all' is provided.
		if [[ "$all" == "1" ]]; then
			paramsargs=()
			# Get package names.
			for f in "$registrypath"/*; do
				paramsargs+=("$(basename "$f")")
			done
		fi

		state=$([ "$command" == "enable" ] && echo "false" || echo "true")

		# Loop over packages and remove each if its exists.
		for pkg in "${paramsargs[@]}"; do
			# Needed paths.
			filepath="$registrypath/$pkg/.$pkg.config.acdef"

			# Resolve symlink: [https://stackoverflow.com/a/42918]
			# Using Python: [https://apple.stackexchange.com/a/4822]
			if [[ "$(__platform)" == "macosx" ]]; then
				resolved_path=$(readlink "$filepath")
			else
				resolved_path=$(readlink -f "$filepath")
			fi

			# Ensure file exists before anything.
			if [[ ! -f "$resolved_path" ]]; then continue; fi

			# Remove current value from config.
			contents="$(<"$resolved_path")" # Get config file contents.

			contents=$(perl -pe 's/^\@disable.*?$//gm' <<< "$contents")
			# Append newline to eof: [https://stackoverflow.com/a/15791595]
			contents+=$'\n@disable = '"$state"$'\n' # Add new value to config.

			# Cleanup contents.
			contents=$(perl -pe 's!^\s+?$!!' <<< "$contents") # Remove newlines.
			# # Add newline after header.: [https://stackoverflow.com/a/549261]
			contents=$(perl -pe 's/^(.*)$/$1\n/ if 1 .. 1' <<< "$contents")

			echo "$contents" > "$filepath" # Save changes.
		done

		;;

	*) ;;
esac
