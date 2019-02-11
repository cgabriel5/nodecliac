# Get version information.
vmajor=${BASH_VERSINFO[0]}
vminor=${BASH_VERSINFO[1]}

# Bash version must be 4.3+ to register completion scripts to commands.
if [[ vmajor -ge 4 ]]; then
	# If bash is version 4 then it must be at least 4.3.
	if [[ vmajor -eq 4 && vminor -le 2 ]]; then return; fi

	# Continue if version is at least 4.3...

	acscript="$HOME/.nodecliac/ac.sh"
	if [[ -f "$acscript" ]]; then
		# Loop over map definition files to source them.
		# [https://stackoverflow.com/a/43606356]
		for filepath in ~/.nodecliac/defs/*; do
			# Get dir and filename.
			# dir=${filepath%/*}
			# Get filename from file path.
			filename="${filepath##*/}"
			# Get command name (everything up to first period).
			command="${filename%%.*}"

			# Only register script to command if command exists in filename.
			if [[ ! -z "$command" ]]; then
				# If command exists then register completion script to command.
				# Note: Command is provided to script as the first parameter.
				source "$acscript" "${command##*/}" "$filename"
			fi
		done
	fi
fi
