#!/usr/local/bin/bash

# Compiles Nim project file through the Nim compiler.
#
# Flags:
#
# --dev: Compile development binary.
# --prod: Compile production binary.
# --script: Generate cross-compilation script.
# 	- Value format: '<OS>:<CPU>'
# 	- <OS> values: (linux|macosx)
# 	- <CPU> values: (amd64|arm64)
# 	- Examples: 'linux:arm64', 'macosx:amd64'
# --name: Rename output binary to provided name.
# --gen: Type of code to generate: default 'c' (c|cpp|oc|js).
# --args: Prints arguments passed to compile.sh script. Use when debugging.
# CFLAGS: ENV var to pass options to compiler.
#
# Examples:
#
### Build production binary:
# 	$ yarn run build project.nim --prod
### Build development binary (default):
# 	$ yarn run build project.nim --dev
### Build development binary with compiler options via CFLAGS ENV var:
# 	$ CFLAGS="--opt:size" yarn run build project.nim --dev
### Build development binary and name created binary:
# 	$ yarn run build project.nim --dev --name nodecliac.linux
#
### Relative or absolute file path can be supplied.
# 	$ yarn run build project.nim --prod
# 	$ yarn run build ./project.nim --prod
# 	$ yarn run build ./folder/project.nim --prod
# 	$ yarn run build ../folder/project.nim --prod
# 	$ yarn run build "$(pwd)"/project.nim --prod
# 	$ yarn run build /absolute/path/to/project.nim --prod
#
### Cross-compilation.
# Copy the generated folder to the target machine, cd into said folder,
# make the 'compile_<PROJECT_NAME>.sh' file executable, and run it to
# generate the binary for that platform.
#
# The following examples will generate ARM64 or AMD64 scripts for Linux.
# 	$ yarn run build project.nim --dest ~/Desktop --script linux:arm64 --prod
# 	$ yarn run build project.nim --dest ~/Desktop --script linux:arm64 --dev
# 	$ yarn run build project.nim --dest ~/Desktop --script linux:amd64 --prod
#
# The following examples will generate ARM64 or AMD64 scripts for macOS.
# 	$ yarn run build project.nim --dest ~/Desktop --script macosx:arm64 --prod
# 	$ yarn run build project.nim --dest ~/Desktop --script macosx:arm64 --dev
# 	$ yarn run build project.nim --dest ~/Desktop --script macosx:amd64 --prod

RED="\033[0;31m"
# Bold colors.
BOLD="\033[1m"
NC="\033[0m"

# Get parent shell path: [https://askubuntu.com/a/1012236]
# [https://stackoverflow.com/a/46918581]
# [https://github.com/npm/npm/pull/10958]
if [[ "$OSTYPE" == "darwin"* ]]; then
	# [https://stackoverflow.com/a/1727031]
	# [https://apple.stackexchange.com/q/426347]
	path="$(perl -ne 'print $1 if /n(.*?)$/' <<< "$(lsof -a -p $SPPID -d cwd -Fn -w)")"
else
	# [TODO]: Test on Linux to ensure same behavior as lsof.
	path="$(ls -l /proc/$PPID/cwd | perl -ne 'print $1 if / -> (\/.*?)$/')/${1}"
fi

# Note: For the time being use Perl to resolve relative paths as macOS does
# not have readlink/realpath binaries.
# macOS Ventura:[https://apple.stackexchange.com/a/450116]
# [https://stackoverflow.com/a/10382170], [https://stackoverflow.com/a/24572274]
path=$(cd "$path" && echo "$(perl -MCwd -e 'print Cwd::abs_path shift' "$1")")
# [https://stackoverflow.com/a/30795461]
# path=$(perl -e 'use Cwd "abs_path"; print abs_path(@ARGV[0])' -- "$0")

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
getdest=""
printargs=""
for i in "${@}"; do
	# [[ "$i" == "-x"* ]] && echo "<$i>" && args+=("$i")
	[[ "$i" == "--args" ]] && printargs="1" && continue
	[[ "$i" == "--prod" ]] && args+=("-p") && continue
	[[ "$i" == "--dev" ]] && args+=("-d") && continue
	[[ "$i" == "--name" ]] && getname="1" && continue
	[[ -n "$getname" ]] && args+=("-n" "$i") && getname="" && continue
	[[ "$i" == "--script" ]] && getscript="1" && continue
	[[ -n "$getscript" ]] && args+=("-s" "$i") && getscript="" && continue
	[[ "$i" == "--gen" ]] && codegen="1" && continue
	[[ -n "$codegen" ]] && args+=("-c" "$i") && codegen="" && continue
	[[ "$i" == "--dest" ]] && getdest="1" && continue
	[[ -n "$getdest" ]] && args+=("-o" "$i") && getdest="" && continue
done

[[ -n "$printargs" ]] && echo -e "[\033[48;5;221mcompile.sh${NC} \033[38;5;247m${args[@]}${NC}]"
CFLAGS="$CFLAGS" "$(pwd)/src/scripts/main/compile.sh" "${args[@]}"

# Move scripts to src/scripts/bin/ destination?
# mv "src/scripts/ac/$F.$USER_OS" "src/scripts/bin/$F.$USER_OS"
