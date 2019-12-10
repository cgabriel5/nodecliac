#!/bin/bash

# Compiles ac binary for OS.
# Example usage: $ ./compile -p -i ~/Desktop/ac.nim -o ~/Desktop/

# Nim has to be intalled to proceed.
if [[ -z "$(command -v nim)" ]]; then
	echo "[ABORTED]: Nim is not installed."
	exit
fi

# Get OS name.
USER_OS=`uname`
USER_OS=`perl -nle 'print lc' <<< "$USER_OS"`
# USER_OS="${USER_OS,,}" # Lowercase [https://stackoverflow.com/a/47815884]
# If os is darwin rename to macosx.
if [[ "$USER_OS" == "darwin" ]]; then USER_OS="macosx"; fi

# Get passed flags.
INPUT_PATH="src/scripts/ac/ac.nim"
OUTPUT_PATH="src/scripts/bin/ac.$USER_OS"
COMPILE_DEV=""
COMPILE_PROD=""
while getopts ':i:o:dp' flag; do
	case "$flag" in
		i) INPUT_PATH="$OPTARG" ;;
		o)
			OUTPUT_PATH="$OPTARG"
			# Append trailing slash if not already present.
			if [[ "$OUTPUT_PATH" != *"/" ]]; then OUTPUT_PATH+="/"; fi
			OUTPUT_PATH+="ac.$USER_OS" # Append output file name.
			# [https://stackoverflow.com/a/6121114]
			# fdir="$(dirname "${INPUT_PATH}")"
			# fname="$(basename "${INPUT_PATH}")"
		;;
		d) COMPILE_DEV="true" ;;
		p) COMPILE_PROD="true" ;;
	esac
done
shift $((OPTIND -1))
# [https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/]

CPU_ARCHITECTURE="i386" # Default to 32 bit. [https://askubuntu.com/a/93196]
if [[ "$(uname -m)" == "x86_64" ]]; then CPU_ARCHITECTURE="amd64"; fi

if [[ "$USER_OS" == "linux" ]]; then
	# If compile flag was provided...
	if [[ -n "$COMPILE_DEV" || -n "$COMPILE_PROD" ]]; then
		if [[ -n "$COMPILE_DEV" ]]; then
			nim c --run \
			--cpu:"$CPU_ARCHITECTURE" \
			--os:"$USER_OS" \
			--hints:on \
			--showAllMismatches:on \
			--forceBuild:on \
			--profiler:on \
			--stacktrace:on \
			--out:"$OUTPUT_PATH" \
			"$INPUT_PATH"
		elif [[ -n "$COMPILE_PROD" ]]; then
			nim c \
			-d:release \
			--cpu:"$CPU_ARCHITECTURE" \
			--os:"$USER_OS" \
			--debugger:off \
			--opt:speed \
			--checks:off \
			--threads:on \
			--assertions:off \
			--hints:off \
			--showAllMismatches:off \
			--forceBuild:on \
			--out:"$OUTPUT_PATH" \
			"$INPUT_PATH"
			strip -s "$OUTPUT_PATH"
		fi

		chmod +x "$OUTPUT_PATH" # Finally, make file executable.
	else
		echo "[ABORTED]: -p or -d switch not provided."
	fi
elif [[ "$USER_OS" == "macosx" ]]; then
	nim c -d:release \
	--debugger:off \
	--opt:speed \
	--checks:off \
	--threads:on \
	--assertions:off \
	--hints:off \
	--showAllMismatches:off \
	--forceBuild:on \
	--out:"$OUTPUT_PATH" \
	"$INPUT_PATH"

	chmod +x "$OUTPUT_PATH" # Finally, make file executable.
fi