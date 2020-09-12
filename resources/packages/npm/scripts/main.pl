#!/usr/bin/perl

# use strict;
# use warnings;
# use diagnostics;

my $action = $ARGV[0];
my $useglobal = 0;
my $cwd = $ENV{'PWD'};
my $hdir = $ENV{'HOME'};
my $usedflags = $ENV{'NODECLIAC_USED_FLAGS'};
my $pkg = '';

my $used = $ENV{'NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS'};
chomp($used); # Remove trailing newline.
my @used_args = split(/[\n ]/, $used);

my $delimiter = "\$\\r\?\\n";
my @flags = split(/$delimiter/m, $usedflags);
for my $flag (@flags) {
	if ($flag eq "-g" || $flag eq "--global") {
		$useglobal = 1;
		last;
	}
}

if (!$useglobal) {
	while ($cwd) {
		if (-e "$cwd/package.json") { $pkg = "$cwd/package.json"; last; }
		$cwd = substr($cwd, 0, rindex($cwd, '/'));
	}

	my %args;

	if ($action eq 'run') {
		if ($pkg) {
			my $pkgcontents = do{local(@ARGV,$/)=$pkg;<>};
			if ($pkgcontents =~ /"scripts"\s*:\s*{([\s\S]*?)}(,|$)/) {
				my @matches = ($1 =~ /"([^"]*)"\s*:/g);
				foreach (@matches) { $args{"$_"} = undef; }
			}
		}
	} else { # Remaining actions: remove|outdated|unplug|upgrade
		if ($pkg) {
			my $pkgcontents = do{local(@ARGV,$/)=$pkg;<>};
			my @matches = ($pkgcontents =~ /"(?:dependencies|devDependencies)"\s*:\s*{([\s\S]*?)}(,|$)/g);
			foreach my $match (@matches) {
				my @deps = ($match =~ /"([^"]*)"\s*:/g);
				foreach (@deps) { $args{"$_"} = undef; }
			}
		}
	}

	foreach my $uarg (@used_args) {
		if (exists($args{$uarg})) {
			delete $args{$uarg};
			$args{"!$uarg"} = undef;
		}
	}

	print join("\n", (keys %args));

} else {
	my $rootdir = "$hdir/.nodecliac/registry/npm/.rootdir";
	if (! -e $rootdir) {
		open(FH, '>', $rootdir) or die;
		# [https://stackoverflow.com/a/5926706]
		# [https://flaviocopes.com/where-npm-install-packages/]
		print FH `npm root -g`;
		close(FH);
	}

	my $root = do{local(@ARGV,$/)=$rootdir;<>};
	$root=~ s/\s+$//;

	# [https://stackoverflow.com/a/5751949]
	# [https://stackoverflow.com/a/2912084]
	# [https://alvinalexander.com/blog/post/perl/how-process-every-file-directory-perl/]
	# [https://stackoverflow.com/a/37786730]
	opendir(DIR, $root) or exit;
	while (my $name = readdir(DIR)) {
		if (-d "$root/$name" && $name !~ /^\.{1,2}$/) {
			my $pattern = '^' . $name . '$';
			print (($used =~ /$pattern/m ? '!' : '') . "$name\n");
		}
	}
	closedir(DIR);
}
