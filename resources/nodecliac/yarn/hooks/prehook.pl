#!/usr/bin/perl

# - This script will modify the ACDEF content by adding rows for
# provided script names. The final ACDEF output will be returned.
# - This script will modify the CLI input. The final, modified input
# will be returned.
#
# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get arguments.
my $input = $ARGV[0]; # Original (complete) CLI input. ($NODECLIAC_INPUT_ORIGINAL)

# Store output.
my $output = "\n";

# ----- Input logic -----

# Check input with RegExp...
if ($input =~ /^([ \t]*yarn)([ \t]+workspace[ \t]+[^ \t]*[ \t]{1,})(.*)/) { $output = "$1 $3"; }

# ----- ACDEF logic -----

# Only run when input is only the yarn command or yarn and completing a subcommand.
# [https://perldoc.perl.org/perlrequick.html]
if ($input =~ /^[ \t]*yarn[ \t]+([^ \t]*)*$/) {
	# Get arguments.
	my $action = "run";
	my $pwd = $ENV{'PWD'}; # → Whether to use/look for global yarn package.json.
	my $hdir = $ENV{'HOME'}; # → Whether to use/look for global yarn package.json.

	# Get package.json paths/info.
	my $cwd = $pwd; # → Whether to use/look for global yarn package.json.
	my $package_dot_json = "";
	my $field_type = "object";
	my $workspace = "";

	# If no global parameter then look for local package.json.
	# [https://stackoverflow.com/a/19031736]
	# [http://defindit.com/readme_files/perl_one_liners.html]
	# [https://www.perlmonks.org/?node_id=1004245]
	# Get workspace name if auto-completing workspace.
	# [https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash]
	if ($input =~ /^[ \t]*yarn[ \t]+workspace[ \t]+([^ \t]*)[ \t]*.*/) { $workspace = $1; }

	# If completing a workspace, reset CWD to workspace's location.
	if ($workspace) { $cwd = "$pwd/$workspace"; }

	# Find package.json file path.
	while ($cwd) {
		# Set package.json file path.
		if (!$package_dot_json && -f "$cwd/package.json") {
			$package_dot_json = "$cwd/package.json"; last;
		}

		# Stop loop at node_modules directory.
		if (-d "$cwd/node_modules") { last; }

		# Continuously chip away last level of PWD.
		$cwd = $cwd =~ s/\/((?:\\\/)|[^\/])+$//r; # ((?:\\\/)|[^\/]*?)*$
	}

	# Get script names and store arguments.
	# [https://www.perl.com/article/21/2013/4/21/Read-an-entire-file-into-a-string/]
	# [https://www.perlmonks.org/?node_id=1438]
	my $pkgcontents = do{local(@ARGV,$/)="$package_dot_json";<>}; # Get package.json contents.
	if ($pkgcontents =~ /"scripts"\s*:\s*{([\s\S]*?)}(,|$)/) {
		my @matches = ($1 =~ /"([^"]*)"\s*:\s*"/g);
		foreach my $match (@matches) { $output .= "\n.$match --"; }
	}
}

# Return output.
print "$output";
