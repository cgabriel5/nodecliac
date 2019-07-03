#!/usr/bin/perl

# This script will modify the ACDEF content by adding rows for
# provided script names. The final ACDEF output will be returned.
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
my $acdef = $ARGV[1]; # Command's acdef file contents.

# Only run when input is only the yarn command or yarn and completing a subcommand.
# [https://perldoc.perl.org/perlrequick.html]
if ($input !~ /^[ \t]*yarn[ \t]+([a-zA-Z][-_a-zA-Z0-9]*)*$/) { exit; }

# Create main script file path.
my $mainscript = $ENV{"HOME"} . "/.nodecliac/registry/yarn/scripts/main.sh";

# Run main script to get script names.
my $scriptnames = `$mainscript run 2> /dev/null`;
# Trim string.
$scriptnames =~ s/^\s+|\s+$//g;

# Script names must exist to proceed.
if (!$scriptnames) { exit; }

# Split string into individual items.
my @scripts = split(/\n/, $scriptnames);

# Store ACDEF addon.
my $addon = "";
foreach my $script (@scripts) { $addon .= "\n.$script --"; }

# Return acdef + addon script name entries.
print "$acdef$addon";
