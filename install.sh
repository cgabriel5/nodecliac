#!/bin/bash

_() {
set -euo pipefail # [https://sipb.mit.edu/doc/safe-shell/]

# Get platform name.
#
# @return {string} - User's platform.
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

# Checks if command exists.
#
# @param {string} 1) - Command name.
# @return {string} - Command path if exists.
# @resource [https://stackoverflow.com/a/677212]
function exists() {
	echo `command -v "$1"`
}

# Checks if function exists.
#
# @param {string} 1) - Function name.
# @resource [https://stackoverflow.com/a/1007613]
function func_exists() {
	declare -F "$1" > /dev/null; echo $?
}

# Remove last line from terminal output.
#
# @return - Nothing is returned.
# @resource [https://stackoverflow.com/a/27326630]
function cline() {
	tput cuu 1 && tput el
}

# Print error message and exit.
#
# @param {string} 1) - Message to print.
# @return - Nothing is returned.
function err() {
	echo -e "${BRED}Error${NC}: $1" && exit
}

# Print success message.
#
# @param {string} 1) - Message to print.
# @return - Nothing is returned.
function success() {
	cline && echo -e " $CHECK_MARK $1" && sleep 0.1 && cline
}

# ANSI colors: [https://stackoverflow.com/a/5947802]
GREEN="\033[0;32m"
BOLD="\033[1m"
BRED="\033[1;31m"
BGREEN="\033[1;32m"
BBLUE="\033[1;34m"
BYELLOW="\033[1;33m"
BPURPLE="\033[1;35m"
NC="\033[0m"
ITC="\033[3m"

os=`platform`
# Unix timestamp in ms: [https://stackoverflow.com/a/21640976]
timestamp=$(perl -MTime::HiRes=time -e 'print int(time() * 1000);')
outputdirname=".nodecliac-src-$timestamp"
outputdir="$HOME/$outputdirname"
binfilepath="/usr/local/bin/nodecliac" # [https://unix.stackexchange.com/a/8664]
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
branch_name="master"
installer=""
rcfile=""
params=""
manual=""
yes=""
update=""
packages=""

sudo echo > /dev/null 2>&1 # Prompt password early.

while (( "$#" )); do
	case "$1" in
		--packages) packages=1; shift ;;
		--manual) manual=1; shift ;;
		--update) update=1; shift ;;
		--yes) yes=1; shift ;;

		--branch=*)
			flag="${1%%=*}"; value="${1#*=}"
			if [[ -n "$value" ]]; then branch_name="$value"; fi; shift ;;
		--branch)
			if [[ -n "$2" && "$2" != *"-" ]]; then branch_name="$2"; fi; shift ;;

		--installer=*)
			flag="${1%%=*}"; value="${1#*=}"
			if [[ -n "$value" ]]; then installer="$value"; fi; shift ;;
		--installer)
			if [[ -n "$2" && "$2" != *"-" ]]; then installer="$2"; fi; shift ;;

		--rcfile=*)
			flag="${1%%=*}"; value="${1#*=}"
			# Expand `~` in path: [https://stackoverflow.com/a/27485157]
			if [[ -n "$value" ]]; then rcfile="${value/#\~/$HOME}"; fi; shift ;;
		--rcfile)
			if [[ -n "$2" && "$2" != *"-" ]]; then rcfile="$2"; fi; shift ;;

		--) shift; break ;; # End argument parsing.
		-*|--*=) shift ;; # Unsupported flags.
		*) shift ;; # Preserve positional arguments.
	esac
done
[[ "$#" != 0 ]] && shift
eval set -- "$params"

repourl="https://api.github.com/repos/cgabriel5/nodecliac/tarball/$branch_name"
branchurl="https://api.github.com/repos/cgabriel5/nodecliac/branches/$branch_name"
gitbranch_https="https://github.com/cgabriel5/nodecliac.git"
gitbranch_ssh="git@github.com:cgabriel5/nodecliac.git"
branch_npm="https://github.com/cgabriel5/nodecliac/tarball/$branch_name"
branch_yarn="cgabriel5/nodecliac#$branch_name"

if [[ -z "$installer" ]]; then
	if [[ "$(exists yarn)" ]]; then installer="yarn"
	elif [[ "$(exists npm)" ]]; then installer="npm"
	else installer="binary"; fi
fi

# Create default rcfile if needed.
if [[ -n "$rcfile" && ! -f "$rcfile" || -z "$rcfile" ]]; then
	rcfile=~/.bashrc; [[ ! -f "$rcfile" ]] && touch "$rcfile"
fi
cp -a "$rcfile" "$HOME/.bashrc_ncliac.bk" # Backup rcfile.

# -------------------------------------------------------- LANGUAGE-REQUIREMENTS

[[ -z "$(exists perl)" ]] && err "Perl not installed."
perl_majorv="$(perl -ne 'print $1 if /\(v([^.]).*\)/' <<< $(perl --version))"
[[ "$((perl_majorv + 0))" -lt 5 ]] && err "Perl 5 is needed."

bversion="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
pcommand=$'print 1 if /^([4]\.([3-9]+|3)|([5-9]|\d{2,})\.\d{1,})/'
[[ ! "$(perl -ne "$pcommand" <<< "$bversion")" ]] && err "Bash 4.3+ is needed."

# ---------------------------------------------------------------BASH-COMPLETION

# [https://unix.stackexchange.com/a/62883]
# [https://stackoverflow.com/a/10574806]
bcpath="$(sudo find /usr -name bash_completion -print -quit -type f)"
[[ -z "$bcpath" ]] && err "bash-completion not installed."

# bcpath=/usr/share/bash-completion/bash_completion
# [[ ! -f "$bcpath" ]] && err "bash-completion not installed."
# pattern='/BASH_COMPLETION_VERSINFO=\((.*?)\)/'
# bcversion="$(perl -ne "$pattern"' && print($1) && exit' "$bcpath")"
# if [[ -z "$bcversion" ]]; then
# 	bcversion="$(perl -ne '/RELEASE:[ \t]*(.*?)$/ && print($1) && exit' "$bcpath")"
# 	[[ -z "$bcversion" ]] && err "bash-completion not installed."
# 	pattern='/^(2{1,}\.[1-9]{1,}|([3-9]{1,}|[1-9]{2,})\.[0-9]{1,}).*$/'
# 	[[ ! "$(perl -ne "$pattern"' && print(1) && exit' <<< "$bcversion")" ]] \
# 	&& err "bash-completion v2.1+ is needed."
# fi

# ----------------------------------------------------------------------- CHECKS

[[ " linux macosx " != *" $os "* ]] && err "Platform '$os' not supported."
[[ $# -gt 2 ]] && err -e "2 arguments are allowed: [installer, branch] but $# provided."
[[ " yarn npm binary " != *" $installer "* ]] && err \
"Invalid installer '$installer'. Allowed: 'yarn|npm|binary'"
case "$installer" in
	yarn|npm) [[ ! "$(exists $installer)" ]] && err "$installer not installed." ;;
esac

if [[ -z "$manual" ]]; then
	# Check branch exists: [https://stackoverflow.com/a/23916276]
	echo " - Verifying branch..."
	if [[ "$(exists wget)" ]]; then
		if [[ ! $(grep -F tree <<< $(wget -qO- "$branchurl")) ]]; then
			cline && err "Branch '$branch_name' doesn't exist."
		fi
	elif [[ "$(exists curl)" ]]; then
		if [[ ! $(grep -F tree <<< $(curl -Ls "$branchurl")) ]]; then
			cline && err "Branch '$branch_name' doesn't exist."
		fi
	fi
	success "Verified branch."
fi

# ------------------------------------------------------------------- NPM-CHECKS

if [[ "$installer" != "binary" ]]; then
	hash -r # Rebuild $PATH: [https://unix.stackexchange.com/a/5610]

	# Ensure NPM is properly configured/setup.
	if [[ "$installer" == "npm" ]]; then
		configstore=~/.config/configstore
		echo " - Checking local config store..."
		[[ ! -d "$configstore" ]] && cline && err "$configstore doesn't exist."
		success "Local config store exists."

		# ~/.config/configstore must be owned by the user.
		# [https://unix.stackexchange.com/a/7733]
		echo " - Checking local config store ownership..."
		if [[ $(ls -ld "$configstore" | awk '{print $3}') != "$USER" ]]; then
			cline && err "Change local config store ownership."
			echo -e "Run: ${BOLD}sudo chown -R \$USER:\$(id -gn \$USER) $configstore${NC}"
		fi
		success "Proper config store ownership."
	fi
fi

# ----------------------------------------------------------- REMOVE-OLD-INSTALL

# If updating, skip following blocks.
if [[ -z "$update" ]]; then
	# If ~/.nodecliac exists back it up.
	if [[ -e ~/.nodecliac ]]; then
		echo " - Backing up old ~/.nodecliac directory..."
		cp -a ~/.nodecliac "$HOME/.nodecliac.bak.$timestamp"
		success "Backed up old ~/.nodecliac directory."
	fi
	if [[ "$(exists nodecliac)" ]]; then
		echo " - Running 'nodecliac uninstall'..."
		nodecliac uninstall > /dev/null 2>&1
		success "Ran 'nodecliac uninstall'."
	fi
fi

if [[ "$(exists yarn)" ]]; then
	echo " - Checking for yarn global nodecliac install..."
	if [[ -n "$(yarn global list | grep -F "nodecliac@")" ]]; then
		cline && echo " - Removing global nodecliac from yarn..."
		yarn global remove nodecliac > /dev/null 2>&1
		success "Removed global yarn nodecliac install."
	else
		success "No global yarn nodecliac install to remove."
	fi
fi
if [[ "$(exists npm)" ]]; then
	echo " - Checking for npm global nodecliac install..."
	if [[ -n "$(npm list -g --depth=0 | grep -F "nodecliac@")" ]]; then
		cline && echo " - Removing global nodecliac from npm..."
		sudo npm uninstall -g nodecliac > /dev/null 2>&1
		success "Removed global npm nodecliac install."
	else
		success "No global npm nodecliac install to remove."
	fi
fi

# -------------------------------------------------------------- INSTALLER-LOGIC

if [[ " binary manual " == *" $installer "* ]]; then
	if [[ -z "$manual" ]]; then
		uhdir="${HOME/#$HOME/\~}" # Un-expand tilde:

		# Clone repo (wget > curl > git).
		usewget="$(exists wget)"
		usecurl="$(exists curl)"
		if [[ -n "$usewget$usecurl" ]]; then
			echo " - Downloading repository..."
			tarname="$HOME/$outputdirname.tar.gz"
			if [[ -n "$usewget" ]]; then wget -q -c "$repourl" -O "$tarname"
			else curl -Ls "$repourl" -o "$tarname"; fi
			success "Downloaded repository."
			echo " - Extracting repository..."
			tar -xzf "$tarname" -C ~/
			success "Extracted repository."
			echo " - Moving repository to '$uhdir'..."
			rm -rf "$outputdir"/* && mv -f ~/cgabriel5-nodecliac-* "$outputdir"
			success "Moved repository to '$uhdir'."
		elif [[ "$(exists git)" ]]; then
			echo " - Downloading repository..."
			git clone -q -b "$branch_name" --single-branch "$gitbranch_https" "$outputdir"
			# git clone -q -b "$branch_name" --single-branch "$gitbranch_ssh" "$outputdir"
			success "Downloaded repository."
		fi
	else
		# Get path of current script. [https://stackoverflow.com/a/246128]
		__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
		outputdir="$__filepath"
	fi

	# Copy relevant/platform specific files.
	echo " - Setting up ~/.nodecliac..."
	dest="$HOME/.nodecliac/src"
	acpath="$outputdir/src/scripts/ac"
	mainpath="$outputdir/src/scripts/main"
	binpath="$outputdir/src/scripts/bin"
	testspath="$outputdir/tests"
	mkdir -p ~/.nodecliac/{registry,src}
	mkdir -p "$dest"/{bin,main}
	mkdir -p "$dest"/ac/utils
	cp -pr "$acpath"/{ac,ac_debug}.pl "$dest/ac"
	cp -pr "$acpath"/utils/LCP.pm "$dest/ac/utils"
	cp -pr "$mainpath"/init.sh "$dest/main"
	cp -pr "$mainpath"/config.pl "$dest/main"
	cp -pr "$testspath"/scripts/nodecliac.sh "$dest/main/test.sh"
	cp -pr "$binpath"/binary.sh "$dest/bin"
	[[ -n "$packages" ]] && cp -pr "$outputdir"/resources/packages/* ~/.nodecliac/registry
	[[ -z "$packages" ]] && cp -pr "$outputdir"/resources/packages/nodecliac ~/.nodecliac/registry
	nimbin="$outputdir/src/parser/nim/nodecliac.$os"
	[[ -e "$nimbin" ]] && cp -pr "$nimbin" "$dest/bin"
	acbin="$binpath/ac.$os"; [[ -e "$acbin" ]] && cp -pr "$acbin" "$dest/bin"
	dacbin="$binpath/ac_debug.$os"; [[ -e "$dacbin" ]] && cp -pr "$dacbin" "$dest/bin"

	version="$(perl -ne 'print $1 if /"version":\s*"([^"]+)/' "$outputdir/package.json")"
	echo "{ \"force\": false, \"rcfile\": \"$rcfile\", \"time\": \"$timestamp\", \"binary\": true, \"version\": \"$version\" }" > ~/.nodecliac/.setup.db.json

	# Strip comments/empty lines.
	# [http://isunix.github.io/blog/2014/07/24/perl-one-liner-to-remove-blank-lines/].
	# [https://stackoverflow.com/a/6995010], [https://unix.stackexchange.com/a/179449]
	perl -pi -e 's/^\s*#(?!!).*?$//g;s/\s{1,}#\s{1,}.+$//g;s!^\s+?$!!' ~/.nodecliac/src/**/*.{sh,pl}
	sudo chmod +x ~/.nodecliac/src/**/*.{sh,pl}

	success "Setup ~/.nodecliac."

	if [[ -z "$(grep -F "ncliac=~/.nodecliac/src/main/init.sh" "$rcfile")" ]]; then
		answer=""
		modrcfile=""
		if [[ -z "$yes" ]]; then
			# Ask user whether to add nodecliac to rcfile.
			echo -e "${BPURPLE}Prompt${NC}: For nodecliac to work it needs to be added to your rcfile."
			echo -e "    ... The following line will be appended to ${BOLD}${rcfile/#$HOME/\~}${NC}:"
			echo -e "    ... ${ITC}ncliac=~/.nodecliac/src/main/init.sh; [ -f \"\$ncliac\" ] && . \"\$ncliac\";${NC}"
			echo -e "    ... (if skipping, manually add it after install to use nodecliac)"
			echo -e -n "${BPURPLE}Answer${NC}: [Press enter for default: Yes] ${BOLD}Add nodecliac to rcfile?${NC} [Y/n] "
			read answer # [https://unix.stackexchange.com/a/165100]
			case "$answer" in
				[Yy]*) modrcfile=1; ;;
				*) modrcfile=0 ;;
			esac
			for i in {1..5}; do cline; done # Remove question/answer lines.
		fi
		[[ -z "$answer" || "$yes" == 1 ]] && modrcfile=1

		# Add nodecliac to rcfile.
		if [[ "$modrcfile" == 1 ]]; then
			echo " - Adding nodecliac to $rcfile..."
			perl -i -lpe 's/\x0a$//' "$rcfile" # Ensure newline.
			echo 'ncliac=~/.nodecliac/src/main/init.sh; [ -f "$ncliac" ] && . "$ncliac";' >> "$rcfile"
			perl -i -lpe 's/\x0a$//' "$rcfile" # Ensure newline.
			success "Added nodecliac to $rcfile."
			# [https://www.unix.com/shell-programming-and-scripting/229399-how-add-newline-character-end-file.html]
			# [https://knowledge.ni.com/KnowledgeArticleDetails?id=kA00Z0000019KZDSA2]
			# [https://stackoverflow.com/a/9021745]
		fi
	fi

	# # Modify nodecliac.acdef for binary.
	# # Remove all but the following commands.
	# allowed_commands="add|remove|link|unlink|enable|disable|print|status|registry|uninstall"
	# perl -i -lne 'if (/^(#|\.('"$allowed_commands"') --| )/) { if ($1 eq " ") { print "\n --"} elsif ($1 eq ".uninstall --") { print "$1" } else { print } }' ~/.nodecliac/registry/nodecliac/nodecliac.acdef
	# # Add back '--version'.
	# perl -p -i -e 's/^ \-\-/ \-\-version?/m if /^ /' ~/.nodecliac/registry/nodecliac/nodecliac.acdef

	echo " - Creating $binfilepath..."
	sudo cp -p "$outputdir/src/scripts/bin/binary.sh" "$binfilepath"
	sudo chmod +x "$binfilepath"
	success "Created $binfilepath."

	if [[ -z "$manual" ]]; then
		echo " - Cleaning up..."
		rm -rf "$HOME/.nodecliac-src-"*
		success "Cleanup completed."
	fi
else
	hash -r # Rebuild $PATH: [https://unix.stackexchange.com/a/5610]

	if [[ "$installer" == "npm" ]]; then
		echo " - Installing nodecliac via npm..."
		# Global installs can't install shorthand branch method:
		# [https://stackoverflow.com/a/32436218]
		# sudo npm i -g "cgabriel5/nodecliac#$branch_name" > /dev/null 2>&1
		sudo "$(exists npm)" i -g --quiet --no-progress "$branch_npm" > /dev/null 2>&1
		success "Installed nodecliac via npm."
	elif [[ "$installer" == "yarn" ]]; then
		echo " - Installing nodecliac via yarn..."
		yarn global add "$branch_yarn" > /dev/null 2>&1
		success "Installed nodecliac via yarn."
	fi

	nodecliac setup --jsInstall # > /dev/null 2>&1
	# echo " - Setting up nodecliac..."
	# success "Setup nodecliac."
fi

# Use \033 rather than \e: [https://stackoverflow.com/a/37366139]
if [[ "$(exists nodecliac)" ]]; then
	echo -e "${BGREEN}Success${NC}: nodecliac installed in ~/.nodecliac"

	if [[ -z "$(grep -F "ncliac=~/.nodecliac/src/main/init.sh" "$rcfile")" ]]; then
		echo -e "   ${BYELLOW}Note${NC}: nodecliac wasn't added to rcfile (${rcfile/#$HOME/\~}) but is necessary to use it."
		echo -e "     ... Add it and reload your rcfile by running the following commands:"
		echo -e "     ... $ ${BOLD}echo${NC} 'ncliac=~/.nodecliac/src/main/init.sh; [ -f \"\$ncliac\" ] && . \"\$ncliac\";' >> ${rcfile/#$HOME/\~} && ${BOLD}source${NC} ${rcfile/#$HOME/\~}"
	else
		echo -e "${BGREEN}Success${NC}: nodecliac added to ${rcfile/#$HOME/\~}"
		echo -e "    ${BBLUE}Tip${NC}: Reload rcfile before using by running:"
		echo -e "     ... $ ${BOLD}source${NC} ${rcfile/#$HOME/\~}${NC}"
	fi
fi
}

_ "$@"
