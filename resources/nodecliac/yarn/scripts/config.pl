#!/usr/bin/perl

# Script will return config keys to set|get|delete subcommands.

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Config keys: [https://stackoverflow.com/a/37222377]
# [https://yarnpkg.com/lang/en/docs/cli/config/#toc-yarn-config-list]
# [https://github.com/yarnpkg/yarn/issues/3320]
# [https://github.com/dsifford/yarn-completion/blob/master/yarn-completion.bash#L384]
my $keys = 'ignore-optional ignore-platform ignore-scripts init-author-email init-author-name init-author-url init-license init-version no-progress prefix registry save-prefix user-agent version-git-message version-git-sign version-git-tag version-tag-prefix';

# Prune arguments and return remaining.
require "$ENV{'HOME'}/.nodecliac/registry/yarn/scripts/prune.pl";
print(ARGPruner::main($keys));
