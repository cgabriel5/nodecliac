#!/bin/bash

# Provide config keys to set|get|delete subcommands.

# Config keys: [https://stackoverflow.com/a/37222377]
# [https://yarnpkg.com/lang/en/docs/cli/config/#toc-yarn-config-list]
# [https://github.com/yarnpkg/yarn/issues/3320]
# [https://github.com/dsifford/yarn-completion/blob/master/yarn-completion.bash#L384]
keys=$(cat <<-END
	ignore-optional
	ignore-platform
	ignore-scripts
	init-author-email
	init-author-name
	init-author-url
	init-license
	init-version
	no-progress
	prefix
	registry
	save-prefix
	user-agent
	version-git-message
	version-git-sign
	version-git-tag
	version-tag-prefix
END
)

# Run perl script to get completions.
prune_args_script=~/.nodecliac/commands/yarn/scripts/prune_args.pl
# Run completion script if it exists.
if [[ -f "$prune_args_script" ]]; then
	output=`"$prune_args_script" "$keys"`

	# Return script names.
	echo -e "\n$output"
fi
