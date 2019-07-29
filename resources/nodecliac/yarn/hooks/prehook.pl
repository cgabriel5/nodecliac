#!/usr/bin/perl

# - Script will return repo scripts to add to ACDEF.
# - Script will return the modified CLI input.
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

# Get needed RegEx matches from CLI input.
my ($workspace_name, $cli_remainder) = $input =~ /^[ \t]*?yarn[ \t]+?workspace[ \t]+?([^ \t]+?)[ \t]+?(.*)/;

# ----- Input logic -----

# Check input with RegExp...
if ($cli_remainder) { $output = "yarn $cli_remainder"; }

# ----- ACDEF logic -----

# Only run when input is only the yarn command or yarn and completing a subcommand.
# [https://perldoc.perl.org/perlrequick.html]
if ($input =~ /^[ \t]*?yarn[ \t]+?([^ \t]*?)$/) {
	# Get arguments.
	# my $action = 'run';
	my $cwd = $ENV{'PWD'};
	# my $hdir = $ENV{'HOME'};

	# Get package.json paths/info.
	my $pkg = '';
	# my $field_type = 'object';

	# If no global parameter then look for local package.json.
	# [https://stackoverflow.com/a/19031736]
	# [http://defindit.com/readme_files/perl_one_liners.html]
	# [https://www.perlmonks.org/?node_id=1004245]
	# Get workspace name if auto-completing workspace.
	# [https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash]
	# If completing a workspace, reset CWD to workspace's location.
	if ($workspace_name) { $cwd .= "/$1"; }

	# Find package.json file path.
	# my $slash_index = -1;
	# my $l = length($cwd);
	while ($cwd) {
		# Set package.json file path.
		if (-f "$cwd/package.json") { $pkg = "$cwd/package.json"; last; }
		# Stop loop at node_modules directory.
		# if (-d "$cwd/node_modules") { last; }

		# Continuously chip away last level of PWD.
		# $cwd =~ s/\/((?:\\\/)|[^\/])+$//; # ((?:\\\/)|[^\/]*?)*$
		$cwd = substr($cwd, 0, rindex($cwd, '/'));

		# # Get last '/' (forward-slash) index.
		# $slash_index = rindex($cwd, '/');
		# # Once no slashes exist, stop loop.
		# # last if ($slash_index < 0);

		# # If path contains a slash remove last path plus the slash.
		# # Reset the length.
		# # [https://stackoverflow.com/a/43964356]
		# my $diff = $l - $slash_index; # Find amount of chars to chop.
		# $l -= $diff; # Reset string length.
		# # Remove n ending characters from last index (including slash).
		# foreach (0 .. $diff - 1) { chop($cwd); }
	}

	# package.json path has to exist.
	if ($pkg) {
		# Get script names and store arguments.
		# [https://www.perl.com/article/21/2013/4/21/Read-an-entire-file-into-a-string/]
		# [https://www.perlmonks.org/?node_id=1438]
		my $pkgcontents = do{local(@ARGV,$/)="$pkg";<>}; # Get package.json contents.
		if ($pkgcontents =~ /"scripts"\s*:\s*{([\s\S]*?)}(,|$)/) {
			my @matches = ($1 =~ /"([^"]*)"\s*:/g);
			# for my $i (0 .. $#matches) { # [https://stackoverflow.com/a/974819]
			# 	# Don't prefix a new line for the first script record.
			# 	$output .=  ($i ? "\n" : '') . ".$matches[$i] --";
			# }

			# [https://stackoverflow.com/a/974819]
			foreach (@matches) { $output .=  '.' . $_ . " --\n"; }
			# Remove last newline.
			chomp($output);
		}
	}
}

# Return output.
print $output;
