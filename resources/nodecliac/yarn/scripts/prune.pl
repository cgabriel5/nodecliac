package ARGPruner;

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Function is provided the arguments to prune. Pruning consists of
# removing any already used arguments.
#
# Arguments:
#   0) The list (string) of arguments to purge.
# **NOTE: All other needed data is obtained from environment variables
# provided from nodecliac.
sub main {
	# Get passed in argument (i.e. script names, (dev)dependencies).
	my ($args) = @_;

	# Get environment variables.
	my $last = $ENV{'NODECLIAC_LAST'};
	my $lchar = $ENV{'NODECLIAC_LAST_CHAR'};
	my $nchar = $ENV{'NODECLIAC_NEXT_CHAR'};

	# Get environment variable containing used default positional arguments.
	my $used = $ENV{'NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS'};
	# Trim string.
	# $used =~ s/^\s+|\s+$//g;
	chomp($used);
	# Split string into individual items.
	my @used_args = split(/[\n ]/, $used);

	# Trim string.
	# $args =~ s/^\s+|\s+$//g;
	chomp($args);

	# Split string into individual items.
	my @items = split(/[\n ]/, $args);
	my %arguments; # This arguments hash will get pruned of used arguments.
	my $is_last_arg_valid = 0;
	# Add arguments to hashes.
	foreach my $arg (@items) {
		$arguments{$arg} = '';
		# Take advantage of loop to check if the last word is an existing arg.
		if ($arg eq $last) { $is_last_arg_valid = 1; }
	}

	# Remove used arguments from arguments list.
	# [https://perldoc.perl.org/perlfaq4.html#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f]
	foreach my $usedarg (@used_args) {
		if (exists($arguments{$usedarg})) { delete $arguments{$usedarg}; }
	}

	# If last char exists only return args starting with last word.
	if ($lchar) {
		foreach my $arg (keys %arguments) {
			if (index($arg, $last)) { delete $arguments{$arg}; }
		}
	}

	# Store final arguments (output).
	my $output = '';
	# Get final arguments list.
	my @final_args = (keys %arguments);

	# If no auto-completion arguments exist...
	if (!@final_args &&
		# ...and if there is no next char or the next char is a space...
		(!$nchar || $nchar eq ' ') &&
		# ...and if the last item is in the provided arguments array...
		$is_last_arg_valid
	) {
		$output = $last; # Add the currently last item to the completion items.
	} else {
		$output = join("\n", @final_args);
	}

	# Return the final output.
	return $output;
}

1;
