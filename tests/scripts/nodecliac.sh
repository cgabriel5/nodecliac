#!/bin/bash

# Script tests both ac.pl and ac.nim auto-completion scripts against
# pre-prepared completion statements.

# ---------------------------------------------------------------- CLI-ARGUMENTS

PRINT=""
FORCE=""
OVERRIDE=""
TIMEFORMAT=%R # [https://stackoverflow.com/a/3795634]

# Get cache level.
CACHE=0
cachepath="$HOME/.nodecliac/.cache-level"
[[ -f "$cachepath" ]] && CACHE=$(<"$cachepath")
TESTS=""

OPTIND=1 # Reset variable: [https://unix.stackexchange.com/a/233737]
while getopts 't:p:f:o:' flag; do # [https://stackoverflow.com/a/18003735]
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
			esac ;;
		t) [[ -n "$OPTARG" ]] && TESTS="$OPTARG" ;;
	esac
done
shift $((OPTIND - 1))

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# ---------------------------------------------------------------------- IMPORTS

[[ -z "$TESTS" ]] && echo -e "[\033[1;31mError\033[0m] Test file not provided." && exit 1
[[ ! -f "$TESTS" ]] && echo -e "[\033[1;31mError\033[0m] Test file \033[1m$TESTS\033[0m not found." && exit 1

. "$TESTS" # [https://stackoverflow.com/a/12694189]

# Note: Because the script will be copied over to ~/.nodecliac,
# explicitly import the necessary functions/variables.
# . "$__filepath/common.sh"

# If provided value is not empty return 1, else return "".
# Note: o is not returned because it is considered true by Bash so 
# "" is returned instead: [https://stackoverflow.com/a/3924230]
# [https://stackoverflow.com/a/3601734]
isset() {
	echo $([[ -n "$1" ]] && echo 1 || echo "")
}
# If provided value is empty return 1, else return "".
# Note: o is not returned because it is considered true by Bash so 
# "" is returned instead: [https://stackoverflow.com/a/3924230]
notset() {
	echo $([[ -z "$1" ]] && echo 1 || echo "")
}

# [https://www.utf8-chartable.de/unicode-utf8-table.pl?start=9984&number=128&names=-&utf8=string-literal]
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
X_MARK="\033[0;31m\xe2\x9c\x98\033[0m"

# ------------------------------------------------------------------------- VARS

# [https://www.thegeekstuff.com/2010/06/bash-array-tutorial/]
declare -a scripts=()
perlscript_path=~/.nodecliac/src/ac/ac.pl # The Perl ac script path.

# Detect which nodecliac ac script is being used (bin or Perl script).
acpl_script=""
if [[ $(isset "$OVERRIDE") ]]; then
	if [[ "$OVERRIDE" == "nim" ]]; then
		acpl_script=~/.nodecliac/src/bin/ac."$(e=$(uname);e=${e,,};echo "${e/darwin/macosx}")"
	else
		acpl_script="$perlscript_path"
	fi
	
	scripts=("$acpl_script")
else
	acpl_script=~/.nodecliac/src/bin/ac."$(e=$(uname);e=${e,,};echo "${e/darwin/macosx}")"
	# acpl_script=~/.nodecliac/src/bin/ac."$(e=$(uname);e=${e,,};echo $e)"
	# acpl_script="${acpl_script/darwin/macosx}"
	#"$(perl -ne 'print $1 if /acpl_script=.*\/(ac.*)$/' <<< "$(<~/.nodecliac/src/ac.sh)")"
	# Fallback to Perl script if Nim os binary is not supported.
	if [[ ! -e "$acpl_script"  ]]; then
		acpl_script="$perlscript_path"
		scripts=("$acpl_script")
	else
		scripts=("$perlscript_path" "$acpl_script")
	fi
fi

skipped=0
test_id=0
passed_count=0
test_count="${#tests[@]}"
test_columns="${#test_count}"

# Note: If nodecliac is not installed tests cannot run so exit with message.
if [[ $(notset "$(command -v nodecliac)") ]]; then
	if [[ $(isset "$PRINT") ]]; then # Print header.
		echo -e "\033[1m[Testing Completions]\033[0m [script=, override=$OVERRIDE, cache=\033[1;32m$CACHE\033[0m]"
		echo -e " $X_MARK [skipped] \033[1;36mnodecliac\033[0m is not installed.\n"
	fi
	exit 0
fi

# To run tests there needs to be modified src/ files or force flag.
if [[ $(notset "$FORCE") && "$(git diff --name-only --cached)" != *"src/"* ]]; then
	if [[ $(isset "$PRINT") ]]; then
		echo -e "\033[1m[Testing Completions]\033[0m [script=, override=$OVERRIDE, cache=\033[1;32m$CACHE\033[0m]"
		echo -e " $CHECK_MARK [skipped] No staged \033[1;34msrc/\033[0m files.\n"
	fi
	
	[[ $(notset "$FORCE") ]] && exit 0 # Exit if not forced.
fi

# -------------------------------------------------------------------- FUNCTIONS

function _nodecliac() {
	local command="$1"
	local root=~/.nodecliac
	local cstring
	local config="$root/.config"
	read -n 4 cstring < "$config"

	local sum=""
	local output=""
	local cline="$2"
	local cpoint="$3"
	local acdefpath="$root"/registry/"$command/$command.acdef"
	local prehook="$root"/registry/"$command"/hooks/pre-parse.sh
	local cache="${cstring:1:1}"
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
			read c < <(date +"%s")
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
		[[ -e "$prehook" ]] && . "$prehook"

		local acdef=$(<"$acdefpath")
		# shopt -s nullglob # [https://stackoverflow.com/a/7702334]
		local posthook="" # [https://stackoverflow.com/a/23423835]
		posthooks=("$root/registry/$command/hooks/post-hook."*)
		phscript="${posthooks[0]}"
		[[ -n "$phscript" && -x "$phscript" ]] && posthook="$phscript"
		# Unset to allow bash-completion to continue to work properly.
		# shopt -u nullglob # [https://unix.stackexchange.com/a/434213]

		output=$(TESTMODE=1 "$acpl_script" "$2" "$cline" "$cpoint" "$command" "$acdef" "$posthook" "$singletons")
	fi

	# 1st line is meta info (completion type, last word, etc.).
	# [https://stackoverflow.com/a/2440685]
	read -r firstline <<< "$output"
	local meta="${firstline%%+*}"
	local type="${meta%%:*}"
	local cacheopt=1; [[ "$type" == *"nocache"* ]] && cacheopt=0

	if [[ "$cache" != 0 && "$usecache" == 0 ]]; then
		[[ "$cacheopt" == 0 && "$cache" == 1 ]] && sum="x$sum"
		echo "$output" > "$root"/.cache/"$sum"
	fi

	echo "$output"
}

# Run nodecliac against provided test/mock CLI input.
#
# @param {string} - The test CLI input.
function xnodecliac {
	local oinput="$1"
	local cline=$([[ -n "$2" ]] && echo "$2" || echo "$1")
	local cpoint="$3"
	local maincommand=${1%% *}

	# Run nodecliac and return output.
	# [https://unix.stackexchange.com/a/12069]
	# [https://stackoverflow.com/a/4617688]
	# [https://stackoverflow.com/a/2409214]
	echo "$( { time _nodecliac "$maincommand" "$cline" "$cpoint"; } 2>&1 )"
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

# Tests answer against output using provided logic type.
#
# @param {string} 1) - The output to test against.
# @param {string} 2) - The answer to test output against.
# @return {number} - 1 is test passed. Otherwise, 0.
#
# @resource [https://stackoverflow.com/a/3352015]
function xlogic() {
	local output="$(echo -e "$1")"
	local answer="$(echo -e "$2")"
	local type="$3"
	case $type in
		contains) [[ "$output" == *"$answer"* ]] && echo 1 || echo 0 ;;
		endsWith) [[ "$output" == *"$answer" ]] && echo 1 || echo 0 ;;
		startsWith) [[ "$output" == "$answer"* ]] && echo 1 || echo 0 ;;
		*) [[ "$(trim "$output")" == "$answer" ]] && echo 1 || echo 0 ;;
	esac
}

# Main test function.
#
# @param {string} 1) - The test to run.
# @param {string} 2) - The test input.
# @param {string} 3) - The answer's test.
function xtest {
	local string="$1"
	local del=";"
	local tests=()
	local results=()
	local teststring=""
	local teststring_og=""
	local suite_status=""

	# [https://stackoverflow.com/a/37270949]
	# [https://unix.stackexchange.com/a/393562]
	# [https://stackoverflow.com/a/52445886]
	while IFS= read -r line; do
		item="$line"
		local cpoint=""

		# Skip over empty lines.
		[[ -z "$(trim "$item")" ]] && continue

		if [[ -z "$teststring" ]]; then
			teststring="$item"
			local ts="${teststring%%|*}"
			cpoint="${#ts}"
			# Remove | from test string.
			teststring_og="${teststring/\|/\\033[1;34m\|\\033[0m\\033[2m}"
			teststring="${teststring/\|/}"

			output="$(xnodecliac "$teststring" "$teststring" "$cpoint")"
			# [https://stackoverflow.com/a/43231384]
			# timeres=$(echo "${output##*$'\n'}")
			t=${output: -5} # [https://stackoverflow.com/a/19858692]
			output=${output::-5} # [https://stackoverflow.com/a/27658733]

			# [https://stackoverflow.com/a/43231038]
			# lines=$(echo "$output" | wc -l)
			# output="$(echo "$output" | head -n $(($lines -1)))"

			micros="${t:3:1}"
			case $micros in
			  0) t="\033[0;39m$t\033[0m" ;;
			  1) t="\033[0;33m$t\033[0m" ;;
			  *) t="\033[0;31m$t\033[0m" ;;
			esac

			((test_id++))
			tid="$test_id"
			tlen="${#test_id}"
			[[ $tlen == 1 ]] && tid="$tid"

			continue
		fi

		# local rtrim=0
		# local ltrim=0
		local cindex=""
		local invert=0
		local tlogic="match"

		# Check if index position is provided.
		if [[ "$item" == *([^\\])":"* ]]; then
			meta="${item%%:*}"
			item="${item#*:}"
			
			# Get index, left, right string information.
			# [[ "$meta" == *"<"* ]] && ltrim=1
			# [[ "$meta" == *">"* ]] && rtrim=1
			[[ "$meta" =~ [0-9] ]] && cindex="${meta//[!0-9]/}"
			[[ "$meta" == *"*"* ]] && cindex="*"
		fi

		local r=0
		item="$(perl -pe 's/([\\])(;|:)/\2/g' <<< "$(trim "$item")")"
		tests+=("$item")

		# Check if result needs to be inverted.
		[[ "$item" == "!"* ]] && invert=1 && item="${item:1}" # Remove '!'.

		# Determine logic check type.
		if [[ "$item" =~ ^\* && "$item" =~ \*$ ]]; then
			tlogic="contains"
			item=${item:1:-1}
		elif [[ "$item" =~ ^\* ]]; then 
			tlogic="endsWith"
			item=${item:1}
		elif [[ "$item" =~ \*$ ]]; then 
			tlogic="startsWith"
			item=${item::1}
		fi

		if [[ "$item" == "#"* ]]; then
			op="${item:2:2}"
			n="${item:4:${#item}}"
			readarray -t completions <<< "$(trim "$output")"
			c="${#completions[@]}"
			case "$op" in
				eq) r=$([ "$c" == "$n" ] && echo 1 || echo 0) ;;
				ne) r=$([ "$c" != "$n" ] && echo 1 || echo 0) ;;
				gt) r=$([ "$c" >  "$n" ] && echo 1 || echo 0) ;;
				ge) r=$([ "$c" >= "$n" ] && echo 1 || echo 0) ;;
				lt) r=$([ "$c" <  "$n" ] && echo 1 || echo 0) ;;
				le) r=$([ "$c" <= "$n" ] && echo 1 || echo 0) ;;
			esac
		else
			if [[ -n "$cindex" ]]; then
				readarray -t completions <<< "$(trim "$output")"
				if [[ "$cindex" == "*" ]]; then
					for completion in "${completions[@]}"; do
						r="$(xlogic "$completion" "$item" "$tlogic")"
						[[ "$r" == 1 ]] && break
					done
				else
					completion="${completions[$cindex]}"
					if [[ -n "$completion" ]]; then
						r="$(xlogic "$completion" "$item" "$tlogic")"
					fi
				fi
			else
				r="$(xlogic "$output" "$item" "$tlogic")"
			fi
		fi
		
		# Invert if needed.
		[[ "$invert" == 1 ]] &&  r=$([ "$r" == 1 ] && echo 0 || echo 1)
		# Determine overall test suite status.
		[[ "$suite_status" != 0 && "$r" == 1 ]] && suite_status=1
		[[ "$r" == 0 ]] && suite_status=0
		
		results+=("$r")
	done < <(perl -pe 's/([^\\]);/\1\n/g' <<< "$string")
	
	if [[ "${#tests[@]}" == 0 ]]; then
		((test_id--))
		((skipped++))
		if [[ $(isset "$PRINT") ]]; then
			echo -e "(-) \033[1mIgnored (No Tests)\033[0m\n    [?] [$teststring_og\\033[0m] (${t}s)"
			echo -e "    \033[1;35mOutput\033[0m"
			readarray -t completions <<< "$(trim "$output")"
			l="${#completions[@]}"
			for ((i = 0 ; i < $l ; i++)); do
				c="${completions[$i]}"
				echo -e "    [$i] => [$c]"
			done
		fi
	else
		if [[ "$suite_status" == 1 ]]; then
			if [[ $(isset "$PRINT") ]]; then
				tidl="${#tid}"
				diff=$(( test_columns - tidl ))
				padding="" # [https://stackoverflow.com/a/5349842]
				[[ "$diff" > 0 ]] && padding="$(printf ' %.0s' $(seq 1 $diff))"
				echo -e "${tid}${padding} $CHECK_MARK ${t}s [$teststring_og\\033[0m]"
			fi
			((passed_count++))
		else
			if [[ $(isset "$PRINT") ]]; then
				tidl="${#tid}"
				diff=$(( test_columns - tidl ))
				padding="" # [https://stackoverflow.com/a/5349842]
				[[ "$diff" > 0 ]] && padding="$(printf ' %.0s' $(seq 1 $diff))"
				echo ""
				echo -e "${tid}${padding} \033[1;31mFailing\033[0m\n    [$X_MARK] (${t}s) TS=[$teststring_og\\033[0m]"

				l="${#tests[@]}"
				for ((i = 0 ; i < $l ; i++)); do
					r="${results[$i]}"
					t="$(perl -pe 's/([\\])(;|:)/\2/g' <<< "$(trim "${tests[$i]}")")"
					if [[ "$r" == 1 ]]; then
						echo -e "    [$CHECK_MARK] [\033[1;36m${tlogic^^}\033[0m] —> [$t]"
					else
						echo -e "    [$X_MARK] [\033[1;36m${tlogic^^}\033[0m] -- [$t]"
					fi
				done
				
				echo -e "    \033[1;35mOutput\033[0m"
				readarray -t completions <<< "$(trim "$output")"
				l="${#completions[@]}"
				for ((i = 0 ; i < $l ; i++)); do
					c="${completions[$i]}"
					echo -e "    [$i] => [$c]"
				done
				echo ""
			fi
		fi
	fi
}

# ------------------------------------------------------------------------ TESTS

# Note: When `OVERRIDE` is present then we only test that
# specificity script once. Else we test both the Nim and Perl scripts.
for script in "${scripts[@]}"; do # [https://linuxconfig.org/how-to-use-arrays-in-bash-script]
	acpl_script="$script" # Reset variable.

	# Print header.
	if [[ $(isset "$PRINT") ]]; then
		echo -e "\033[1m[Testing Completions]\033[0m [script=\033[1;32m$(basename -- "$script")\033[0m, override=$OVERRIDE, cache=\033[1;32m$CACHE\033[0m]"
	fi
	for test in "${tests[@]}"; do xtest "$test"; done

	[[ $(isset "$PRINT") ]] && echo "" # Pad output.
	test_id=0
done

# r="$(xnodecliac "")"
# echo ">$r<"

# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
if [[ $(isset "$PRINT") ]]; then
	# Perl round number: [https://stackoverflow.com/a/178576]
	test_count=$(( (2*test_count) - skipped ))
	percent=$(perl -e "printf \"%.2f\", $passed_count/$test_count*100" 2> /dev/null)
	[[ -z "$percent" ]] && percent=0
	echo -e " \033[1;34mResult\033[0m: $passed_count/$test_count — (coverage: \033[1m$percent%\033[0m)"
fi

[[ $(isset "$PRINT") ]] && echo "" # Pad output.

# Set exit code. If all tests pass then set to 0.
# [https://shapeshed.com/unix-exit-codes/]
[[ "$passed_count" == "$test_count" ]] && exit 0 || exit 1
