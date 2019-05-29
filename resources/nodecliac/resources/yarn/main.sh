# Parses and extracts data from package.json files.
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
# Resource:
#    Code lifted and modified from dsifford's yarn-completion [https://github.com/dsifford/yarn-completion].
##
__yarn_get_package_fields() {
	declare cwd=$PWD field_type=object field_key opt package_dot_json OPTIND OPTARG

	# '-n' documentation: [https://likegeeks.com/sed-linux/]
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

	field_key='"'$1'"'

	[[ ! -f $package_dot_json || ! $field_key ]] && return

	# Generate the primitive (boolean, number, string) RegExp patterns.
	function __ptn_prim() {
		# Vars.
		local pattern mpattern

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
	function __ptn_objt() {
		# Vars.
		local pattern1 pattern2

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

	# Generate RegExp pattern to extract needed data from package.json.
	case "$field_type" in
		object)  pattern="`__ptn_objt object`"  ;;
		array)   pattern="`__ptn_objt array`"   ;;
		boolean) pattern="`__ptn_prim boolean`" ;;
		number)  pattern="`__ptn_prim number`"  ;;
		string)  pattern="`__ptn_prim string`"  ;;
	esac

	# Finally, extract package.json data.
	sed -n "$pattern"  "$package_dot_json"
}

# Depending on provided action run appropriate logic...

case "$1" in
	remove|outdated|unplug|upgrade)
		# Get (dev)dependencies.
		dev=`__yarn_get_package_fields dependencies`
		devdep=`__yarn_get_package_fields devDependencies`

		# Return (dev)dependencies values to auto-complete.
		echo -e "$dev\n$devdep"
	;;
	run)
		# Get script names.
		scripts=`__yarn_get_package_fields scripts`

		# Run perl script to get completions.
		prune_args_script=~/.nodecliac/resources/yarn/prune_args.pl
		# Run completion script if it exists.
		if [[ -f "$prune_args_script" ]]; then
			output=`"$prune_args_script" "$scripts"`

			# Return script names.
			echo -e "\n$output"
		fi
	;;
esac
