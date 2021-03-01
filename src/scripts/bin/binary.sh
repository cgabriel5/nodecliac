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

# Takes a relative path and returns its absolute path.
#
# @return {string} - The relative path.
#
# @resource [https://stackoverflow.com/a/31605674]
# @resource [https://stackoverflow.com/a/20500246]
# @resource [https://stackoverflow.com/a/21188136]
# @resource [https://stackoverflow.com/a/25880707]
function resolve {
	local a=""
	local p="$1"

	# Return on empty path.
	[[ -z "$p" ]] && echo ""

	# Try readlink if installed.
	if [[ "$(command -v readlink)" ]]; then
		# Resolve symlink: [https://stackoverflow.com/a/42918]
		# Using Python: [https://apple.stackexchange.com/a/4822]
		if [[ "$(platform)" == "macosx" ]]; then
			a="$(readlink "$p")"
		else
			a="$(readlink -f "$p")"
		fi

	# Else use fallback.
	else

		# Remove trailing slash.
		[[ "$p" == *"/" ]] && p="${p::-1}"

		case "$p" in
			".") a="$(pwd)" ;;
			"..") a="$(dirname "$(pwd)")" ;;
			*)
				head="$(dirname "$p")"
				[[ -e "$head" ]] && a="$(cd "$head" && pwd)/$(basename "$p")"
				;;
		esac
	fi

	# Ensure that path exists.
	[[ -e "$a" ]] && echo "$a" || echo ""
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

# Collapse starting home dir in a path to '~'.
#
# @param  {string} p - The path.
# @return {undefined} - Nothing is returned.
function shrink() {
	p="$1"
	if [[ "$p" == "$HOME" ]]; then
		echo "~"
	elif [[ "$p" == "$HOME"* ]]; then
		hlen="${#HOME}"
		echo "~${p:$hlen}"
	else
		echo "$1"
	fi
}

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

# Download webpage contents.
#
# @return {string} - The webpage's URL.
#
# @resource [https://stackoverflow.com/a/3742990]
function download {
	if [[ "$(command -v curl)" ]]; then
		echo "$(curl -s -L "$1")"
	elif [[ "$(command -v wget)" ]]; then
		echo "$(wget -q -O - "$1")"
	fi
}

# ANSI colors: [https://stackoverflow.com/a/5947802]
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
MAGENTA="\033[0;35m"
# Bold colors.
BOLD="\033[1m"
ITALIC="\033[3m"
BRED="\033[1;31m"
BBLUE="\033[1;34m"
BMAGENTA="\033[1;35m"
BTURQ="\033[1;36m"
BGREEN="\033[1;32m"
NC="\033[0m"

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
path=""
skipval=""
repo=""

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
				else
					debug_enable="1"; shift
				fi ;;
		--disable)
				if [[ "$command" == "status" ]]; then
					disablencliac="1"; shift
				else
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

		# `add|link` command flags.
		--path=*)
			flag="${1%%=*}"; value="${1#*=}"
			if [[ -n "$value" ]]; then path="$value"; fi; shift ;;
		--path)
			if [[ -n "$2" && "$2" != *"-" ]]; then path="$2"; fi; shift ;;

		# `add` command flags.
		--force) force="1"; shift ;;
		--skip-val) skipval="1"; shift ;;
		--repo=*)
			flag="${1%%=*}"; value="${1#*=}"
			if [[ -n "$value" ]]; then repo="$value"; fi; shift ;;
		--repo)
			if [[ -n "$2" && "$2" != *"-" ]]; then repo="$2"; fi; shift ;;

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
commands=" bin init make format print registry setup status uninstall add remove link unlink enable disable cache test debug "

# Exit if invalid command.
if [[ "$commands" != *"$command"* ]]; then
	echo -e "Unknown command ${BOLD}$command${NC}"
	exit
fi

case "$command" in

	init)

		cwd="$PWD"

		function init() {
			restart="$1"
			[[ "$restart" == 1 ]] && echo ""

			echo -e "${BBLUE}Info:${NC} nodecliac completion package initialization." > /dev/tty

			local command=""
			local padding=""
			local def="${BTURQ}${ITALIC}default${NC}"
			local pprefix="$padding${BMAGENTA}Prompt:${NC}"
			local aprefix="$padding${BGREEN}Answer:${NC}"

			# Print reply/response.
			#
			# @param  {string} reply - The provided reply.
			# @return {undefined} - Nothing is returned.
			function preply() {
				reply="$1"
				echo -e "$aprefix ${BOLD}$reply${NC}" > /dev/tty
			}

			while [[ -z "$command" ]]; do
				echo -en "$pprefix [1/6] Completion package command (${YELLOW}required${NC}): "
				read command
				# Clear line on empty response.
				[[ -z "$command" ]] && tput cuu 1 && tput el
			done
			command="$(trim "$command")"

			# Check for existing same name completion package.
			local pkgpath="$cwd/$command"
			local spkgpath="$(shrink "$pkgpath")"
			if [[ -z "$force" && -d "$pkgpath" ]]; then
				echo -e "${BRED}Error:${NC} Directory ${BOLD}$command${NC} already exists at:"
				echo -e "... $spkgpath"
				echo -e "${BBLUE}Tip:${NC} Run with --force flag to overwrite existing folder."
				exit
			fi

			preply "$command"
			local author=""; echo -en "$pprefix [2/6] Author (GitHub username or real name): "
			read author
			preply "$author"
			local version=""; echo -en "$pprefix [3/6] Version [${def} 0.0.1]: "
			read version
			version="${version:-0.0.1}"
			preply "$version"
			local des_def="Completion package for $command"
			local description=""; echo -en "$pprefix [4/6] Description [${def} ${des_def}]: "
			read description
			description="${description:-$des_def}"
			preply "$description"
			local license=""; echo -en "$pprefix [5/6] Project license [${def} MIT]: "
			read license
			license="${license:-MIT}"
			preply "$license"
			local repo=""; echo -en "$pprefix [6/6] Github repo: (i.e. username/repository) "
			read repo
			preply "$repo"

			local content=$(cat <<-END
	${MAGENTA}[Package]${NC}
	name = "$command"
	version = "$version"
	description = "$description"
	license = "$license"

	${MAGENTA}[Author]${NC}
	name = "$author"
	repo = "$repo"
END
)

			echo ""
			echo -e "${BBLUE}Info:${NC} package.ini will contain the following:"
			echo ""
			echo -e "$content"

			echo ""
			echo -e "${BBLUE}Info:${NC} Completion package base structure:"
			echo ""

			local tree=$(cat <<-END
	$spkgpath
	├── $command.acmap
	├── $command.acdef
	├── .$command.config.acmap
	└── package.ini
END
)

			echo -e "$tree"
			echo ""

			local confirmation=""
			local allowed=" y yes c cancel n no r restart "
			while [[ "$allowed" != *" ${confirmation,,} "* ]]; do
				echo -e -n "$pprefix Looks good, create package? [${BTURQ}${ITALIC}default${NC} ${BTURQ}y${NC}]es, [c]ancel, [r]estart: "
				read confirmation
				confirmation="${confirmation:-y}"
				# Clear line on empty response.
				[[ "$allowed" != *" ${confirmation,,} "* ]] && tput cuu 1 && tput el
			done

			local fchar="${confirmation:0:1}"
			confirmation="${fchar,,}"
			preply "$confirmation"
			case "$confirmation" in
				"y")
					# Create basic completion package for command.
					mkdir -p "$pkgpath"
					local pkginipath="$pkgpath/package.ini"
					local acmappath="$pkgpath/$command.acmap"
					local acdefpath="$pkgpath/$command.acdef"
					local configpath="$pkgpath/.$command.config.acmap"
					# Strip ansi colors: [https://superuser.com/a/561105]
					# [https://superuser.com/a/380776]
					# content="$(perl -pe 's/\\x1b\[[0-9;]*[mG]//g' <<< "$content")"
					content="$(perl -pe 's/\\033\[\d*(;\d*)*m//g' <<< "$content")"
					# [https://unix.stackexchange.com/a/573371]
					install -m 775 <(echo "$content") "$pkginipath"
					# [https://unix.stackexchange.com/a/47182]
					install -m 775 /dev/null "$acmappath"
					install -m 775 /dev/null "$acdefpath"
					install -m 775 /dev/null "$configpath"
					echo ""
					echo -e "${BBLUE}Info:${NC} completion packaged created at:"
					echo -e "... $spkgpath"
					;;
				"c")
					echo ""
					echo -e "${BBLUE}Info:${NC} Completion package initialization cancelled."
					exit
					;;
				"r") init "1" ;;
			esac
		}

		init

		;;

	bin)

		echo "$(command -v nodecliac)"

		;;

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
				echo -e "${BOLD}[$prcommand.acdef]${NC}\n$(cat "$acdefpath")"
			fi
			if [[ -e "$acdefconfigpath" ]]; then
				echo -e "${BOLD}[$prcommand.config.acdef]${NC}\n$(cat "$acdefconfigpath")"
			fi
		fi

		;;

	registry)

		# Build acdef file paths string. [https://unix.stackexchange.com/a/96904]
		# for f in ~/.nodecliac/registry/*/*.acdef ~/.nodecliac/registry/*/.*.acdef; do
		# for f in ~/.nodecliac/registry/*/*.acdef; do

		# Count items in directory: [https://stackoverflow.com/a/33891876]
		count="$(trim "$(ls 2>/dev/null -Ubd1 -- ~/.nodecliac/registry/* | wc -l)")"
		rdir="${registrypath/#$HOME/\~}" # Un-expand tilde:
		echo -e "${BBLUE}$rdir/${NC}" # Print header.
		[[ $count -gt 0 && $count != 1 ]] && count="$((count - 1))" # Account for 0 base index.
		counter=0

		# Exit if directory is empty.
		if [[ "$count" == "0" ]]; then
			if [[ "$counter" == 1 ]]; then
				echo -e "\n$counter package"
			else
				echo -e "\n$counter packages"
			fi
			exit
		fi

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

				resolved=$(resolve "$pkgpath")
				realpath="$resolved"

				if [[ -d "$resolved" ]]; then issymlinkdir=1; isdir=1; fi

				# Confirm symlink directory contain needed .acdefs.
				sympath="$resolved/$command/$filename"
				sympathconf="$resolved/$command/$configfilename"

				check=0
				if [[ -f "$sympath" ]]; then check=1; fi # Check for .acdef.
				if [[ -f "$sympathconf" && "$check" == 1 ]]; then issymlink_valid=1; fi # Check for config file.
			fi

				# Remove user name from path: [https://stackoverflow.com/a/22261454]
				re="^$HOME/(.*)"
				[[ "$realpath" =~ $re ]]
				realpath="~/${BASH_REMATCH[1]}"

				bcommand="${BBLUE}$command${NC}"
				ccommand="${BTURQ}$command${NC}"
				rcommand="${BRED}$command${NC}"

				# Row declaration.
				decor="├── "; if [[ "$counter" == "$count" || "$count" == 1 ]]; then decor="└── "; fi

				if [[ "$issymlink" == 0 ]]; then
					if [[ "$isdir" == 1 ]]; then
						dcommand=$([ "$hasacdefs" == 1 ] && echo "$bcommand" || echo "$rcommand")
						echo -e "$decor$dcommand/"
					else
						echo -e "$decor$rcommand"
					fi
				else
					if [[ "$issymlinkdir" == 1 ]]; then
						color=$([ "$issymlink_valid" == 1 ] && echo "${BBLUE}" || echo "${BRED}")
						linkdir="$color$realpath${NC}"
						echo -e "$decor$ccommand -> $linkdir/"
					else
						echo -e "$decor$ccommand -> $realpath"
					fi
				fi

				((counter=counter+1)) # Increment counter.

		done

		if [[ "$counter" == 1 ]]; then
			echo -e "\n$counter package"
		else
			echo -e "\n$counter packages"
		fi

		# # Remove trailing newline: [https://unix.stackexchange.com/a/140738]
		# echo -e "$(echo -e "$header$output" | perl -0 -pe 's/\n\Z//')"

		;;

	setup) ;; # No-operation.

	status)
		initconfig

		# If no flag is supplied then only print the status.
		if [[ -z "$enable" && -z "$disable" ]]; then
			status="$(getsetting status)"
			message="nodecliac: ${RED}off${NC}"
			[[ "$status" == 1 ]] && message="nodecliac: ${GREEN}on${NC}"
			echo -e "$message"
		else
			if [[ -n "$enable" && -n "$disable" ]]; then
				varg1="${BOLD}--enable${NC}"
				varg2="${BOLD}--disable${NC}"
				echo -e "$varg1 and $varg2 given when only one can be provided." && exit 1
			fi

			if [[ -n "$enable" ]]; then
				setsetting status 1 # perl -pi -e 's/^./1/' "$config"
				echo -e "${GREEN}off${NC}"
			elif [[ -n "$disable" ]]; then
				# timestamp="$(perl -MTime::HiRes=time -e 'print int(time() * 1000);')"
				# [https://www.tutorialspoint.com/perl/perl_date_time.htm]
				# date="$(perl -e 'use POSIX qw(strftime); $datestring = strftime "%a %b %d %Y %H:%M:%S %z (%Z)", localtime; print "$datestring"')"
				# contents="Disabled: $date;$timestamp"
				setsetting status 0 # perl -pi -e 's/^./0/' "$config"
				echo -e "${RED}off${NC}"
			fi
		fi

		;;

	debug)
		initconfig

		if [[ -n "$enablencliac" && -n "$disablencliac" ]]; then
			varg1="${BOLD}--enable${NC}"
			varg2="${BOLD}--disable${NC}"
			echo -e "$varg1 and $varg2 given when only one can be provided."
		fi

		# 0=off , 1=debug , 2=debug + ac.pl , 3=debug + ac.nim
		if [[ -n "$debug_enable" ]]; then
			value=1
			if [[ "$debug_script" == "nim" ]]; then value=3
			elif [[ "$debug_script" == "perl" ]]; then value=2; fi
			setsetting debug "$value"
			echo -e "${GREEN}on${NC}"
		elif [[ -n "$debug_disable" ]]; then
			setsetting debug 0
			echo -e "${RED}off${NC}"
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
			perl -pi -e "s/ncliac=~\/.nodecliac\/src\/main\/init.sh;if \[ -f \"\\\$ncliac\" \];then source \"\\\$ncliac\";fi;if /^ncliac/" "$rcfile"
			echo -e "${GREEN}success${NC} reverted ${BOLD}"$rcfile"${NC} changes."
		fi

		# Delete main folder.
		if [[ -e ~/.nodecliac ]]; then rm -rf ~/.nodecliac; fi

		# Remove bin file.
		binfilepath=/usr/local/bin/nodecliac
		if [[ -f "$binfilepath" && -n "$(grep -o "\#\!/bin/bash" "$binfilepath")" ]]; then
			sudo rm -f "$binfilepath"
			echo -e "${GREEN}success${NC} removed nodecliac bin file."
		fi

		;;

	add)

			# Checks whether completion package has a valid base structure.
			#
			# @param  {string} command - The completion package command.
			# @param  {string} dir     - The directory path of package.
			# @return {boolean} - The validation check result.
			function check() {
				local result=1, re=""

				local prefix="${RED}Error:${NC} Package missing ./"
				function perror() {
					file="$1"
					result=0
					echo -e "$prefix${BOLD}$file${NC}" > /dev/tty
				}

				# If a single item is provided a folder contents
				# check is performed.
				if [[ "${#@}" == 2 ]]; then
					local command="$1"
					local dir="$2"
					# Validate repo's basic package structure: Must
					# contain: acmap, acdef, and config.acdef root files.
					local ini="package.ini"
					local acmap="$command.acmap"
					local acdef="$command.acdef"
					local config=".$command.config.acdef"
					local inipath="$dir/$ini"
					local acmappath="$dir/$acmap"
					local acdefpath="$dir/$acdef"
					local configpath="$dir/$config"
					[[ ! -f "$acmappath" ]] && perror "$acmap"
					[[ ! -f "$acdefpath" ]] && perror "$acdef"
					[[ ! -f "$configpath" ]] && perror "$config"
					[[ ! -f "$inipath" ]] && perror "$ini"
				else
					# Check for multiple lines individually.
					local command="$1"
					local contents="$2"
					contents="$(trim "$contents")"

					re="svn: E[[:digit:]]{6}:" # [https://stackoverflow.com/a/32607896]
					[[ "$contents" =~ $re ]] && echo "Provided URL does not exist." > /dev/tty

					local ini="package.ini"
					local acmap="$command.acmap"
					local acdef="$command.acdef"
					local config=".$command.config.acdef"

					[[ ! "$(grep -o "^$ini$" <<< "$contents")" ]] && perror "$ini"
					[[ ! "$(grep -o "^$acmap$" <<< "$contents")" ]] && perror "$acmap"
					[[ ! "$(grep -o "^$acdef$" <<< "$contents")" ]] && perror "$acdef"
					[[ ! "$(grep -o "^$config$" <<< "$contents")" ]] && perror "$config"
				fi

				echo "$result"
			}

		[[ -n "$path" && "$path" != /* ]] && path="$(resolve "$path")"

		sub=""
		if [[ -n "$repo" && -z "$path" ]]; then
			if [[ "$repo" == *"/trunk/"* ]]; then
				# [https://superuser.com/a/1001979]
				# [https://stackoverflow.com/a/20348190]
				needle="/trunk/"
				nlen="${#needle}"
				sub=${repo#*$needle}
				repo="${repo%%$needle*}"
				# index=$(( ${#repo} - ${#rest} - $nlen ))
				# repo="${repo:0:$index}"
				# sub="${repo:$(( index + nlen ))}"
			fi
		fi

		# Extract possibly provided branch name.
		r_branch="master"
		if [[ "$repo" == *"#"* ]]; then
			r_branch="${repo#*#}"
			repo="${repo%%#*}"
		fi

		[[ "$sub" == *"/" ]] && sub="${sub::-1}"
		[[ "$repo" == *"/" ]] && repo="${repo::-1}"

		if [[ -z "$repo" ]]; then
			cwd=$([ -n "$path" ] && echo "$path" || echo "$PWD")
			dirname=$(basename "$cwd") # Get package name.
			pkgpath="$registrypath/$dirname"

			# If package exists error.
			if [[ -d "$pkgpath" ]]; then
				# Check if folder is a symlink.
				type=$([ -L "$pkgpath" ] && echo "Symlink " || echo "")
				echo -e "$type${BOLD}$dirname${NC}/ exists in registry. Remove it and try again."
				exit
			fi

			# Validate package base structure.
			[[ -z "$skipval" && "$(check "$dirname" "$cwd")" == 0 ]] && exit

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
				echo -e "${BOLD}$dirname${NC}/ exceeds 10MB. Use --force to add package anyway." && exit
			fi

			mkdir -p "$pkgpath"
			cp -r "$cwd" "$registrypath" # [https://stackoverflow.com/a/14922600]

		else

			uri=""; cmd=""; err=""; res=""
			rname="${repo#*/}"
			timestamp="$(perl -MTime::HiRes=time -e 'print int(time() * 1000);')"
			output="$HOME/Downloads/$rname-$timestamp"

			# Reset rname if subdirectory is provided.
			[[ -n "$sub" ]] && rname="${sub##*/}"

			# If package exists error.
			pkgpath="$registrypath/$rname"
			if [[ -d "$pkgpath" ]]; then
				# Check if folder is a symlink.
				type=$([ -L "$pkgpath" ] && echo "Symlink " || echo "")
				echo -e "$type${BOLD}$rname${NC}/ exists in registry. Remove it and try again."
				exit
			fi

			# Use git: [https://stackoverflow.com/a/60254704]
			if [[ -z "$sub" ]]; then
				# Ensure repo exists.
				uri="https://api.github.com/repos/$repo/branches/${r_branch}"
				res="$(download "$uri")"
				[[ -z "$res" ]] && echo "Provided URL does not exist." && exit

				# Download repo with git.
				uri="git@github.com:$repo.git"
				# [https://stackoverflow.com/a/42932348]
				git clone "$uri" "$output" >/dev/null 2>&1
			else
				# Use svn: [https://stackoverflow.com/a/18194523]

				# First check that svn is installed.
				[[ -z "$(command -v svn)" ]] && echo "\`svn' is not installed." && exit

				# Check that repo exists.
				uri="https://github.com/$repo/trunk/$sub"
				if [[ "$branch" != "master" ]]; uri="https://github.com/${repo}/branches/${r_branch}/${sub}"
				res="$(svn ls "$uri")"

				# Use `svn ls` output here to validate package base structure.
				[[ -z "$skipval" && "$(check "$rname" "$res" "0")" == 0 ]] && exit

				re="svn: E[[:digit:]]{6}:" # [https://stackoverflow.com/a/32607896]
				[[ "$res" =~ $re ]] && echo "Provided repo URL does not exist."

				# Use svn to download provided sub directory.
				svn export "$uri" "$output" > /dev/null 2>&1
			fi

			# Validate package base structure.
			[[ -z "$skipval" && "$(check "$rname" "$output")" == 0 ]] && exit

			# Move repo to registry.
			[[ ! -d "$registrypath" ]] && "nodecliac registry ${BOLD}$registrypath${NC} doesn't exist."
			# Delete existing registry package if it exists.
			[[ -d "$pkgpath" ]] && rm -rf "$pkgpath"
			mv "$output" "$pkgpath"

		fi

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
			echo -e "File ${BOLD}${errscript}${NC} doesn't exit."
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

		[[ -n "$path" && "$path" != /* ]] && path="$(resolve "$path")"

		cwd=$([ -n "$path" ] && echo "$path" || echo "$PWD")
		dirname=$(basename "$cwd") # Get package name.
		destination="$registrypath/$dirname"

		# If folder exists give error.
		if [[ ! -d "$cwd" ]]; then exit; fi # Confirm cwd exists.

		# If folder exists give error.
		if [[ -d "$destination" || -L "$destination" ]]; then
			# Check if folder is a symlink.
			type=$([ -L "$destination" ] && echo "Symlink " || echo "")
			echo -e "$type${BOLD}$dirname${NC}/ exists. Remove it and try again."
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

			resolved=$(resolve "$filepath")

			# Ensure file exists before anything.
			if [[ ! -f "$resolved" ]]; then continue; fi

			# Remove current value from config.
			contents="$(<"$resolved")" # Get config file contents.

			contents=$(perl -pe 's/^\@disable.*?$//gm' <<< "$contents")
			# Append newline to eof: [https://stackoverflow.com/a/15791595]
			contents+=$'\n@disable = '"$state"$'\n' # Add new value to config.

			# Cleanup contents.
			contents=$(perl -pe 's!^\s+?$!!' <<< "$contents") # Remove newlines.
			# Add newline after header.: [https://stackoverflow.com/a/549261]
			contents=$(perl -pe 's/^(.*)$/$1\n/ if 1 .. 1' <<< "$contents")

			echo "$contents" > "$filepath" # Save changes.
		done

		;;

	cache)

		cachepath=~/.nodecliac/.cache

		initconfig

		if [[ -d "$cachepath" && "$ccache" == "1" ]]; then
			rm -rf "$cachepath"/*
			echo -e "${GREEN}success${NC} Cleared cache."
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
