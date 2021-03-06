#!/bin/bash

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

# Script checks whether `nodecliac make` returns same output. If so
# the parser is working properly.

# ---------------------------------------------------------------------- IMPORTS

. "$__filepath/common.sh"

# ------------------------------------------------------------------------- VARS

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

TESTDIR=$(chipdir "$__filepath" 1) # The tests script's path.
NIM_BIN="$(chipdir "$__filepath" 2)/src/parser/nim/nodecliac.$(platform)"

output_path="outputs/$OUTPUT_DIR"
mkdir -p "$TESTDIR/$output_path"

files_count=0
passed_count=0

# ------------------------------------------------------------------------- TEST

# Print header.
if [[ $(isset "$PRINT") ]]; then echo -e "${BOLD}[Testing $HEADER]${NC}"; fi

# To run tests there needs to be modified src/ files or force flag.
if [[ "$(git diff --name-only --cached)" != *"src/"* && $(notset "$FORCE") ]]; then
	if [[ $(isset "$PRINT") ]]; then
		echo -e " $CHECK_MARK [skipped] No staged ${BBLUE}src/${NC} files.\n"
	fi

	if [[ $(notset "$FORCE") ]]; then exit 0; fi # Exit if not forced.
fi

# Delete existing log files.
logpath="$TESTDIR/$output_path/logs"
if [[ -e "$logpath" ]]; then rm -rf "$logpath"; fi

decor="==============="

for f in "$TESTDIR"/acmaps/*.acmap; do
	((files_count++))

	forg="$f"
	output=""
	log=""
	# Run with `--test` flag to prevent printing headers/meta information.
	if [[ "$ACTION" == "parse" ]]; then
		output_js="$(nodecliac make --source "$f" --test)"
		if [[ "$output_js" == "["* ]]; then
			# Remove colors from output: [https://stackoverflow.com/a/54648447]
			output_js="$(echo "$output_js" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')"
		fi
		output_nim="$("$NIM_BIN" make --source "$f" --test)"
		if [[ "$output_nim" == "["* ]]; then
			output_nim="$(echo "$output_nim" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')"
		fi
		if [[ "$output_js" == "$output_nim" ]]; then
			output="$output_js"
		else
			log="true"
			output=" -:- parsing -:-\n\n"
			output+="# $decor <JS $decor\n"
			output+="$output_js"
			output+="\n#\n\n"
			output+="# $decor >Nim $decor\n"
			output+="$output_nim"
			output+="\n#"
			# [https://stackoverflow.com/a/454549]
			# [https://linuxconfig.org/add-character-to-the-beginning-of-each-line-using-sed]
			diffoutput="$(diff  <(echo "$output_js" ) <(echo "$output_nim") | sed 's/^/# /')"
			output+="\n\n# $decor DIFF $decor\n$diffoutput"
		fi
	else
		output_js="$(nodecliac format --source "$f" --indent "t:1" --test)"
		if [[ "$output_js" == "["* ]]; then
			# Remove colors from output: [https://stackoverflow.com/a/54648447]
			output_js="$(echo "$output_js" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')"
		fi
		output_nim="$("$NIM_BIN" format --source "$f" --indent "t:1" --test)"
		if [[ "$output_nim" == "["* ]]; then
			output_nim="$(echo "$output_nim" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')"
		fi
		if [[ "$output_js" == "$output_nim" ]]; then
			output="$output_js"
		else
			log="true"
			output=" -:- formatting -:-\n\n"
			output+="# $decor <JS $decor\n"
			output+="$output_js"
			output+="\n#\n\n"
			output+="# $decor >Nim $decor\n"
			output+="$output_nim"
			output+="\n#"
			diffoutput="$(diff  <(echo "$output_js" ) <(echo "$output_nim") | sed 's/^/# /')"
			output+="\n\n# $decor DIFF $decor\n$diffoutput"
		fi
	fi

	# Get basename from file path.
	# [https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/]
	# [https://stackoverflow.com/a/3362952]
	# [https://stackoverflow.com/a/2664746]
	# [https://stackoverflow.com/a/42069449]
	# [https://stackoverflow.com/a/192337]
	f="$(basename -- $f)"
	# Get filename (no extension) from basename.
	f="${f%.*}"

	# Check if file is a test file and not an actual/real .acmap.
	istest_file=""
	if [[ "$f" == *"-t" ]]; then
		istest_file="${BOLD}*${NC}"
		# [https://stackoverflow.com/a/27658733]
		f=${f::-2} # Remove test file indicator.
	fi

	# The output file path.
	foutput="$TESTDIR/$output_path/$f.$EXTENSION"

	# Create log files if tests fail.
	if [[ "$log" == "true" ]]; then
		mkdir -p "$logpath"
		echo -e "$output" > "$logpath/$f.$EXTENSION"
	fi
	
	# If output folder is not yet populated, populate it.
	if [[ ! -e "$foutput" ]]; then
		echo "$output" >> "$foutput"
	fi

	# Compare output with output file.
	contents="$(<"$foutput")"
	# If the contents don't match the output something failed.
	if [[ "$output" != "$contents" ]]; then
		if [[ $(isset "$PRINT") ]]; then
			echo -e " $X_MARK ${RED}$f${NC}$istest_file"
			# exit 1
			# echo -e "$output"
			# nodecliac make --source "$forg" --test
			# nodecliac format --source "$forg" --indent "t:1" --test
		fi
	else
		if [[ $(isset "$PRINT") ]]; then
			echo -e " $CHECK_MARK $f$istest_file"
		fi
		((passed_count++))
	fi
done

if [[ $(isset "$PRINT") ]]; then
	echo ""
	# Perl round number: [https://stackoverflow.com/a/178576]
	percent=$(perl -e "printf \"%.2f\", $passed_count/$files_count*100")
	echo -e " ${BBLUE}Result${NC}: $passed_count/$files_count — (coverage: ${BOLD}$percent%${NC})"
fi

if [[ $(isset "$PRINT") ]]; then echo ""; fi # Pad output.

# [https://shapeshed.com/unix-exit-codes/]
if [[ "$passed_count" == "$files_count" ]]; then exit 0; else exit 1; fi
