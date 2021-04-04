#!/bin/bash

# Compiles Nim project file through the Nim compiler.
#
# Flags:
#
# --dev: Compile development binary.
# --prod: Compile production binary.
# --script: Generate cross-compilation script (linux|macosx).
# --name: Rename output binary to provided name.
# --gen: Type of code to generate: default 'c' (c|cpp|oc|js).
# CFLAGS: ENV var to pass options to compiler.
#
# Examples:
#
# Build production binary:
# 	$ yarn run build "$(pwd)"/main.nim --prod
# Build development binary (default):
# 	$ yarn run build "$(pwd)"/main.nim --dev
# Build development binary with compiler options via ENV var:
# 	$ CFLAGS="--opt:size" yarn run build "$(pwd)"/main.nim --dev
# Build development binary and name created binary:
# 	$ yarn run build "$(pwd)"/main.nim --dev --name nodecliac.linux

RED="\033[0;31m"
# Bold colors.
BOLD="\033[1m"
NC="\033[0m"

# Get parent shell path: [https://askubuntu.com/a/1012236]
# [https://stackoverflow.com/a/46918581]
# [https://github.com/npm/npm/pull/10958]
path="$(ls -l /proc/$SPPID/cwd | perl -ne 'print $1 if / -> (\/.*?)$/')/${1}"

if [[ $# -eq 0 ]]; then
	echo -e "${RED}Error:${NC} No arguments provided." && exit
fi

if [[ ! -e "$path" ]]; then
	echo -e "${RED}Error:${NC} ${BOLD}${1}${NC} doesn't exist." && exit
fi

# Get OS name.
# USER_OS=`uname`
# USER_OS="${USER_OS,,}";
# USER_OS="${USER_OS/darwin/macosx}";
# name="${filename%%.*}"
# ext="${filename#*.}"
# output="${dirname}/${name}.${USER_OS}"

args=("-i" "$path")
getname=""
getscript=""
codegen=""
for i in "${@}"; do
	# [[ "$i" == "-x"* ]] && echo "<$i>" && args+=("$i")
	[[ "$i" == "--prod" ]] && args+=("-p") && continue
	[[ "$i" == "--dev" ]] && args+=("-d") && continue
	[[ "$i" == "--name" ]] && getname="1" && continue
	[[ -n "$getname" ]] && args+=("-n" "$i") && getname="" && continue
	[[ "$i" == "--script" ]] && getscript="1" && continue
	[[ -n "$getscript" ]] && args+=("-s" "$i") && getscript="" && continue
	[[ "$i" == "--gen" ]] && codegen="1" && continue
	[[ -n "$codegen" ]] && args+=("-c" "$i") && codegen="" && continue
done

CFLAGS="$CFLAGS" "$(pwd)/src/scripts/main/compile.sh" "${args[@]}"

# Move scripts to src/scripts/bin/ destination?
# mv "src/scripts/ac/$F.$USER_OS" "src/scripts/bin/$F.$USER_OS"
