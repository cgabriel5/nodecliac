#!/usr/bin/perl

# This script's purpose will modify the acdef content by adding rows for
# provided script names. The final acdef output will be returned.
#
# Arguments:
#   0) The list (string) of script names.
# **NOTE: All other needed data is obtained from environment variables
# provided from nodecliac.

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get acdef from environment variables.
my $acdef = $ENV{'NODECLIAC_ACDEF'};

# Get passed in script names.
my $scriptnames = $ARGV[0];
# Trim string.
$scriptnames =~ s/^\s+|\s+$//g;
# Split string into individual items.
my @scripts = split(/\n/, $scriptnames);

# Store built output.
my $output = "\n";

# Remove already used items.
foreach my $script (@scripts) {
	# Build onto output.
	$output .= "\n.$script --";
}

# Return acdef + output.
print "$acdef$output";
