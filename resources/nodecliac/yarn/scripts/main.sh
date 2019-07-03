#!/bin/bash

# Get arguments.
action="$1"
useglobal_pkg="$2"

# Get package.json JSON file path.
package_info=`"$HOME/.nodecliac/registry/yarn/scripts/pkg_path.sh" "$NODECLIAC_INPUT_ORIGINAL" "$useglobal_pkg"`
read -r firstline <<< "$package_info"
field_type="${firstline%%:*}"
package_dot_json="${firstline#*:}"

# package.json file must exist to continue.
[[ ! -f "$package_dot_json" ]] && exit

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
	local pattern field_key="$1"

	# Generate RegExp pattern to extract needed data from package.json.
	case "$field_type" in
		object|array) pattern="`__ptn_objt "$field_type" $field_key`" ;;
		boolean|boolean|string) pattern="`__ptn_prim "$field_type" $field_key`" ;;
	esac

	# Finally, extract package.json data.
	sed -n "$pattern" "$package_dot_json"
}

# Perl script path.
prune_args_script=~/.nodecliac/registry/yarn/scripts/prune_args.pl
# Run completion script if it exists: [https://stackoverflow.com/a/21164441]
if [[ ! -f "$prune_args_script" ]]; then exit; fi

# Store action arguments for later pruning.
args=""

# Depending on provided action run appropriate logic...
case "$action" in
	remove|outdated|unplug|upgrade)
		# Get (dev)dependencies.
		dev=`__yarn_get_package_fields dependencies`
		devdep=`__yarn_get_package_fields devDependencies`

		# [https://stackoverflow.com/a/13658950]
		nl=$'\n'

		# Store arguments.
		args="$dev$nl$devdep"
	;;
	run)
		# Get script names and store arguments.
		args=`__yarn_get_package_fields scripts`
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

			# Store arguments.
			args="${MAPFILE[*]}"
		fi
	;;
esac

# If output exists run the pruning arguments script and return result.
if [[ ! -z "$args"  ]]; then
	# Run argument pruning script.
	output=`"$prune_args_script" "$args"`
	echo -e "\n$output"
fi
