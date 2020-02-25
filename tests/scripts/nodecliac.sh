#!/bin/bash

# Script tests both ac.pl and ac.nim auto-completion scripts against
# pre-prepared completion statements.

# -----------------------------------------------------------------CLI-ARGUMENTS

PRINT=""
FORCE=""
OVERRIDE=""

OPTIND=1 # Reset variable: [https://unix.stackexchange.com/a/233737]
while getopts 'p:f:o:' flag; do # [https://stackoverflow.com/a/18003735]
	case "$flag" in
		p)
			case "$OPTARG" in
				true) PRINT="$OPTARG" ;;
				false) PRINT="" ;;
				*) PRINT="true" ;;
			esac ;;
		f)
			case "$OPTARG" in
				true) FORCE="$OPTARG" ;;
				*) FORCE="" ;;
			esac ;;
		o)
			case "$OPTARG" in
				nim | pl) OVERRIDE="$OPTARG" ;;
				*) OVERRIDE="" ;;
			esac
	esac
done
shift $((OPTIND - 1))

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# -----------------------------------------------------------------------IMPORTS

. "$__filepath/common.sh" # Import functions/variables.

# --------------------------------------------------------------------------VARS

# [https://www.thegeekstuff.com/2010/06/bash-array-tutorial/]
declare -a scripts=() # Create scripts array.
perlscript_path=~/.nodecliac/src/ac/ac.pl # The Perl ac script path.

# Detect which nodecliac ac script is being used (bin or Perl script).
acpl_script=""
if [[ $(isset "$OVERRIDE") ]]; then
	if [[ "$OVERRIDE" == "nim" ]]; then
		acpl_script=~/.nodecliac/src/bin/ac."$(e=$(uname);e=${e,,};echo ${e/darwin/macosx})"
	else
		acpl_script="$perlscript_path"
	fi
	
	scripts=("$acpl_script") # Add script to array.
else
	acpl_script=~/.nodecliac/src/bin/ac."$(e=$(uname);e=${e,,};echo ${e/darwin/macosx})"
	# acpl_script=~/.nodecliac/src/bin/ac."$(e=$(uname);e=${e,,};echo $e)"
	# acpl_script="${acpl_script/darwin/macosx}"
	#"$(perl -ne 'print $1 if /acpl_script=.*\/(ac.*)$/' <<< "$(<~/.nodecliac/src/ac.sh)")"
	# Fallback to Perl script if Nim os binary is not supported.
	if [[ ! -e "$acpl_script"  ]]; then
		acpl_script="$perlscript_path"
		scripts=("$acpl_script") # Add script to array.
	else
		# Add script to array.
		scripts=("$perlscript_path" "$acpl_script")
	fi
fi

test_count=0
passed_count=0

# Note: If nodecliac is not installed tests cannot run so exit with message.
if [[ $(notset "$(command -v nodecliac)") ]]; then
	if [[ $(isset "$PRINT") ]]; then # Print header.
		echo -e "\033[1m[Testing Completion Script]\033[0m [script=, override=$OVERRIDE]"
		echo -e " $X_MARK [skipped] \033[1;36mnodecliac\033[0m is not installed.\n"
	fi
	exit 0
fi

# To run tests there needs to be modified src/ files or force flag.
if [[ "$STAGED_FILES" != *"src/"* && $(notset "$FORCE") ]]; then
	if [[ $(isset "$PRINT") ]]; then
		echo -e "\033[1m[Testing Completion Script]\033[0m [script=, override=$OVERRIDE]"
		echo -e " $CHECK_MARK [skipped] No staged \033[1;34msrc/\033[0m files.\n"
	fi
	
	if [[ $(notset "$FORCE") ]]; then exit 0; fi # Exit if not forced.
fi

# ---------------------------------------------------------------------FUNCTIONS

# Run nodecliac against provided test/mock CLI input.
#
# @param {string} - The test CLI input.
function xnodecliac {
	# Get arguments.
	local oinput="$1"
	local cline=$([[ -n "$2" ]] && echo "$2" || echo "$1")
	local cpoint=$([[ -n "$3" ]] && echo "$3" || echo "${#oinput}")
	# local cpoint=${#oinput}
	local maincommand=${1%% *}
	local acdef="$(<~/.nodecliac/registry/$maincommand/$maincommand.acdef)"

	# Run nodecliac and return output.
	local res="$("$acpl_script" "$oinput" "$cline" "$cpoint" "$maincommand" "$acdef")"
	# time "$acpl_script" "$oinput" "$cline" "$cpoint" "$maincommand" "$acdef"
	echo "$res"
}

# Main test function.
#
# @param {string} 1) - The test to run.
# @param {string} 2) - The test input.
# @param {string} 2) - The answer's test.
function xtest {
	local testname="$1"
	local teststring="$2"
	local answer="$3"
	local cpoint="$4" # Explicit tab point.

	r="$(xtest_${testname} "$(xnodecliac "$teststring" "$teststring" "$cpoint")" "$answer")"

	((test_count++))

	if [[ "$r" == "1" ]]; then
		if [[ $(isset "$PRINT") ]]; then
			echo -e " $CHECK_MARK ${testname:0:1} '$teststring'"
		fi
		((passed_count++))
	else
		if [[ $(isset "$PRINT") ]]; then
			echo -e " $X_MARK ${testname:0:1} '$teststring'"
			# exit 1
		fi
	fi
}

# Test that provided answer is an exact match against nodecliac output.
#
# @param {string} 1) - The nodecliac output.
# @param {string} 2) - The answer to test against.
function xtest_matches {
	# Append trailing whitespace if third argument is provided.
	local answer="$(echo -e "$2")"
	local output="$(echo -e "$1")"

	# [https://stackoverflow.com/a/454549]
	# diff  <(echo -e "$output" ) <(echo -e "$answer")

	if [[ "$output" == "$answer" ]]; then echo 1; else echo 0; fi
}

# Test that provided answer is contains in nodecliac output.
#
# @param {string} 1) - The nodecliac output.
# @param {string} 2) - The answer to test against.
function xtest_contains {
	# Append trailing whitespace if third argument is provided.
	local answer="$(echo -e "$2")"
	local output="$(echo -e "$1")"

	if [[ "$output" == *"$answer"* ]]; then echo 1; else echo 0; fi
}

# Test that provided answer is not contained in nodecliac output.
#
# @param {string} 1) - The nodecliac output.
# @param {string} 2) - The answer to test against.
function xtest_omits {
	# Append trailing whitespace if third argument is provided.
	local answer="$(echo -e "$2")"
	local output="$(echo -e "$1")"

	if [[ "$output" == *"$answer"* ]]; then echo 0; else echo 1; fi
}

# -------------------------------------------------------------------------TESTS

# Note: When `OVERRIDE` is present then we only test that
# specificity script once. Else we test both the Nim and Perl scripts.
for script in "${scripts[@]}"; do # [https://linuxconfig.org/how-to-use-arrays-in-bash-script]
	acpl_script="$script" # Reset variable.

	# Print header.
	if [[ $(isset "$PRINT") ]]; then
		echo -e "\033[1m[Testing Completion Script]\033[0m [script=\033[1;32m$(basename -- $script)\033[0m, override=$OVERRIDE]"
	fi

	# [test-suite: nodecliac]
	xtest contains "nodecliac " "uninstall"
	# xtest contains "nodecliac --engine=" "1"
	xtest contains "nodecliac --engine=2 --" "--version "
	xtest contains "nodecliac print --command=" "subl"
	xtest contains "nodecliac print --command" "--command="
	xtest contains "nodecliac print --command=node" "nodecliac "
	xtest contains "nodecliac print --command node" "nodecliac "
	xtest contains "nodecliac print --comm" "--command"
	xtest contains "nodecliac make --sou path/to/file" "source" "20"
	xtest contains "nodecliac format --source command.acmap --print --indent \"s:2\" --" "strip-comments"

	# [test-suite: prettier-cli-watcher]
	xtest matches "prettier-cli-watcher " "command:"
	xtest contains "prettier-cli-watcher --watcher=" "hound"
	xtest omits "prettier-cli-watcher --watcher= --" "--watcher"
	xtest contains "prettier-cli-watcher --watcher=hou" "hound "
	xtest contains "prettier-cli-watcher --watcher=hound" "hound "
	xtest omits "prettier-cli-watcher --watcher=hound --" "--watcher"
	xtest matches "prettier-cli-watcher --watcher=hound --w" "flag:--w"
	# xtest omits "prettier-cli-watcher --watcher=hound --watcher " "chokidar"
	# xtest omits "prettier-cli-watcher --watcher=hound --watcher=" "chokidar"
	xtest matches "prettier-cli-watcher --watcher=hound --" "$(cat <<-END
	flag:--
	--configpath=
	--dir=
	--dtime=
	--extensions=
	--ignoredirs=
	--nolog 
	--nonotify 
	END
	)"
	xtest contains "prettier-cli-watcher --watcher hou" "hound "
	xtest contains "prettier-cli-watcher --watcher hound" "hound "
	xtest omits "prettier-cli-watcher --watcher hound --" "--watcher"
	xtest matches "prettier-cli-watcher --watcher hound --w" "flag:--w"
	xtest omits "prettier-cli-watcher --watcher hound --watcher " "chokidar"
	xtest matches "prettier-cli-watcher --watcher hound --watcher" "flag:--watcher"
	xtest omits "prettier-cli-watcher --watcher=hound --watcher=" "chokidar"
	xtest omits "prettier-cli-watcher --watcher=hound --watcher" "chokidar"
	xtest omits "prettier-cli-watcher --watcher=hound --watcher chok" "chokidar"

	# [test-suite: yarn]
	xtest matches "yarn remov " "command:" # `remov` command does not exit.
	xtest contains "yarn " "config"
	xtest contains "yarn run " "pretty"
	xtest contains "yarn remove " "prettier"
	# Completing a non existing argument should not append a trailing space.
	xtest matches "yarn remove nonexistantarg" "command:nonexistantarg"
	xtest contains "yarn add prettier-cli-watcher@* --" "--dev"

	# [test-suite: nim]
	xtest contains "nim compile --" "--hint..." # Test flag collapsing.
	xtest contains "nim compile --app=con" "console"
	xtest contains "nim compile --app:con" "console"

	if [[ $(isset "$PRINT") ]]; then echo ""; fi # Pad output.
done

# r="$(xnodecliac "")"
# echo ">$r<"

# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
if [[ $(isset "$PRINT") ]]; then
	# Perl round number: [https://stackoverflow.com/a/178576]
	percent=$(perl -e "printf \"%.2f\", $passed_count/$test_count*100")
	echo -e " \033[1;34mResult\033[0m: $passed_count/$test_count — (coverage: \033[1m$percent%\033[0m)"
fi

if [[ $(isset "$PRINT") ]]; then echo ""; fi # Pad output.

# Set exist code. If all tests pass then set to 0.
# [https://shapeshed.com/unix-exit-codes/]
if [[ "$passed_count" == "$test_count" ]]; then exit 0; else exit 1; fi
