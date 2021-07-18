#!/usr/bin/perl

# When running, returns repo scripts to add to ACDEF and the modified CLI input.

# use strict;
# use warnings;
# use diagnostics;

my $input = $ARGV[0];
if ($input =~ /^[ \t]*?op[ \t]+?help[ \t](.*)/) { print "op $1"; }
