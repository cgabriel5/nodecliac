package ARGPruner;

# This script's purpose is to return a pruned list of arguments. In essence,
# a string of arguments is provided and from those arguments all used
# arguments are excluded to return all unused arguments.
#
# Arguments:
#   0) The list (string) of arguments to purge.
# **NOTE: All other needed data is obtained from environment variables
# provided from nodecliac.

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

sub main {
	# Get environment variables.
	my $last = $ENV{'NODECLIAC_LAST'};
	my $lchar = $ENV{'NODECLIAC_LAST_CHAR'};
	my $nchar = $ENV{'NODECLIAC_NEXT_CHAR'};

	# Get environment variable containing used default positional arguments.
	my $used = $ENV{'NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS'};
	# Trim string.
	$used =~ s/^\s+|\s+$//g;
	# Split string into individual items.
	my @used_args = split(/[\n ]/, $used);

	# Get passed in argument (i.e. script names, (dev)dependencies).
	my ($args) = @_;
	# Trim string.
	$args =~ s/^\s+|\s+$//g;
	# Split string into individual items.
	my @arguments = split(/[\n ]/, $args);

	# Array will store unused items.
	my @cleaned_args = ();

	# Remove already used items.
	foreach my $arg (@arguments) {
		# If the argument is in the used_args array then skip it.
		# [https://stackoverflow.com/a/20570606]
		if (!grep(/^$arg$/, @used_args)) {
			# If a last character exists then we need only return completion
			# items that start with the last word.
			if ($lchar) {
				if (index($arg, $last) == 0) { push(@cleaned_args, $arg);}
			}
			# ..else return all completion items.
			else {
				push(@cleaned_args, $arg);
			}
		}
	}

	# Return unused items string.
	my $final_args = join("\n", @cleaned_args);

	# If no completion items exist do some final checks...
	if (
		# If no auto-completion arguments exist...
		!$final_args &&
		# ...and if there is no next char or the next char is a space...
		(!$nchar || $nchar eq " ") &&
		# ...and if the last item is in the provided arguments array...
		grep(/^$last$/, @arguments)
	) {
		# Add the currently last item to the completion items.
		print "\n$last";
	}

	# Return unused items string.
	return "$final_args";
}

1;
