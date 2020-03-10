#!/usr/bin/perl

# Script returns config keys to set|get|delete subcommands.

# use strict;
# use warnings;
# use diagnostics;

# Config keys: [https://stackoverflow.com/a/37222377]
# [https://yarnpkg.com/lang/en/docs/cli/config/#toc-yarn-config-list]
# [https://github.com/yarnpkg/yarn/issues/3320]
# [https://github.com/dsifford/yarn-completion/blob/master/yarn-completion.bash#L384]
my %args = (
	'ignore-optional' => undef,
	'ignore-platform' => undef,
	'ignore-scripts' => undef,
	'init-author-email' => undef,
	'init-author-name' => undef,
	'init-author-url' => undef,
	'init-license' => undef,
	'init-version' => undef,
	'no-progress' => undef,
	'prefix' => undef,
	'registry' => undef,
	'save-prefix' => undef,
	'user-agent' => undef,
	'version-git-message' => undef,
	'version-git-sign' => undef,
	'version-git-tag' => undef,
	'version-tag-prefix' => undef
);

my $last = $ENV{'NODECLIAC_LAST'};
my $lchar = $ENV{'NODECLIAC_LAST_CHAR'};
my $nchar = $ENV{'NODECLIAC_NEXT_CHAR'};
my $used = $ENV{'NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS'};
chomp($used); # Remove trailing newline.
my @used_args = split(/[\n ]/, $used);

foreach my $uarg (@used_args) {
	if (exists($args{$uarg})) {
		delete $args{$uarg};
		$args{"!$uarg"} = undef;
	}
}

print join("\n", (keys %args));
