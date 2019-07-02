#!/usr/bin/perl

# - This script will modify the CLI input and save the result to
# hooks/.input.data.
# - This script will modify the ACDEF file contents and save the result to
# hooks/.acdef.data.
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

# Get needed environment variable(s).
my $hdir = $ENV{"HOME"};
my $input = $ENV{'NODECLIAC_INPUT'};
# my $acdef = $ENV{'NODECLIAC_ACDEF'};
my $maincommand = $ENV{'NODECLIAC_MAIN_COMMAND'};

# Hook directory path.
my $commanddir = "$hdir/.nodecliac/registry/$maincommand";
my $hookdir = "$commanddir/hooks";

# Store applied modification indicators.
my $output = "";

# Generate/save new CLI input contents...

# Check input with RegExp...
if ($input =~ /^([ \t]*yarn)([ \t]+workspace[ \t]+[a-zA-Z][-_a-zA-Z0-9]*[ \t]{1,})(.*)/) {
	system "echo \"$1 $3\" > $hookdir/.input.data"; # Save output to file.
	$output .= "input;"; # Set indicator.
}

# Generate/save new acdef contents...

# Check last modified time. [https://stackoverflow.com/a/45955855]
my $mmod = `stat -c %Y "\$PWD/package.json"`;
$mmod =~ s/\n+$//g; # Trim newlines from output.

# If the mmod time file does not exist then create it.
my $mmodfile = "$hookdir/.mmod.data";
if (not -e $mmodfile) {
	system "echo \"$mmod\" > $mmodfile";
} else {
	# Since it exists check the mmod time against the saved file time.
	my $timestamp = `cat $mmodfile`; # Get file timestamp.
	$timestamp =~ s/\n+$//g; # Trim newlines from output.

	# If package.json's last modified time is the same as the stored value
	# then package.json has not been modified so no need to get scripts.
	if ($timestamp eq $mmod) { exit; }
}

# Create main script file path.
my $mainscript = "$commanddir/scripts/main.sh";

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

# Save new acdef + addon script name entries to file.
# [https://stackoverflow.com/a/10947977]
# system "cat $commanddir/$maincommand.acdef <(echo \"$addon\")"

# [https://stackoverflow.com/a/11401845]
system "a=\"\$(cat $commanddir/$maincommand.acdef)\";echo \"\$a$addon\" > $hookdir/.acdef.data";
$output .= "acdef;"; # Set indicator.

print "$output";
