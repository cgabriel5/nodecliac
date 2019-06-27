#!/bin/bash

# Store package.json JSON data and file path.
# Modifying global vars: [https://stackoverflow.com/q/23564995]
package_dot_json=""
field_type="object"

# Find package.json file path.
#
# @return {undefined} - Nothing is returned.
function __getpkg_filepath() {
	# Declare variables.
	declare cwd="$PWD" opt OPTIND OPTARG

	# [https://stackoverflow.com/a/19031736]
	# [http://defindit.com/readme_files/perl_one_liners.html]
	# [https://www.perlmonks.org/?node_id=1004245]
	# Get workspace name if auto-completing workspace.
	workspace=$(echo "$NODECLIAC_INPUT_ORIGINAL" | perl -ne 'print "$1" if /^[ \t]*yarn[ \t]+workspace[ \t]+([a-zA-Z][-_a-zA-Z0-9]*)[ \t]*.*/')

	# If workspace flag is set then we are auto-completing a workspace.
	# Therefore, reset CWD to workspace's location.
	if [[ ! -z "$workspace" ]]; then cwd="$PWD/$workspace"; fi

	# '-n' documentation:
	# [https://stackoverflow.com/a/3601734]
	# [https://linuxconfig.org/how-to-test-for-null-or-empty-variables-within-bash-script]
	# [https://likegeeks.com/sed-linux/]
	while [[ -n $cwd ]]; do
		if [[ -f "$cwd/package.json" ]]; then
			package_dot_json="$cwd/package.json"
			break
		fi
		cwd="${cwd%/*}"
	done

	while getopts ":gt:" opt; do
		case $opt in
			g)
				if [[ -f $HOME/.config/yarn/global/package.json ]]; then
					package_dot_json="$HOME/.config/yarn/global/package.json"
				elif [[ -f $HOME/.local/share/yarn/global/package.json ]]; then
					package_dot_json="$HOME/.local/share/yarn/global/package.json"
				elif [[ -f $HOME/.yarn/global/package.json ]]; then
					package_dot_json="$HOME/.yarn/global/package.json"
				else
					package_dot_json=""
				fi
				;;
			t)
				case "$OPTARG" in
					array | boolean | number | object | string)
						field_type="$OPTARG"
						;;
				esac
				;;
			*) ;;
		esac
	done
	# [https://unix.stackexchange.com/a/214151]
	shift $((OPTIND - 1))
}; __getpkg_filepath; # Immediately run function.

# Generate the primitive (boolean, number, string) RegExp lookup pattern.
#
# @param {string} 1) - The data type.
# @param {string} 2) - The field key (package.json key entry).
# @return {string} - The RegExp lookup pattern.
function __ptn_prim() {
	# Vars.
	local pattern mpattern field_key='"'$2'"'

	# RegExp escaping documentation:
	# [https://unix.stackexchange.com/questions/263668/sed-capture-groups-not-working#comment860675_263675]
	# [https://stackoverflow.com/a/11651184]
	# [https://stackoverflow.com/a/2777621]
	# [https://superuser.com/a/112000]

	# Lookup data type's patterns.
	case "$1" in
		boolean) pattern='\(true\|false\)' ;;
		number)  pattern='"\([\.0-9]*\)"'  ;;
		string)  pattern='"\(.*\)"'        ;;
	esac

	# Boolean, string, number general pattern.
	mpattern="[[:space:]]*$field_key:[[:space:]]*XX.*"
	# [https://stackoverflow.com/a/13210909]
	echo "s/${mpattern/XX/$pattern}/\1/p"
}

# Generate the object (object, array) RegExp patterns.
#
# @param {string} 1) - The data type.
# @param {string} 2) - The field key (package.json key entry).
# @return {string} - The RegExp lookup pattern.
function __ptn_objt() {
	# Vars.
	local pattern1 pattern2 field_key='"'$2'"'

	# Lookup data type's patterns.
	case "$1" in
		object) pattern1='{';  pattern2='}' ;;
		array)  pattern1='\['; pattern2=']' ;;
	esac

	# Boolean, string, number general pattern.
	echo '/'"$field_key"':[[:space:]]*'"$pattern1"'/,/^[[:space:]]*'"$pattern2"'/{
		# exclude start and end patterns
		//!{
			# extract the text between the first pair of double quotes
			s/^[[:space:]]*"\([^"]*\).*/\1/p
		}
	}'
}

# Extracts data from package.json.
#
# Usage:
#	__yarn_get_package_fields [-g] [-t FIELDTYPE] <field-key>
#
# Options:
#   -g			  Parse global package.json file, if available
#   -t FIELDTYPE  The field type being parsed (array|boolean|number|object|string) [default: object]
#
# Notes:
#	If FIELDTYPE is object, then the object keys are returned.
#	If FIELDTYPE is array, boolean, number, or string, then the field values are returned.
#	<field-key> must be a first-level field in the json file.
#
# Resource: Lifted/modified from dsifford's yarn-completion [https://github.com/dsifford/yarn-completion].
function __yarn_get_package_fields() {
	# Vars.
	field_key="$1"

	# package.json file must exist and field key must be provided to continue.
	[[ ! -f "$package_dot_json" || ! "$field_key" ]] && return

	# Generate RegExp pattern to extract needed data from package.json.
	case "$field_type" in
		object)  pattern="`__ptn_objt object $field_key`"  ;;
		array)   pattern="`__ptn_objt array $field_key`"   ;;
		boolean) pattern="`__ptn_prim boolean $field_key`" ;;
		number)  pattern="`__ptn_prim number $field_key`"  ;;
		string)  pattern="`__ptn_prim string $field_key`"  ;;
	esac

	# Finally, extract package.json data.
	sed -n "$pattern" "$package_dot_json"
}

# Perl script path.
prune_args_script=~/.nodecliac/registry/yarn/scripts/prune_args.pl

# Depending on provided action run appropriate logic...

case "$1" in
	remove|outdated|unplug|upgrade)
		# Get (dev)dependencies.
		dev=`__yarn_get_package_fields dependencies`
		devdep=`__yarn_get_package_fields devDependencies`

		# Run completion script if it exists.
		if [[ -f "$prune_args_script" ]]; then
			# [https://stackoverflow.com/a/13658950]
			nl=$'\n'

			output=`"$prune_args_script" "$dev$nl$devdep"`

			# Return (dev)dependencies values to auto-complete.
			echo -e "\n$output"
		fi

		break
	;;
	run)
		# Get script names.
		scripts=`__yarn_get_package_fields scripts`

		# Run completion script if it exists.
		if [[ -f "$prune_args_script" ]]; then
			output=`"$prune_args_script" "$scripts"`

			# Return script names.
			echo -e "\n$output"
		fi

		break
	;;
	workspace)
		# Get workspaces info via yarn.
		workspaces_info=$(yarn workspaces info -s 2> /dev/null)

		# Get args count.
		args_count="$NODECLIAC_ARG_COUNT"

		if [[ -n "$workspaces_info" && "$args_count" -le 2 ]] || [[ -n "$workspaces_info" && "$args_count" -le 3 && "$NODECLIAC_LAST_CHAR" != " " ]]; then
			# Get workspace names.
			# [https://github.com/dsifford/yarn-completion/blob/master/yarn-completion.bash]
			# [https://www.computerhope.com/unix/bash/mapfile.htm]
			mapfile -t < <(sed -n 's/^ \{2\}"\([^"]*\)": {$/\1/p' <<< "$workspaces_info")

			# Run completion script if it exists.
			if [[ -f "$prune_args_script" ]]; then
				output=`"$prune_args_script" "${MAPFILE[*]}"`

				# Return script names.
				echo -e "\n$output"
			fi
		fi
	;;
esac
