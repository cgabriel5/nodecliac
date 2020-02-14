#!/bin/bash

# Compiles Nim project file through the Nim compiler.
#
# Flags:
#
# -i: Path of file to compile.
# -o: Path of binary output.
# -d: Compile development binary.
# -p: Compile production binary.
#
# Examples:
#
# Build production binary:
# 	$ ./compile -i ~/Desktop/file.nim -o ~/Desktop/ -p
# Build development binary:
# 	$ ./compile -i ~/Desktop/file.nim -o ~/Desktop/ -d

# Nim has to be intalled to proceed.
if [[ -z "$(command -v nim)" ]]; then
	echo "[ABORTED] Nim is not installed."
	exit
fi

# Get OS name.
USER_OS=`uname`
USER_OS=`perl -nle 'print lc' <<< "$USER_OS"`
# USER_OS="${USER_OS,,}" # Lowercase [https://stackoverflow.com/a/47815884]
# If os is darwin rename to macosx.
if [[ "$USER_OS" == "darwin" ]]; then USER_OS="macosx"; fi

# Get passed flags.
INPUT_PATH=""
OUTPUT_PATH=""
COMPILE_DEV="true" # Default.
COMPILE_PROD=""
file=""
ext=""
name=""
while getopts ':i:o:dp' flag; do
	case "$flag" in
		i) INPUT_PATH="$OPTARG" ;;
		o)
			OUTPUT_PATH="$OPTARG"
			# Append trailing slash if not already present.
			if [[ "$OUTPUT_PATH" != *"/" ]]; then OUTPUT_PATH+="/"; fi

			# [https://stackoverflow.com/a/965072]
			file=$(basename -- "$INPUT_PATH")
			ext="${file##*.}" # File extension.
			name="${file%.*}" # File name.

			OUTPUT_PATH+="$name.$USER_OS" # Append output file name.
			# [https://stackoverflow.com/a/6121114]
			# fdir="$(dirname "$INPUT_PATH")"
			# fname="$(basename "$INPUT_PATH")"
		;;
		d) COMPILE_DEV="true"; COMPILE_PROD="" ;;
		p) COMPILE_PROD="true"; COMPILE_DEV="" ;;
	esac
done
shift $((OPTIND -1))
# [https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/]

# If input is not provided exit.
if [[ -z "$INPUT_PATH" ]]; then
	echo "[ABORTED] Provide project input file."
	exit
fi

if [[ ! -e "$INPUT_PATH" ]]; then
	echo "[ABORTED] Path doesn't exist."
	exit
fi

if [[ ! -f "$INPUT_PATH" ]]; then
	echo "[ABORTED] Path doesn't lead to a file."
	exit
fi

# If output path isn't given, save to dir of source file.
if [[ -z "$OUTPUT_PATH" ]]; then
	OUTPUT_PATH="$(dirname "$INPUT_PATH")"

	# [https://stackoverflow.com/a/965072]
	file=$(basename -- "$INPUT_PATH")
	ext="${file##*.}" # File extension.
	name="${file%.*}" # File name.

	OUTPUT_PATH+="/$name.$USER_OS"
fi

if [[ "$ext" != "nim" ]]; then
	echo "[ABORTED] Please provide a '.nim' file."
	exit
fi

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
