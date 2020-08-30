#!/bin/bash

function completion_logic() {
	local COMP_CWORD="$NODECLIAC_COMP_INDEX"
	local LAST="$NODECLIAC_LAST"
	local CTYPE="$NODECLIAC_COMP_TYPE"
	local prev="$NODECLIAC_PREV"
	local cmd="$NODECLIAC_ARG_1"
	local sub="$NODECLIAC_ARG_2"
	local cat="$NODECLIAC_ARG_3"

	# [https://stackoverflow.com/a/37222377]
	# [https://support.1password.com/command-line/#appendix-categories]
	local categories=(
		'Login'
		'Secure Note'
		'Credit Card'
		'Identity'
		'Bank Account'
		'Database'
		'Driver License'
		'Email Account'
		'Membership'
		'Outdoor License'
		'Passport'
		'Reward Program'
		'Server'
		'Social Security Number'
		'Software License'
		'Wireless Router'
	)

	case "$cmd" in
		create|get)
			case "$sub" in
				item|template)
					if [[ $COMP_CWORD == 3 ]]; then
						# Remove user name from path: [https://stackoverflow.com/a/22261454]
						local re="^([\'\"])"
						[[ "$cat" =~ $re ]]
						local q="${BASH_REMATCH[1]}"
						if [[ -z "$cat" || -z "$q" ]]; then
							# [https://stackoverflow.com/a/45207304]
							# [https://stackoverflow.com/a/15692004]
							printf '%s\n' "${categories[@]// /\\ }"
							# for c in "${categories[@]}"; do echo "${c// /\\ }"; done
						else
							printf "$q%s$q\n" "${categories[@]}"
							# for c in "${categories[@]}"; do echo "$q$c$q"; done
						fi
					fi
					return ;;
			esac
			;;

		list)
			case "$sub" in
				items)
					if [[ "$CTYPE" == "flag" && "$LAST" == "--categories="* ]]; then
						local output="$(~/.nodecliac/registry/op/scripts/categories.pl DSL)"
						[[ -n "$output" ]] && echo -e "$output"
					fi
					return ;;
			esac
			;;

	esac
}
completion_logic
