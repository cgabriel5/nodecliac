#!/bin/bash

# Compiles Nim project file through the Nim compiler.
#
# Flags:
#
# -i: Path of file to compile.
# -o: Path of binary output.
# -d: Compile development binary.
# -p: Compile production binary.
# -n: Optional binary file name.
#
# Examples:
#
# Build production binary:
# 	$ ./compile -i ~/Desktop/file.nim -o ~/Desktop/ -p
# Build development binary:
# 	$ ./compile -i ~/Desktop/file.nim -o ~/Desktop/ -d

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


# Nim has to be intalled to proceed.
if [[ -z "$(command -v nim)" ]]; then
	echo "[ABORTED] Nim is not installed."
	exit 1
fi

# Get OS name.
USER_OS=`uname`
USER_OS=`perl -nle 'print lc' <<< "$USER_OS"`
# USER_OS="${USER_OS,,}" # Lowercase [https://stackoverflow.com/a/47815884]
# If os is darwin rename to macosx.
if [[ "$USER_OS" == "darwin" ]]; then USER_OS="macosx"; fi

# ANSI colors: [https://stackoverflow.com/a/5947802]
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
BOLD="\033[1m"
GREEN="\033[0;32m"
NC="\033[0m"

# Get passed flags.
INPUT_PATH=""
OUTPUT_PATH=""
COMPILE_DEV="true" # Default.
COMPILE_PROD=""
COMPILE_TYPE=""
file=""
ext=""
name=""
oname=""

# Parse any provided compiler flags via CFLAGS env.
coptions=()
 while IFS=';' read -ra COPTIONS; do
	for i in "${COPTIONS[@]}"; do
		coptions+=("$i")
	done
 done <<< "$(trim "$CFLAGS")"

while getopts ':i:o:n:dp' flag; do
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
			oname="$name.$USER_OS"
			# [https://stackoverflow.com/a/6121114]
			# fdir="$(dirname "$INPUT_PATH")"
			# fname="$(basename "$INPUT_PATH")"
		;;
		n) oname="$OPTARG" ;;
		d) COMPILE_DEV="true"; COMPILE_PROD="" ;;
		p) COMPILE_PROD="true"; COMPILE_DEV="" ;;
	esac
done
shift $((OPTIND -1))
# [https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/]

# If input is not provided exit.
if [[ -z "$INPUT_PATH" ]]; then
	echo "[ABORTED] Provide project input file."
	exit 1
fi

if [[ ! -e "$INPUT_PATH" ]]; then
	echo -e "[ABORTED] Path ${BOLD}$INPUT_PATH${NC} doesn't exist."
	exit 1
fi

if [[ ! -f "$INPUT_PATH" ]]; then
	echo -e "[ABORTED] Path ${BOLD}$INPUT_PATH${NC} doesn't lead to a file."
	exit 1
fi

# If output path isn't given, save to dir of source file.
if [[ -z "$OUTPUT_PATH" ]]; then
	OUTPUT_PATH="$(dirname "$INPUT_PATH")"

	# [https://stackoverflow.com/a/965072]
	file=$(basename -- "$INPUT_PATH")
	ext="${file##*.}" # File extension.
	name="${file%.*}" # File name.
	if [[ -z "$oname" ]]; then oname="$name.$USER_OS"; fi
fi
OUTPUT_PATH+="/$oname" # Append output file name.

if [[ "$ext" != "nim" ]]; then
	echo "[ABORTED] Please provide a '.nim' file."
	exit 1
fi

CPU_ARCHITECTURE="i386" # Default to 32 bit. [https://askubuntu.com/a/93196]
if [[ "$(uname -m)" == "x86_64" ]]; then CPU_ARCHITECTURE="amd64"; fi

# Compile with '-no-pie' to generated an executable and not shared library:
# [https://forum.openframeworks.cc/t/ubuntu-18-04-mistaking-executable-as-shared-library/30873]
# [https://askubuntu.com/q/1071374]
# [https://stackoverflow.com/a/45332687]
# [https://askubuntu.com/a/960212]
# [https://stackoverflow.com/a/50615370]
# [https://github.com/nim-lang/Nim/issues/506]
# [https://nim-lang.org/docs/manual.html#implementation-specific-pragmas-passl-pragma]

args=(
	"--passL:\"-no-pie\""
	"--cpu:$CPU_ARCHITECTURE"
	"--os:$USER_OS"
	# "--forceBuild:on"
)

if [[ "$INPUT_PATH" == *"/gui/"* ]]; then
	COMPILE_TYPE="GUI"
	args+=(
		"--gc:arc"
		"--app:gui"
		"-d:ssl"
		"-d:release"
		"-d:danger"
		"--tlsEmulation:off"
		"--passL:\"-s\""
		"--threads:on"
		"--verbosity:0"
		"--opt:speed"
		"--checks:off"
		"--assertions:off"
		"--hints:on"
		"--showAllMismatches:off"
		# "--forceBuild:off"
		"--stackTrace:off"
		"--lineTrace:off"
		"--deadCodeElim:on"
		"--linedir:off"
		"--profiler:off"
		"--panics:off"
		"-d:nimDebugDlOpen"
		"-d:noSignalHandler"
		# "--debuginfo"
	)
elif [[ -n "$COMPILE_DEV" ]]; then
	COMPILE_TYPE="DEV"
	args+=(
		"--hints:on"
		"--profiler:on"
		"--stacktrace:on"
		"--showAllMismatches:on"
	)
elif [[ -n "$COMPILE_PROD" ]]; then
	COMPILE_TYPE="PROD"
	args+=(
		"-d:release"
		"-d:danger"
		"--opt:speed"
		"--hints:off"
		"--checks:off"
		"--threads:off"
		"--debugger:off"
		"--debuginfo:off"
		"--lineTrace:off"
		"--assertions:off"
		"--stackTrace:off"
		"--deadCodeElim:on"
		"--showAllMismatches:off"
	)

	# Packing greatly reduces binary size, but also adds a little overhead
	# at the cost of execution speed. Therefore, disable packing for now.
	# if [[ "$USER_OS" == "linux" ]]; then strip -s "$OUTPUT_PATH"; fi
	# if [[ -n "$(command -v upx)" ]]; then upx --best "$OUTPUT_PATH"; fi
fi

# Add any explicitly provided compiler options.
[[ "${#coptions[@]}" -gt 0 ]] && args+=("${coptions[@]}")

args+=(
	"--out:$OUTPUT_PATH"
	"$INPUT_PATH"
)

echo -e "nim compile / ${GREEN}${BOLD}[${COMPILE_TYPE}]${NC}"
count="${#args[@]}"
index=0
for x in "${args[@]}"; do
	decor=$([ $index == $((count-1))  ] && echo "└──" || echo "├──")
	spacing=" "
	[[ "${x:1:1}" != "-" ]] && spacing="  "
	echo " ${decor}${spacing}${x}"
	index=$((index+1))
done

nim compile "${args[@]}"
[[ -f "$OUTPUT_PATH" ]] && chmod +x "$OUTPUT_PATH"
