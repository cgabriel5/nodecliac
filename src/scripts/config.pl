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

# Loop over settings to get their values.
for (my $i = 0; $i < $l; $i++) {
	my $setting = $settings[$i];

	# Get config value.
	my $value = "";
	my $pattern = '^\@' . $setting . '\s*\=\s*(.*)$';
	if ($config =~ /$pattern/m) {
		if ($1) { $value = $1; }
	}

	# Custom logic for the 'default' setting.
	if ($setting eq "default") {
		# Allowed comp-option values.
		# [http://www.gnu.org/software/bash/manual/bash.html#Programmable-Completion]
		# [https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html]
		my $compopts = " bashdefault default dirnames filenames noquote nosort nospace plusdirs false ";
		my $co_value = "default";

		# If a value was found check if it's allowed.
		if ($value && index($compopts, $value) != -1) { $value = $co_value; }
		# If no value was found then set to default value.
		if (!$value) { $value = $co_value; }
	}

	# Add value to output string.
	$output .= "[$i] => $value\; ";
}

# Return values.
print "$output";

