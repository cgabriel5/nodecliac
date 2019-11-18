#!/bin/bash

# Script checks whether `nodecliac make` returns same output. If so
# the parser is working properly.

# -----------------------------------------------------------------CLI-ARGUMENTS

LOG_SILENT=0
SKIP_HEADER=0

while getopts 'sh' flag; do
	case "$flag" in
		s) LOG_SILENT=1 ;;
		h) SKIP_HEADER=1 ;;
	esac
done

# --------------------------------------------------------------------------VARS

# [https://www.utf8-chartable.de/unicode-utf8-table.pl?start=9984&number=128&names=-&utf8=string-literal]
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
X_MARK="\033[0;31m\xe2\x9c\x98\033[0m"

# Get path test directory path.
# [https://stackoverflow.com/a/246128]
# Remove current directory from path. [https://unix.stackexchange.com/a/28773]
DIR="$(dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd ))"

# The output path.
output_path="outputs/parsers"
# Create needed folder it not already created.
mkdir -p "$DIR/$output_path"

# populate=0
# # If output folder is not yet populated, populate it.
# # [https://superuser.com/a/352290]
# if [[ -z "$(ls -A $DIR/$output_path)" ]]; then
# 	populate=1
# fi

files_count=0
passed_count=0

# --------------------------------------------------------------------------TEST

# Print header.
if [[ "$LOG_SILENT" == 0 && "$SKIP_HEADER" == 0 ]]; then
	echo -e "\033[1m[Testing Parser]\033[0m"
fi

for f in "$DIR"/acmaps/*.acmap; do
	((files_count++))

	forg="$f"
	# Run with `--test` flag to prevent printing headers/meta information.
	output="$(nodecliac make --source "$f" --test)"

	# Get basename from file path.
	# [https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/]
	# [https://stackoverflow.com/a/3362952]
	# [https://stackoverflow.com/a/2664746]
	f="$(basename -- $f)"
	# Get filename (no extension) from basename.
	f="${f%.*}"

	# Check if file is a test file and not an actual/real .acmap.
	istest_file=""
	if [[ "$f" == *"-t" ]]; then
		istest_file="\033[1m*\033[0m"
		f=${f/-t/} # Remove test file indicator.
	fi
	
	# The output file path.
	foutput="$DIR/$output_path/$f.acdef"

	# If output folder is not yet populated, populate it.
	# if [[ "$populate" == "1" ]]; then
	if [[ ! -e "$foutput" ]]; then
		echo "$output" >> "$foutput"
	fi

	# else
	# Compare output with output file.
	contents="$(<"$foutput")"
	# If the contents don't match the output something failed.
	if [[ "$output" != "$contents" ]]; then
		if [[ "$LOG_SILENT" == 0 ]]; then
			echo -e " $X_MARK \033[31m$f\033[0m$istest_file"
			# exit 1
			# echo -e "$output"
			# nodecliac make --source "$forg" --test
		fi
	else
		if [[ "$LOG_SILENT" == 0 ]]; then			
			echo -e " $CHECK_MARK $f$istest_file"
		fi
		((passed_count++))
	fi
	# fi

done

# # If passed_count is zero then $output_path/ directory was just populated
# # so re-run the test with the populated directory.
# if [[ "$passed_count" == "0" ]]; then
# 	# [https://stackoverflow.com/a/42069449]
# 	# [https://stackoverflow.com/a/192337]
# 	scriptname="$(basename "$0")"
# 	. "$DIR/$scriptname" -h -s
# else
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
if [[ "$LOG_SILENT" == 0 ]]; then
	echo ""
	# Perl round number: [https://stackoverflow.com/a/178576]
	percent=$(perl -e "printf \"%.2f\", $passed_count/$files_count*100")
	echo -e " \033[1;34mResult\033[0m: $passed_count/$files_count — (coverage: \033[1m$percent%\033[0m)"
fi
# fi

# [https://shapeshed.com/unix-exit-codes/]
if [[ "$passed_count" == "$files_count" ]]; then exit 0; else exit 1; fi
