#!/usr/bin/perl

# Script returns repo scripts to add to ACDEF and the modified CLI input.

# use strict;
# use warnings;
# use diagnostics;

my $input = $ARGV[0];
my $output = "\n";
my ($workspace_name, $cli_remainder) = $input =~ /^[ \t]*?yarn[ \t]+?workspace[ \t]+?([^ \t]+?)[ \t]+?(.*)/;

# ----- Input logic -----

if ($cli_remainder) { $output = "yarn $cli_remainder"; }

# ----- ACDEF logic -----

if ($input =~ /^[ \t]*?yarn[ \t]+?([^ \t]*?)$/) {
	my $cwd = $ENV{'PWD'};
	my $pkg = '';

	# If a workspace use its location.
	if ($workspace_name) { $cwd .= "/$1"; }
	while ($cwd) {
		if (-e "$cwd/package.json") { $pkg = "$cwd/package.json"; last; }
		$cwd = substr($cwd, 0, rindex($cwd, '/'));
	}

	if ($pkg) {
		my $pkgcontents = do{local(@ARGV,$/)=$pkg;<>};
		if ($pkgcontents =~ /"scripts"\s*:\s*{([\s\S]*?)}(,|$)/) {
			my @matches = ($1 =~ /"([^"]*)"\s*:/g);
			foreach (@matches) { $output .=  '.' . $_ . " --\n"; }
			chomp($output);
		}
	}
}

print $output;
