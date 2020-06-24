#!/usr/bin/perl

# use strict;
# use warnings;
# use diagnostics;

my %args;
my $cwd = $ENV{'PWD'};
my $hdir = $ENV{'HOME'};
my $path = "$hdir/.nodecliac/registry";
my $used = $ENV{'NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS'} // "";

# [https://stackoverflow.com/a/5751949]
# [https://stackoverflow.com/a/2912084]
# [https://alvinalexander.com/blog/post/perl/how-process-every-file-directory-perl/]
opendir(DIR, $path) or exit;
while (my $name = readdir(DIR)) {
	if (-d "$path/$name" && $name !~ /^\.{1,2}$/) {
		my $pattern = '^' . $name . '$';
		print (($used =~ /$pattern/m ? '!' : '') . "$name\n");
	}
}
closedir(DIR);
