#!/usr/bin/perl

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get command name from sourced passed-in argument.
# my $maincommand = $ARGV[0];
# Get the config definitions file.
my $config = $ARGV[0];
# Get config setting to find.
# my $setting = $ARGV[1];
my $output = "";

# Split settings string.
my @settings = split(";", $ARGV[1]);
my $l = scalar(@settings);

# Allowed comp-option values.
# [http://www.gnu.org/software/bash/manual/bash.html#Programmable-Completion]
# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
my $def_compopts = " bashdefault default dirnames filenames noquote nosort nospace plusdirs false ";
my $def_default = "default";

# Loop over settings to get their values.
for (my $i = 0; $i < $l; $i++) {
	my $setting = $settings[$i];

	# Get config value.
	my $value = "";
	my $pattern = '^\@' . $setting . '\s*\=\s*(.*)$';
	# Get setting's value.
	if ($config =~ /$pattern/m) { if ($1) { $value = $1; } }

	# If value is quoted, unquote it.
	if ($value =~ /^("|').*\1$/) { $value = substr($value, 1, -1); }

	# Custom logic for the 'default' setting.
	if ($setting eq "default") {
		if ($value) {
			# If value is not allowed reset to default value.
			if (index($def_compopts, $value) == -1) { $value = $def_default; }
		} else {
			# If no value was found then set to default value.
			$value = $def_default;
		}
	}

	# Add value to output string.
	$output .= "[$i] => $value\; ";
}

# Return values.
print "$output";

