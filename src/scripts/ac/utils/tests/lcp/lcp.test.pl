use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin =~ s/tests\/lcp//r;
use LCP;

use JSON::MaybeXS qw(decode_json);
my $data = decode_json do{local(@ARGV,$/)="./data.json";<>};

print "\nCustoms\n";
my $i = 0;
for my $item ( @{$data->{customs}} ){
	my $res = LCP::lcp(\@{ $item }, 2, 2, 3, 3, 0, "--", "...", ('='));
	my @prefixes = @{ $res->{prefixes} };
	print $i + 1 . " " . @prefixes . " ";
	for my $prefix (@prefixes) { print "|$prefix|"; }
	print "\n";
	$i++;
};

print "\nDefaults\n";
$i = 0;
for my $item ( @{$data->{defaults}} ){
	my $res = LCP::lcp(\@{ $item });
	my @prefixes = @{ $res->{prefixes} };
	print $i + 1 . " " . @prefixes . " ";
	for my $prefix (@prefixes) { print "|$prefix|"; }
	print "\n";
	$i++;
};
