acscript="$HOME/.nodecliac/ac.sh"
if [[ -f "$acscript" ]]; then
	# Loop over map definition files to source them.
	# [https://stackoverflow.com/a/43606356]
	for filepath in ~/.nodecliac/maps/*; do
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
			source "$acscript" "${filepath##*/}"
		fi
	done
fi
