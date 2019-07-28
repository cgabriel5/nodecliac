#!/usr/bin/perl

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get arguments.
my $action = $ARGV[0];
my $pwd = $ENV{'PWD'}; # → Whether to use/look for global yarn package.json.
my $hdir = $ENV{'HOME'}; # → Whether to use/look for global yarn package.json.
my $useglobal_pkg = $ARGV[1]; # → Whether to use/look for global yarn package.json.
my $input = $ENV{'NODECLIAC_INPUT_ORIGINAL'};

# Get arguments.
my $cwd = $pwd; # → Whether to use/look for global yarn package.json.
my $pkg = '';
# my $field_type = 'object';

# If no global parameter then look for local package.json.
if (!$useglobal_pkg) {
	# [https://stackoverflow.com/a/19031736]
	# [http://defindit.com/readme_files/perl_one_liners.html]
	# [https://www.perlmonks.org/?node_id=1004245]
	# Get workspace name if auto-completing workspace.
	# [https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash]
	# If completing a workspace, reset CWD to workspace's location.
	if ($input =~ /^[ \t]*yarn[ \t]+workspace[ \t]+([^ \t]*)[ \t]*.*/) { $cwd = "$pwd/$1"; }

	# Find package.json file path.
	while ($cwd) {
		# Set package.json file path.
		if (-f "$cwd/package.json") { $pkg = "$cwd/package.json"; last; }
		# Stop loop at node_modules directory.
		if (-d "$cwd/node_modules") { last; }

		# Continuously chip away last level of PWD.
		$cwd =~ s/\/((?:\\\/)|[^\/])+$//; # ((?:\\\/)|[^\/]*?)*$
	}
} else { # Else look for global yarn package.json.
	# Global lookup file paths.
	my @paths = (
		"$hdir/.config/yarn/global/package.json",
		"$hdir/.local/share/yarn/global/package.json",
		"$hdir/.yarn/global/package.json"
	);

	# Default to empty string if no global file exists.
	$pkg = '';

	# Loop over paths until one is found, if at all.
	foreach my $path (@paths) { if (-f $path) { $pkg = $path; last; } }
}

# Store action arguments for later pruning.
my $args = '';

# Depending on provided action run appropriate logic...
if ($action eq 'run') {
	# Get script names and store arguments.
	my $pkgcontents = do{local(@ARGV,$/)="$pkg";<>}; # Get package.json contents.
	if ($pkgcontents =~ /"scripts"\s*:\s*{([\s\S]*?)}(,|$)/) {
		my @matches = ($1 =~ /"([^"]*)"\s*:/g);
		foreach my $match (@matches) { $args .= "\n$match"; }
	}
} elsif ($action eq 'workspace') {
	# Get workspaces info via yarn.
	my $workspaces_info = `LC_ALL=C yarn workspaces info -s 2> /dev/null`;
	# Get args count.
	my $args_count = $ENV{'NODECLIAC_ARG_COUNT'};

	if (($workspaces_info && $args_count <= 2) || ($workspaces_info && $args_count <= 3 && $ENV{'NODECLIAC_LAST_CHAR'})) {
		# Get workspace names.
		while ($workspaces_info =~ /"location":\s*"([^"]+)",/g) { $args .= "$1\n"; }
	}
} else { # Note: Default remaining actions to the default to speed up checking (remove|outdated|unplug|upgrade).
	# Get (dev)dependencies.
	my $pkgcontents = do{local(@ARGV,$/)="$pkg";<>}; # Get package.json contents.
	# [https://stackoverflow.com/a/2304626]
	my @matches = ($pkgcontents =~ /"(dependencies|devDependencies)"\s*:\s*{([\s\S]*?)}(,|$)/g);
	foreach my $match (@matches) {
		my @deps = ($match =~ /"([^"]*)"\s*:/g);
		foreach my $dep (@deps) { $args .= "$dep\n"; }
	}
}

# Prune arguments and return remaining.
require "$hdir/.nodecliac/registry/yarn/scripts/prune.pl";
print("\n", ARGPruner::main($args));
