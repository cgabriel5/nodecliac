#!/usr/bin/perl

# This script will modify the CLI input. The final, modified input
# will be returned.
#
# Arguments:
#   -- none
# **NOTE: All other needed data is obtained from environment variables
# provided from nodecliac.

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get arguments.
my $input = $ARGV[0]; # Original (complete) CLI input.
# Store output.
my $output = "";

# Check input with RegExp...
if ($input =~ /^([ \t]*yarn)([ \t]+workspace[ \t]+[a-zA-Z][-_a-zA-Z0-9]*[ \t]{1,})(.*)/) { $output = "$1 $3"; }

# Return output.
print "$output";
