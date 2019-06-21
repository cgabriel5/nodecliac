#!/usr/bin/perl

# This script's purpose will modify the ACDEF content by adding rows for
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

# Create main script file path.
my $mainscript = glob("~/.nodecliac/commands/yarn/scripts/main.sh");

# Run main script to get script names.
my $scriptnames = `bash -c \"$mainscript run\" 2> /dev/null`;
# Trim string.
$scriptnames =~ s/^\s+|\s+$//g;

# Script names must exist to proceed.
if (!$scriptnames) { exit; }

# Split string into individual items.
my @scripts = split(/\n/, $scriptnames);

# Get ACDEF from environment variables.
my $acdef = $ENV{'NODECLIAC_ACDEF'};

# Store ACDEF addon.
my $addon = "";
foreach my $script (@scripts) { $addon .= "\n.$script --"; }

# Return acdef + addon script name entries.
print "$acdef$addon";
