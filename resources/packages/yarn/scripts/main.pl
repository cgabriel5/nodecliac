#!/usr/bin/perl

# use strict;
# use warnings;
# use diagnostics;

my $action = $ARGV[0];
my $useglobal = $ARGV[1];
my $cwd = $ENV{'PWD'};
my $hdir = $ENV{'HOME'};
my $input = $ENV{'NODECLIAC_INPUT_ORIGINAL'};
my $pkg = '';

if (!$useglobal) {
	# If a workspace use its location.
	if ($input =~ /^[ \t]*?yarn[ \t]+?workspace[ \t]+?([^ \t]+?)[ \t]+?.*/) { $cwd = "/$1"; }

	while ($cwd) {
		if (-e "$cwd/package.json") { $pkg = "$cwd/package.json"; last; }
		$cwd = substr($cwd, 0, rindex($cwd, '/'));
	}
} else {
	my @paths = (
		"$hdir/.config/yarn/global/package.json",
		"$hdir/.local/share/yarn/global/package.json",
		"$hdir/.yarn/global/package.json"
	);

	$pkg = '';
	foreach my $path (@paths) { if (-f $path) { $pkg = $path; last; } }
}

my %args;

if ($action eq 'run') {
	my $pkgcontents = do{local(@ARGV,$/)=$pkg;<>};
	if ($pkgcontents =~ /"scripts"\s*:\s*{([\s\S]*?)}(,|$)/) {
		my @matches = ($1 =~ /"([^"]*)"\s*:/g);
		foreach (@matches) { $args{"$_"} = undef; }
	}
} elsif ($action eq 'workspace') {
	my $workspaces_info = `LC_ALL=C yarn workspaces info -s 2> /dev/null`;
	my $args_count = $ENV{'NODECLIAC_ARG_COUNT'};

	if (($workspaces_info && $args_count <= 2) || ($workspaces_info && $args_count <= 3 && $ENV{'NODECLIAC_LAST_CHAR'})) {
		# Get workspace names.
		while ($workspaces_info =~ /"location":\s*"([^"]+)",/g) { $args{"$1"} = undef; }
	}
} else { # Remaining actions: remove|outdated|unplug|upgrade
	my $pkgcontents = do{local(@ARGV,$/)=$pkg;<>};
	my @matches = ($pkgcontents =~ /"(dependencies|devDependencies)"\s*:\s*{([\s\S]*?)}(,|$)/g);
	foreach my $match (@matches) {
		my @deps = ($match =~ /"([^"]*)"\s*:/g);
		foreach (@deps) { $args{"$_"} = undef; }
	}
}

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
