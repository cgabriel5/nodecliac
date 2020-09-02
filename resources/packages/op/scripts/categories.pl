#!/usr/bin/perl

# use strict;
# use warnings;
# use diagnostics;

my $dsl = $ARGV[0];
# my $last = $ENV{'NODECLIAC_LAST'};
# my ($flag, $skip, $eq, $value) = $last =~ /^(--?[^=]+)((=)(.*?))?$/;
my $flag = $ENV{'NODECLIAC_FLAG_NAME'};
my $eq = $ENV{'NODECLIAC_FLAG_EQSIGN'};
my $value = $ENV{'NODECLIAC_FLAG_VALUE'};

my %used;
my %categories = (
	'Login' => undef,
	'Secure Note' => undef,
	'Credit Card' => undef,
	'Identity' => undef,
	'Bank Account' => undef,
	'Database' => undef,
	'Driver License' => undef,
	'Email Account' => undef,
	'Membership' => undef,
	'Outdoor License' => undef,
	'Passport' => undef,
	'Reward Program' => undef,
	'Server' => undef,
	'Social Security Number' => undef,
	'Software License' => undef,
	'Wireless Router' => undef
);

# [https://stackoverflow.com/a/1817608]
# [http://www.mpihowto.com/index.php/perl/perl-built-in-functions/perl-functions-for-real-hashes/perl-delete-function]
my $q = substr($value, 0, 1);
my $isquoted = $q =~ tr/"'//;
if ($isquoted) {
	substr($value, 0, 1, ''); # Remove first quote.
	foreach $key (keys %categories) {
		delete $categories{$key};
		$categories{"$q$key$q"} = undef;
	}
} else {
	$q = '';
	foreach $key (keys %categories) {
		delete $categories{$key};
		$key =~ s/ /\\ /g;
		$categories{$key} = undef;
	}
}
my $href = \%categories;

if ($dsl) {
	print "__DSL__\n"; # Tell ac script it's a delimited separated list.

	if (!$value) {
		foreach $key (keys %{$href}) {
			delete $href->{$key};
			$href->{"$flag$eq$key"} = undef;
		}
	} else {
		my $del = ',';
		my @list = split($del, $value);
		for my $i (0 .. $#list) {
			my $cat = "$list[$i]";
			$cat =~ s/^\s+|\s+$//g;
			if ($isquoted) { $cat = "$q$cat$q"; }
			# [https://stackoverflow.com/a/24832274]
			if (exists($href->{$cat})) {
				delete $href->{$cat};
				$used{$cat} = undef;
			}
		}

		if (scalar(@list) == 1 && $value !~ /\s*${del}$/) {
			foreach $key (keys %{$href}) {
				delete $href->{$key};
				$href->{"$flag$eq$key"} = undef;
			}
			$href->{"!$flag$eq" . (keys %used)[0]} = undef;

		} else {
			my $litem = "";
			if (scalar(@list) != 1) {
				if ($value !~ /\s*${del}$/) { $litem = pop(@list); }
			}
			my $prefix = $q . join($del, @list) . $del;
			foreach $key (keys %{$href}) {
				delete $href->{$key};
				$key =~ s/^["']//;
				$href->{"$flag$eq$prefix$key"} = undef;
			}

			if (exists($used{"$q$litem$q"})) {
				$href->{"!$flag$eq$prefix$litem$q"} = undef;
			}
		}
	}
}

print join("\n", (keys %{$href}));
