#!/usr/bin/perl

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get arguments.
my $action = $ARGV[0];
my $useglobal = $ARGV[1]; # Whether to use/look for global yarn package.json.
my $cwd = $ENV{'PWD'};
my $hdir = $ENV{'HOME'};
my $input = $ENV{'NODECLIAC_INPUT_ORIGINAL'};

# Get package.json paths/info.
my $pkg = '';
# my $field_type = 'object';

# If no global parameter then look for local package.json.
if (!$useglobal) {
	# [https://stackoverflow.com/a/19031736]
	# [http://defindit.com/readme_files/perl_one_liners.html]
	# [https://www.perlmonks.org/?node_id=1004245]
	# Get workspace name if auto-completing workspace.
	# [https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash]
	# If completing a workspace, reset CWD to workspace's location.
	if ($input =~ /^[ \t]*?yarn[ \t]+?workspace[ \t]+?([^ \t]+?)[ \t]+?.*/) { $cwd = "/$1"; }

	# Find package.json file path.
	while ($cwd) {
		# Set package.json file path.
		if (-e "$cwd/package.json") { $pkg = "$cwd/package.json"; last; }
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
my %args;

# Depending on provided action run appropriate logic...
if ($action eq 'run') {
	# Get script names and store arguments.
	my $pkgcontents = do{local(@ARGV,$/)=$pkg;<>}; # Get package.json contents.
	if ($pkgcontents =~ /"scripts"\s*:\s*{([\s\S]*?)}(,|$)/) {
		my @matches = ($1 =~ /"([^"]*)"\s*:/g);
		foreach (@matches) { $args{"$_"} = undef; }
	}
} elsif ($action eq 'workspace') {
	# Get workspaces info via yarn.
	my $workspaces_info = `LC_ALL=C yarn workspaces info -s 2> /dev/null`;
	# Get args count.
	my $args_count = $ENV{'NODECLIAC_ARG_COUNT'};

	if (($workspaces_info && $args_count <= 2) || ($workspaces_info && $args_count <= 3 && $ENV{'NODECLIAC_LAST_CHAR'})) {
		# Get workspace names.
		while ($workspaces_info =~ /"location":\s*"([^"]+)",/g) { $args{"$1"} = undef; }
	}
} else { # Note: Default remaining actions to the default to speed up checking (remove|outdated|unplug|upgrade).
	# Get (dev)dependencies.
	my $pkgcontents = do{local(@ARGV,$/)=$pkg;<>}; # Get package.json contents.
	# [https://stackoverflow.com/a/2304626]
	my @matches = ($pkgcontents =~ /"(dependencies|devDependencies)"\s*:\s*{([\s\S]*?)}(,|$)/g);
	foreach my $match (@matches) {
		my @deps = ($match =~ /"([^"]*)"\s*:/g);
		foreach (@deps) { $args{"$_"} = undef; }
	}
}

# Get environment variables.
my $last = $ENV{'NODECLIAC_LAST'};
my $lchar = $ENV{'NODECLIAC_LAST_CHAR'};
my $nchar = $ENV{'NODECLIAC_NEXT_CHAR'};

# Get environment variable containing used default positional arguments.
my $used = $ENV{'NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS'};
# $used =~ s/^\s+|\s+$//g; # Trim string.
chomp($used); # Remove trailing newline.
# Split string into individual items.
my @used_args = split(/[\n ]/, $used);

foreach my $uarg (@used_args) {
	if (exists($args{$uarg})) {
		delete $args{$uarg}; # Delete to re-add key + used modifier ('!').
		$args{"!$uarg"} = undef;
	}
}

# Prune arguments and return remaining.
# require "$hdir/.nodecliac/registry/yarn/scripts/prune.pl";
print join("\n", (keys %args));