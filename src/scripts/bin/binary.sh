#!/bin/bash

if [[ "$#" -eq 0 ]]; then exit; fi

# Get platform name.
#
# @return {string} - User's platform.
#
# @resource [https://stackoverflow.com/a/18434831]
function platform() {
	case "$OSTYPE" in
		solaris*) echo "solaris" ;;
		darwin*)  echo "macosx" ;;
		linux*)   echo "linux" ;;
		bsd*)     echo "bsd" ;;
		msys*)    echo "windows" ;;
		*)        echo "unknown" ;;
	esac
}

# Create config file if it's empty or does not exist yet.
#
# @return {undefined} - Nothing is returned.
function initconfig() {
	# Config settings:
	# [1] status (disabled)
	# [2] cache
	# [3] debug
	# [4] singletons
	local root=~/.nodecliac
	local config="$root/.config"
	[[ ! -e "$config" || ! -s "$config" ]] && echo "1101" > "$config"
}

# Returns config setting.
#
# @param  {string} setting - The setting name.
# @return {undefined} - Nothing is returned.
function getsetting() {
	local root=~/.nodecliac
	local config="$root/.config"
	local cstring=$(<"$config")
	# [https://stackoverflow.com/a/3352015]
	cstring="${cstring%"${cstring##*[![:space:]]}"}"
	case "$1" in
		status) echo "${cstring:0:1}" ;;
		cache) echo "${cstring:1:1}" ;;
		debug) echo "${cstring:2:1}" ;;
		singletons) echo "${cstring:3:1}" ;;
	esac
}

# Sets the config setting.
#
# @param  {string} setting - The setting name.
# @param  {string} value - The setting's value.
# @return {undefined} - Nothing is returned.
function setsetting() {
	local root=~/.nodecliac
	local config="$root/.config"
	local cstring=$(<"$config")
	# [https://stackoverflow.com/a/3352015]
	cstring="${cstring%"${cstring##*[![:space:]]}"}"
	case "$1" in
		status) cstring="$2${v:1}" ;;
		cache) cstring="${cstring:0:1}$2${cstring:2}" ;;
		debug) cstring="${cstring:0:2}$2${cstring:3}" ;;
		singletons) cstring="${cstring:0:3}$2${cstring:4}" ;;
	esac
	echo "$cstring" > "$config"
}

rcfile=""
prcommand=""
enablencliac=""
disablencliac=""
debug_enable=""
debug_disable=""
debug_script=""
command=""
version=""
ccache=""
level=""
force=""
setlevel=0
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

		# `print` command flags.
		--command=*)
			flag="${1%%=*}"; value="${1#*=}"
			if [[ -n "$value" ]]; then prcommand="$value"; fi; shift ;;
		--command)
			if [[ -n "$2" && "$2" != *"-" ]]; then prcommand="$2"; fi; shift ;;

		# `status` command flags.
		--enable) enablencliac="1"; shift ;;
		--disable) disablencliac="1"; shift ;;

		# `status|debug` command flags.
		--enable)
				if [[ "$command" == "status" ]]; then
					enablencliac="1"; shift
				elif
					debug_enable="1"; shift
				fi ;;
		--disable)
				if [[ "$command" == "status" ]]; then
					disablencliac="1"; shift
				elif
					debug_disable="1"; shift
				fi ;;

		# `debug` command flag.
		--script=*)
			flag="${1%%=*}"; value="${1#*=}"
			[[ -n "$value" ]] && debug_script="$value" && shift ;;
		--script)
			[[ -n "$2" && "$2" != *"-" ]] && debug_script="$2" && shift ;;

		# `cache` command flags.
		--clear) ccache="1"; shift ;;
		--level=*)
			setlevel=1
			flag="${1%%=*}"; value="${1#*=}"
			if [[ -n "$value" ]]; then level="$value"; fi; shift ;;
		--level)
			setlevel=1
			if [[ -n "$2" && "$2" != *"-" ]]; then level="$2"; fi; shift ;;

		# `uninstall` command flags.
		--rcfile=*)
			# Expand `~` in path: [https://stackoverflow.com/a/27485157]
			if [[ -n "$value" ]]; then rcfile="${value/#\~/$HOME}"; fi; shift ;;
		--rcfile)
			if [[ -n "$2" && "$2" != *"-" ]]; then rcfile="$2"; fi; shift ;;

		# `remove|unlink|enable|disable` command flags.
		--all) all="1"; shift ;;

		# `add` command flags.
		--force) force="1"; shift ;;

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
eval set -- "$params" # Set positional arguments in their proper place.
shift # Remove command from arguments array.

# If no command given but '--version' flag supplied show version.
setupfilepath=~/.nodecliac/.setup.db.json
if [[ -z "$command" && "$version" == "1" && -f "$setupfilepath" ]]; then
	# Get package.json version number. [https://stackoverflow.com/a/4794172]
	echo "$(perl -ne 'print $1 if /"version":\s*"([^"]+)/' "$setupfilepath")"
fi

# Allowed commands.
commands=" make format print registry setup status uninstall add remove link unlink enable disable cache test debug "

if [[ "$commands" != *"$command"* ]]; then exit; fi # Exit if invalid command.

case "$command" in
	make|format)

		# Run Nim binary if it exists.
		binfilepath=~/.nodecliac/src/bin/nodecliac.$(platform)""
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

		# Trim string whitespace.
		#
		# @return {string} - Trimmed string.
		#
		# @resource [https://stackoverflow.com/a/3352015]
		function trim() {
			local arg="$*"
			arg="${arg#"${arg%%[![:space:]]*}"}" # Remove leading ws.
			arg="${arg%"${arg##*[![:space:]]}"}" # Remove trailing ws.
			printf '%s' "$arg"
		}

		# Count items in directory: [https://stackoverflow.com/a/33891876]
		count="$(trim "$(ls 2>/dev/null -Ubd1 -- ~/.nodecliac/registry/* | wc -l)")"
		echo -e "\033[1m$registrypath\033[0m ($count)" # Print header.
		[[ $count -gt 0 ]] && count="$((count - 1))" # Account for 0 base index.
		counter=0

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
				if [[ "$(platform)" == "macosx" ]]; then
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
		initconfig

		# If no flag is supplied then only print the status.
		if [[ -z "$enable" && -z "$disable" ]]; then
			status="$(getsetting status)"
			message="nodecliac: \033[0;31moff\033[0m"
			[[ "$status" == 1 ]] && message="nodecliac: \033[0;32mon\033[0m"
			echo -e "$message"
		else
			if [[ -n "$enable" && -n "$disable" ]]; then
				varg1="\033[1m--enable\033[0m"
				varg2="\033[1m--disable\033[0m"
				echo -e "$varg1 and $varg2 given when only one can be provided." && exit 1
			fi

			if [[ -n "$enable" ]]; then
				setsetting status 1 # perl -pi -e 's/^./1/' "$config"
				echo -e "\033[0;32moff\033[0m"
			elif [[ -n "$disable" ]]; then
				# timestamp="$(perl -MTime::HiRes=time -e 'print int(time() * 1000);')"
				# [https://www.tutorialspoint.com/perl/perl_date_time.htm]
				# date="$(perl -e 'use POSIX qw(strftime); $datestring = strftime "%a %b %d %Y %H:%M:%S %z (%Z)", localtime; print "$datestring"')"
				# contents="Disabled: $date;$timestamp"
				setsetting status 0 # perl -pi -e 's/^./0/' "$config"
				echo -e "\033[0;31moff\033[0m"
			fi
		fi

		;;

	debug)
		initconfig

		if [[ -n "$enablencliac" && -n "$disablencliac" ]]; then
			varg1="\033[1m--enable\033[0m"
			varg2="\033[1m--disable\033[0m"
			echo -e "$varg1 and $varg2 given when only one can be provided."
		fi

		# 0=off , 1=debug , 2=debug + ac.pl , 3=debug + ac.nim
		if [[ -n "$debug_enable" ]]; then
			value=1
			if [[ "$debug_script" == "nim" ]]; then value=3
			elif [[ "$debug_script" == "pl" ]]; then value=2; fi
			setsetting debug "$value"
			echo -e "\033[0;32mon\033[0m"
		elif [[ -n "$debug_disable" ]]; then
			setsetting debug 0
			echo -e "\033[0;31moff\033[0m"
		else
			getsetting debug
		fi

		;;

	uninstall)

		# Prompt password early on. Also ensures user really wants to uninstall.
		sudo echo > /dev/null 2>&1

		# Only continue with uninstall if nodecliac was installed for 'binary'.
		if [[ -z "$(grep -o "binary" "$HOME/.nodecliac/.setup.db.json")" ]]; then exit; fi

		# Confirm bashrcfile exists else default to ~/.bashrc.
		if [[ -z "$rcfile" ]] ||
			[[ ! -e "$rcfile" && ! -f "$rcfile" ]]; then rcfile=~/.bashrc; fi

		# Remove nodecliac from ~/.bashrc.
		if [[ -n "$(grep -o "ncliac=~/.nodecliac/src/main/init.sh" "$rcfile")" ]]; then
			# [https://stackoverflow.com/a/57813295]
			perl -0pi -e 's/([# \t]*)\bncliac.*"\$ncliac";?\n?//g;s/\n+(\n)$/\1/gs' ~/.bashrc
			# perl -pi -e "s/ncliac=~\/.nodecliac\/src\/main\/init.sh;if \[ -f \"\\\$ncliac\" \];then source \"\\\$ncliac\";fi;// if /^ncliac/" "$rcfile"
			echo -e "\033[32mSuccessfully\033[0m reverted \033[1m"$rcfile"\033[0m changes."
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
			exit
		fi

		# Skip size check when --force is provided.
		if [[ -z "$force" ]]; then
			if [[ "$(platform)" == "macosx" ]]; then
				# [https://serverfault.com/a/913506]
				size=$(du -skL "$cwd" | grep -oE '[0-9]+' | head -n1)
			else
				# [https://stackoverflow.com/a/22295129]
				size=$(du --apparent-size -skL "$cwd" | grep -oE '[0-9]+' | head -n1)
			fi
			# Anything larger than 10MB must be force added.
			[[ -n "$(perl -e 'print int('"$size"') > 10000')" ]] &&
			echo -e "\033[1m$dirname\033[0m/ exceeds 10MB. Use --force to add package anyway." && exit
		fi

		mkdir -p "$destination" # Create needed parent directories.

		# [https://stackoverflow.com/a/14922600]
		cp -r "$cwd" "$registrypath" # Copy folder to nodecliac registry.

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

	test)

		errscript="$HOME/.nodecliac/src/main/test.sh"
		if [[ ! -f "$errscript" ]]; then
			echo -e "File \033[1m${errscript}\033[0m doesn't exit."
			exit
		fi

		# Loop over packages and remove each if its exists.
		for pkg in "${paramsargs[@]}"; do
			# Needed paths.
			pkgpath="$registrypath/$pkg"
			test="$pkgpath/$pkg.tests.sh"

			[[ ! -f "$test" ]] && continue
			"$errscript" "-p" "true" "-f" "true" "-t" "$test"
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
			exit
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
			if [[ "$(platform)" == "macosx" ]]; then
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

	cache)

		cachepath=~/.nodecliac/.cache

		initconfig

		if [[ -d "$cachepath" && "$ccache" == "1" ]]; then
			rm -rf "$cachepath"/*
			echo -e "\033[0;32msuccess\033[0m Cleared cache."
		fi

		if [[ "$setlevel" == 1 ]]; then
			if [[ ! -z "${level##*[!0-9]*}" ]]; then
				[[ " 0 1 2 " != *" $level "* ]] && level=1
				setsetting cache "$level"
			else
				getsetting cache
			fi
		fi

		;;

	*) ;;
esac
