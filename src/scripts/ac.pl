#!/usr/bin/perl
# ------------- ^Use '-d:NYTProf' flag to profile script.

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get environment variables.
# Get user's home directory.
# [https://stackoverflow.com/a/1475447]
# [https://stackoverflow.com/a/1475396]
# [https://stackoverflow.com/a/4045032]
# [https://stackoverflow.com/a/4043831]
# [https://stackoverflow.com/a/18123004]
# my $hdir = glob('~'); # ← Slowest...
# my $hdir = `echo "\$HOME"`; # ← Less slow...
# [https://stackoverflow.com/q/1475357]
my $hdir = $ENV{'HOME'}; # ← Fastest way but is it reliable?

# Get arguments.
my $oinput = $ARGV[0]; # Original unmodified CLI input.
my $cline = $ARGV[1]; # CLI input (could be modified via prehook).
my $cpoint = int($ARGV[2]); # Caret index when [tab] key was pressed.
my $maincommand = $ARGV[3]; # Get command name from sourced passed-in argument.
my $acdef = $ARGV[4]; # Get the acdef definitions file.

# # Get the command's ACDEF file.
# my $acdefpath = "$hdir/.nodecliac/registry/$maincommand/$maincommand.acdef";
# # If the ACDEF file does not exist then exit script.
# exit if (not -f $acdefpath);
# my $acdef = do{local(@ARGV,$/)="$acdefpath";<>}; # Get the acdef definitions file.

# Vars.
my @args = ();
my $last = '';
my $elast_ptn = ''; # Escaped last word pattern.
my $type = '';
my %usedflags;
my @foundflags = ();
my @completions = ();
my $commandchain = '';
my $lastchar = substr($cline, $cpoint - 1, 1); # Character before caret.
my $nextchar = substr($cline, $cpoint, 1); # Character after caret.
my $cline_length = length($cline); # Original input's length.
my $isquoted = 0;
my $autocompletion = 1;
my $input = substr($cline, 0, $cpoint); # CLI input from start to caret index.
my $input_remainder = substr($cline, $cpoint, -1); # CLI input from caret index to input string end.

# Vars to be used for storing used default positional arguments.
my $used_default_pa_args = '';
my $collect_used_pa_args = '';

# # Store hook scripts paths.
# my $hpaths = '';

# Set environment vars so command has access.
my $prefix = 'NODECLIAC_';

# RegExp Patterns: [https://stackoverflow.com/a/953076]
my $flgopt = qr/-{1,2}[-.a-zA-Z0-9]*\=/; # "--flag/-flag="
my $flgoptvalue = qr/^-{1,2}[a-zA-Z0-9]*\=\*?.{1,}/; # "--flag/-flag=value"
my $flagcommand = qr/^-{1,2}[a-zA-Z0-9]*\=\*?\$\((.{1,})\)$/; # "--flag/-flag=$("<COMMAND-STRING>")"

# # RegExp Patterns:
# # my $flgopt = '-{1,2}[-.a-zA-Z0-9]*='; # "--flag/-flag="
# my $flagstartr = '^-{1,2}[a-zA-Z0-9]([-.a-zA-Z0-9]{1,})?\=\*?'; # "--flag/-flag=*"
# # my $flgoptvalue = $flagstartr . '.{1,}$'; # "--flag/-flag=value"
# my $commandstr = '\$\((.{1,})\)$'; # $("<COMMAND-STRING>")
# my $flagcommand = $flagstartr . $commandstr; # "--flag/-flag=$("<COMMAND-STRING>")"

# # Log local variables and their values.
# sub __debug {
# 	print "\n";
# 	print "  commandchain: '$commandchain'\n";
# 	print "          last: '$last'\n";
# 	print "         input: '$input'\n";
# 	print "  input length: '$cline_length'\n";
# 	print "   caret index: '$cpoint'\n";
# 	print "      lastchar: '$lastchar'\n";
# 	print "      nextchar: '$nextchar'\n";
# 	print "      isquoted: '$isquoted'\n";
# 	print "autocompletion: '$autocompletion'\n";
# }

# Return provided arrays length.
#
# @param {array} 1) - The array's reference.
# @return {number} - The array's size.
#
# @resource [https://perlmaven.com/passing-two-arrays-to-a-function]
sub __len {
	# Get arguments.
	my ($array_ref) = @_;
	# Dereference and use array.
	my @array = @{ $array_ref };

	# [https://alvinalexander.com/blog/post/perl/how-determine-size-number-elements-length-perl-array]
	# [https://stackoverflow.com/questions/7406807/find-size-of-an-array-in-perl]
	return $#array + 1; # scalar(@array);
}

# Global flag only to be used for __dupecheck function.
my %__dc_multiflags;

# Check whether provided flag is already used or not.
#
# @param {string} 1) - The flag to check.
# @return {boolean} - True if duplicate. Else false.
sub __dupecheck {
	# Get provided flag arg.
	my (
		$flag,
		$flag_fkey,
		$flag_isbool,
		$flag_eqsign,
		$flag_multif,
		$flag_value
	) = @_;

	# If used flags hash is empty, breakdown used flags and populate hash.
	if (!%usedflags) {
		# [https://perlmaven.com/multi-dimensional-hashes]
		foreach my $uflag (@foundflags) {
			# Breakup last word into flag/value.
			my @matches = $uflag =~ /^([^=]+)((?:=\*?)(.*))?/;
			# Default to empty string if no match.
			# [https://perlmaven.com/how-to-set-default-values-in-perl]
			my $uflag_fkey = $matches[0] // '';
			my $uflag_value = $matches[2] // '';

			# Store flag key and its value in hashes.
			# [https://perlmaven.com/multi-dimensional-hashes]
			$usedflags{$uflag_fkey}{$uflag_value} = 1;
		}
	}

	# Var boolean.
	my $dupe = 0;

	# If its a multi-flag then let it through.
	if (exists($__dc_multiflags{$flag_fkey})) {
		$dupe = 0;

		# Although a multi-starred flag, check if value has been used or not.
		if (exists($usedflags{$flag_fkey}{$flag_value})) { $dupe = 1; }

	} elsif (!$flag_eqsign) { # Valueless flag dupe check.

		# Check for --flag (no-value) and --flag=<Value> (with value).
		if (exists($usedflags{$flag_fkey})) { $dupe = 1; }

	} else { # Flag with value dupe check.
		# Count substring occurrences: [https://stackoverflow.com/a/9538604]
		# Dereference before use: [https://stackoverflow.com/a/37438262]
		my $flag_values = $usedflags{$flag_fkey};
		my $count = (keys %$flag_values);

		# More than 1 occurrence flag has been used.
		if ($count > 0) { $dupe = 1; }

		# If there is exactly 1 occurrence and the flag matches the
		# RegExp pattern we undupe flag as the 1 occurrence is being
		# completed (i.e. a value is being completed).
		if ($count == 1 && $flag =~ $flgoptvalue) { $dupe = 0; }
	}

	# Return dupe boolean result.
	return $dupe;
}

# Check whether string is left quoted (i.e. starts with a quote).
#
# @param {string} 1) - The string to check.
# @return {boolean} - True means it's left quoted.
sub __is_lquoted {
	# Get first character's numerical value.
	my $res = ord($_[0]);
	return ($res == 34 || $res == 39); # Single quote: 39, double quote: 34.
}

# Get last command in chain: 'mc.sc1.sc2' → 'sc2'
#
# @param {string} 1) - The row to extract command from.
# @param {number} 2) - The chain replacement type.
# @return {string} - The last command in chain.
sub __last_command {
	# Get arguments.
	my ($row, $type, $lchain) = @_;

	# Extract command chain from row.
	# ($row) = $row =~ /^[^ ]*/g;
	if ($row =~ /^([^ ]*)/) { $row = $1; }

	# Chain replacement depends on completion type.
	if ($type == 2) {
		# # Get the last command in chain.
		# my @cparts = split(/(?<!\\)\./, $row);
		# $row = pop(@cparts);

		# Get the last command in chain.
		$row = (split(/(?<!\\)\./, $row))[-1];

		# Slower then split/pop^.
		# if ($row =~ /((?!\.)((?:\\\.)|[^\.])+)$/) { $row = $1; }
	} else {
		$row = substr($row, $lchain + 1, length($row));
		# $row =~ s/$commandchain\.//;
	}

	# Extract next command in chain.
	my $lastcommand;
	if ($row =~ /^([^\s]*)(?=(?<!\\)\.)/) { $lastcommand = $1; }
	$lastcommand //= $row;

	# Remove any slashes from command.
	if (__includes($lastcommand, "\\")) { $lastcommand =~ s/\\//; }

	return $lastcommand;
}

# Check whether string starts with a hyphen.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means it starts with a hyphen.
#
# @resource [https://stackoverflow.com/a/34951053]
# @resource [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
sub __starts_with_hyphen { return ord($_[0]) == 45; }

# Check whether string contains provided substring.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means substring is found in string.
sub __includes { return index($_[0], $_[1]) + 1; }

# # Removes duplicate values from provided array.
# #
# # @param {string} 1) - The provided array.
# # @return {undefined} - Nothing is returned.
# #
# # @resource [https://stackoverflow.com/a/7657]
# sub __unique {
# 	my %seen;
# 	grep(!$seen{$_}++, @_);
# }

# Checks whether the provided string is a valid file or directory.
#
# @param {string} 1) - The string to check.
# @return {number} - 0 or 1 to represent boolean.
#
# Test with following commands:
# $ nodecliac uninstall subcmd subcmd noncmd ~ --
# $ nodecliac add ~ --
# $ nodecliac ~ --
sub __is_file_or_dir {
	# Get arguments.
	my ($item) = @_;

	# If arg contains a '/' sign check if it's a path. If so let it pass.
	return (__includes($item, '/') || $item eq '~');
	# $item =~ s/^~/$hdir/; # Expand tilde in path.

	# With tilde expanded, check if string is a path.
	# return (-e $item || -d $item) ? 1 : 0;
	# return (-e $item) ? 1 : 0;
}

# Escape '\' characters and replace unescaped slashes '/' with '.' (dots)
#     command strings
#
# @param {string} 1) - The item (command) string to escape.
# @return {string} - The escaped item (command) string.
sub __normalize_command {
	# Get arguments.
	my ($item) = @_;

	# If string is a file/directory then return.
	if (__is_file_or_dir($item)) { return $item; }

	# Chain replacements: [https://stackoverflow.com/a/43007999]
	$item = $item =~ s/\./\\\\./r # Escape dots.
				  =~ s/([^\\]|^)\//$1\./r; # Replace unescaped '/' with '.' dots.

	# Finally, validate that only allowed characters are in string.
	# tr///c does not do any variable interpolation do character sets need
	# to be hardcoded: [https://www.perlmonks.org/?node_id=445971]
	# [https://stackoverflow.com/a/15534516]
	if ($item =~ tr/-._:\\a-zA-Z0-9//c) { exit; }

	# Returned normalized item string.
	return $item;
}

# Validates whether command/flag (--flag) only contain valid characters.
#     If word command/flag contains invalid characters the script will
#     exit. In turn, terminating auto completion.
#
# @param {string} 1) - The word to check.
# @return {string} - The validated argument.
sub __validate_flag {
	# Get arguments.
	my ($item, $type) = @_;

	# If string is a file/directory then return.
	if (__is_file_or_dir($item)) { return $item; }

	# # Determine what matching pattern to use (command/flag).
	# my $pattern = ($type eq 'command') ? '[^-_.:a-zA-Z0-9\\\/]+' : '[^-_a-zA-Z0-9]+';
	# # Exit script if invalid characters are found (failed RegExp).
	# if ($item =~ /$pattern/) { exit; }

	# Finally, validate that only allowed characters are in string.
	# Determine character list to use (command or flag).
	# tr///c does not do any variable interpolation do character sets need
	# to be hardcoded: [https://www.perlmonks.org/?node_id=445971]
	# [https://stackoverflow.com/a/15534516]
	if ($item =~ tr/-_a-zA-Z0-9//c) { exit; }

	# Return word.
	return $item;
}
# Look at __validate_flag for function details.
sub __validate_command {
	my ($item, $type) = @_;
	if (__is_file_or_dir($item)) { return $item; }
	if ($item =~ tr/-._:\\a-zA-Z0-9//c) { exit; }
	return $item;
}

# Parse and run command-flag (flag) or default command chain command
#     (commandchain).
#
# @param {string} 1) - The command to run in string.
# @return {null} - Nothing is returned.
sub __execute_command {
	# Get arguments.
	my ($command_str, $flags, $last_fkey) = @_;

	# Unescape pipe chars (better if unescaped args individually?).
	$command_str =~ s/\\\|/\|/g;

	# Cache captured string command.
	my @arguments = __paramparse($command_str);
	my $args_count = pop(@arguments);

	# Set defaults.
	my $command = $arguments[0];
	# By default command output will be split lines.
	my $delimiter = "\$\\r\?\\n";

	# 'bash -c' with arguments documentation:
	# [https://stackoverflow.com/q/26167803]
	# [https://unix.stackexchange.com/a/144519]
	# [https://stackoverflow.com/a/1711985]

	# Start creating command string. Will take the
	# following form: `$command 2> /dev/null`
	my $cmd = substr($command, 1, -1); # Remove start/end quotes.

	# Only command and delimiter.
	if ($args_count > 1) {
		# print last element
		# $cdelimiter = $arguments[-1];
		my $cdelimiter = pop(@arguments);

		# Set custom delimiter if provided. To be
		# provided it must be more than 2 characters.
		# Meaning more than the 2 quotes.
		if (length($cdelimiter) >= 2) {
			# [https://stackoverflow.com/a/5745667]
			$delimiter = substr($cdelimiter, 1, -1);
		}

		# Reduce arguments count by one since we
		# popped off the last item (the delimiter).
		$args_count -= 1;

		# Add arguments to command string.
		for (my $i = 1; $i < $args_count; $i++) {
			# Cache argument.
			my $arg = $arguments[$i];

			# Run command if '$' is prefix to string.
			if ($arg =~ /^\$/) {
				# Remove '$' command indicator.
				$arg = substr($arg, 1);
				# Get the used quote type.
				my $quote_char =  substr($arg, 0, 1);

				# Remove start/end quotes.
				$arg = substr($arg, 1, -1);

				# Run command and append result to command string.
				my $cmdarg = "$arg 2> /dev/null";
				$cmd .= " $quote_char" . `$cmdarg` . $quote_char;

				# # If the result is empty after
				# # trimming then do not append?
				# my $result = `$cmdarg`;
				# if ($result =~ s/^\s*|\s*$//rg) {}
			} else {
				# Append non-command argument to
				# command string.
				$cmd .= " $arg";
			}
		}
	}

	# Close command string. Suppress any/all errors.
	$cmd .= ' 2> /dev/null';

	# Reset command string.
	$command = $cmd;

	# Run command. Add an or logical statement in case
	# the command returns nothing or an error is return.
	# [https://stackoverflow.com/a/3854742]
	# [https://stackoverflow.com/a/15678831]
	# [https://stackoverflow.com/a/9784016]
	# [https://stackoverflow.com/a/3201234]
	# [https://stackoverflow.com/a/3374285]
	# [https://stackoverflow.com/a/11231972]

	# Set all environment variables to access in custom scripts.
	__set_envs();

	# Run the command.
	my $lines = `$command`;
	# Note: command_str (the provided command string) will
	# be injected as is. Meaning it will be provided to
	# 'bash' with the provided surrounding quotes. User
	# needs to make sure to properly use and escape
	# quotes as needed. ' 2> /dev/null' will suppress
	# all errors in the event the command fails.

	# Unset environment vars once command is ran.
	# [https://stackoverflow.com/a/8770380]
	# Is this needed? For example, unset NODECLIAC_INPUT:
	# delete $ENV{"${prefix}INPUT"};

	# By default if the command generates output split
	# it by lines. Unless a delimiter was provided.
	# Then split by custom delimiter to then add to
	# flags array.
	if ($lines) {
		# Trim string if using custom delimiter.
		if ($delimiter ne "\$\\r\?\\n") {
			# [https://perlmaven.com/trim]
			$lines =~ s/^\s+|\s+$//g;
		}

		# Split output by lines.
		# [https://stackoverflow.com/a/4226362]
		my @lines = split(/$delimiter/m, $lines);

		# Run logic for command-flag command execution.
		if ($type eq 'flag') {
			# Add each line to flags array.
			foreach my $line (@lines) {
				# # Remove starting left line break in line,
				# # if it exists, before adding to flags.
				# if ($delimiter eq "\$") {
				# 	$line =~ s/^\n//;
				# }

				# Line cannot be empty.
				if ($line) {
					# Finally, add to flags array.
					push(@$flags, $last_fkey . "=$line");
				}
			}
		}
		# Run logic for default command chain commands.
		else {
			# Add each line to completions array.
			foreach my $line (@lines) {
				# Line cannot be empty.
				if ($line) {
					if ($last) {
						# When last word is present only
						# add words that start with last
						# word.

						# Since we are completing a command we only
						# want words that start with the current
						# command we are trying to complete.
						if ($line =~ /$elast_ptn/) {
							# Finally, add to flags array.
							push(@completions, $line);
						}
					} else {
						# Finally, add to flags array.
						push(@completions, $line);
					}
				}
			}
		}
	}

	return;
}

# Parse string command flag ($("")) arguments.
#
# @param  {string} 1) input - The string command-flag to parse.
# @return {string} - The cleaned command-flag string.
sub __paramparse {
	# Get arguments.
	my ($input) = @_;

	# Parse command string to get individual arguments. Things to note: each
	# argument is to be encapsulated with strings. User can decide which to
	# use, either single or double. As long as their contents are properly
	# escaped.
	my @arguments = ();
	my $argument = '';
	my $cmdstr_length = length($input);
	my $state = 0; # Start closed.
	my $quote_type = '';
	my $args_count = 0;

	# Return empty string when input is empty.
	if (!$input || !$cmdstr_length) {
		# Push 0 for arg count to array.
		push(@arguments, 0);
		return @arguments;
	}

	# Command flag syntax:
	# $("COMMAND-STRING" [, [<ARG1>, <ARGN> [, "<DELIMITER>"]]])

	# Loop over every input char: [https://stackoverflow.com/q/10487316]
	# [https://stackoverflow.com/q/18906514]
	# [https://stackoverflow.com/q/13952870]
	# [https://stackoverflow.com/q/1007981]
	for (my $i = 0; $i < $cmdstr_length; $i++) {
		# Cache current/previous/next chars.
		my $char = substr($input, $i, 1);
		my $pchar = substr($input, $i - 1, 1);
		my $nchar = substr($input, $i + 1, 1);

		# Check if current character is a quote and unescaped.
		my $is_unesc_quote = (($char eq '"' || $char eq "'") && $pchar ne "\\");

		# If character is an unescaped quote.
		if (!$state && $is_unesc_quote) {
			# Check if the previous character is a dollar sign. This
			# means the command should run as a command.
			if ($pchar && $pchar eq "\$") { $argument .= "\$"; }
			# Set state to open.
			$state = 1;
			# Set quote type.
			$quote_type = $char;
			# Store the character.
			$argument .= $char;

		# If char is an unescaped quote + status is open...reset.
		} elsif ($state && $is_unesc_quote && $quote_type eq $char) {
			# Set state to close.
			$state = 0;
			# Reset quote type.
			$quote_type = '';
			# Store the character.
			$argument .= $char;

		# If char is a "'" and status is open due to being wrapped in '"'
		# double quotes then allow the single quotes through.
		# Example: yarn list --depth=0 \| grep -Po 'RegExp_PATTERN'
		# -----------------------------------------^--------------^
		# ^-This will include the "'" (single quote characters).
		} elsif ($state && $is_unesc_quote) { # && $quote_type eq '"'
			# Store the character.
			$argument .= $char;

		# Handle escaped characters.
		} elsif ($char eq "\\") {
			if ($nchar) {
				# Store the character.
				$argument .= "$char$nchar";
				$i++;
			} else {
				# Store the character.
				$argument .= $char;
			}

		# For anything that is not a quote char.
		} elsif ($char !~ /["']/) {
			# If we hit a comma and the state is closed.
			# We store the current argument and reset
			# everything.
			if (!$state && $char eq ',') {
				push(@arguments, $argument);
				$args_count++;
				$argument = '';
			} elsif ($state) {
				# Store the character.
				$argument .= $char;
			}
		}
	}
	# Add remaining argument if string is not empty.
	if ($argument) {
		push(@arguments, $argument);
		$args_count++;
	}

	# Push arg count to array.
	push(@arguments, $args_count);

	# Return arguments array.
	# [https://stackoverflow.com/a/11303607]
	return @arguments;
}

# # Checks whether provided file (path) exists.
# #
# # @param {string} 1) - The file's path.
# # @return {boolean} - True if file exists. Otherwise false.
# sub __file_exists {
# 	# Get arguments.
# 	my ($scriptpath) = @_;

# 	# [https://stackoverflow.com/a/2601042]
# 	# [https://stackoverflow.com/a/8584617]
# 	# [https://www.perlmonks.org/?node_id=510490]
# 	return (-e "$scriptpath");
# }

# # Checks whether provided file (path) is executable.
# #
# # @param {string} 1) - The file's path.
# # @return {boolean} - True if file is executable. Otherwise false.
# sub __file_exec {
# 	# Get arguments.
# 	my ($scriptpath) = @_;

# 	# [https://stackoverflow.com/a/2601042]
# 	# [https://stackoverflow.com/a/8584617]
# 	# [https://www.perlmonks.org/?node_id=510490]
# 	return (-x "$scriptpath");
# }

# Set environment variables to access in custom scripts.
#
# @return {undefined} - Nothing is returned.
sub __set_envs {
	# Get parsed arguments count.
	my $l = __len(\@args);

	# Use hash to store environment variables: [https://perlmaven.com/perl-hashes]
	my %envs = (
		# Following env vars are provided by bash but exposed via nodecliac.
		"${prefix}COMP_LINE" => $cline, # Original (unmodified) CLI input.
		"${prefix}COMP_POINT" => $cpoint, # Caret index when [tab] key was pressed.

		# Following env vars are custom and exposed via nodecliac.
		# "${prefix}ACDEF" => $acdef,
		"${prefix}MAIN_COMMAND" => $maincommand, # The command auto completion is being performed for.
		"${prefix}COMMAND_CHAIN" => $commandchain, # The parsed command chain.
		# "${prefix}USED_FLAGS" => $usedflags, # The parsed used flags.
		"${prefix}LAST" => $last, # The last parsed word item (note: could be a partial word item. This happens
		# when the [tab] key gets pressed within a word item. For example, take the input 'maincommand command'. If
		# the [tab] key was pressed like so: 'maincommand comm[tab]and' then the last word item is 'comm' and it is
		# a partial as its remaining text is 'and'. This will result in using 'comm' to determine possible auto
		# completion word possibilities.).
		"${prefix}PREV" => $args[-2], # The word item preceding the last word item.
		"${prefix}INPUT" => $input, # CLI input from start to caret index.
		"${prefix}INPUT_ORIGINAL" => $oinput, # Original unmodified CLI input.
		"${prefix}INPUT_REMAINDER" => $input_remainder, # CLI input from start to caret index.
		"${prefix}LAST_CHAR" => $lastchar, # Character before caret.
		"${prefix}NEXT_CHAR" => $nextchar, # Character after caret. If char is not '' (empty) then the last word
		# item is a partial word.
		"${prefix}COMP_LINE_LENGTH" => $cline_length, # Original input's length.
		"${prefix}INPUT_LINE_LENGTH" => $cline_length, # CLI input from start to caret index string length.
		"${prefix}ARG_COUNT" => $l, # Amount arguments parsed before caret position/index.
		# Store collected positional arguments after validating the command-chain to access in plugin auto-completion scripts.
		"${prefix}USED_DEFAULT_POSITIONAL_ARGS" => $used_default_pa_args
	);

	# Dynamically set arguments.
	# for (my $i = 0; $i < $l; $i++) { $ENV{"${prefix}ARG_${i}"} = $args[$i]; }

	# If no arguments are provided then we set all env variables.
	# [https://stackoverflow.com/a/19234273]
	# [https://alvinalexander.com/blog/post/perl/how-access-arguments-perl-subroutine-function]
	if (@_ == 0) {
		# Set environment variable: [https://alvinalexander.com/blog/post/perl/how-to-traverse-loop-items-elements-perl-hash]
		foreach my $key (keys %envs) { $ENV{$key} = $envs{$key}; }
	} else {
		# Split rows by lines: [https://stackoverflow.com/a/11746174]
		foreach my $env_name (@_) {
			my $key = "${prefix}$env_name";
			# Set environment if provided env name exists in envs lookup hash table.
			# [https://alvinalexander.com/blog/post/perl/perl-how-test-hash-contains-key]
			if (exists($envs{$key})) { $ENV{$key} = $envs{$key}; }
		}
	}

	return;
}

# # Get hook scripts file paths list. Used for hook scripts.
# #
# # @return {undefined} - Nothing is returned.
# sub __hook_filepaths {
# 	# Use shell commands over Perl's glob function. The glob function is much
# 	# slower than Bash commands. Once the command is run store the commands
# 	# for later use/lookup.
# 	# [https://stackoverflow.com/a/6364244]
# 	# [https://stackoverflow.com/a/34195247]
# 	# [https://zybuluo.com/ysongzybl/note/96951]
# 	# $hpaths = `bash -c "for f in ~/.nodecliac/registry/$maincommand/hooks/{acdef,input}.*; do [ -e \"\$f\" ] && echo \"\\\$f\" || echo \"\"; done 2> /dev/null"`;
# 	# $hpaths = `bash -c "for f in ~/.nodecliac/registry/$maincommand/hooks/*.*; do [[ \\\"\\\${f##*/}\\\" =~ ^(acdef|input)\\.[a-zA-Z]+\$ ]] && echo \"\\\$f\"; done;"`;
# 	$hpaths = `bash -c "for f in ~/.nodecliac/registry/$maincommand/hooks/*.*; do [[ \\\"\\\${f##*/}\\\" =~ ^(prehook)\\.[a-zA-Z]+\$ ]] && echo \"\\\$f\"; done;"`;

# 	# $hpaths = `for f in ~/.nodecliac/registry/yarn/hooks/*.*; do file=\"\${f##*/}\"; name=\"\${file%%.*}\"; filter=\"\`echo \"\$name\" | grep ^prehook\$)\`\"; [ -z \"\$filter\" ] || echo \"\$f\"; done`;

# 	# $hpaths = `ls ~/.nodecliac/registry/$maincommand/hooks/*.* -u`;
# 	# Test in command line with Perl: [https://stackoverflow.com/a/3374281]
# 	# perl -e 'print `bash -c "for f in ~/.nodecliac/registry/yarn/hooks/{acdef,input}.*; do [ -e \"\$f\" ] && echo \"\\\$f\" || echo \"\"; done 2> /dev/null"`';

# 	# This is for future reference on how to escape code for the shell,
# 	# bash -c command, and a Perl one-liner. The following lines of code
# 	# can be copy/pasted into the terminal.
# 	# [https://stackoverflow.com/a/20796575]
# 	# [https://stackoverflow.com/questions/17420994/bash-regex-match-string]
# 	# perl -e 'print `bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \\\"\\\${f##*/}\\\" =~ ^(acdef|input)\\.[a-zA-Z]+\$ ]] && echo \"\\\$f\"; done;"`';
# 	#                 bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \"\${f##*/}\" =~ ^(acdef|input)\\.[a-zA-Z]+$ ]] && echo \"\$f\"; done;"
# 	#                          for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ "${f##*/}" =~ ^(acdef|input)\.[a-zA-Z]+$ ]] && echo "$f"; done
# }

# # Runs acdef hook script. This is pre-parsing hook.
# #
# # @return {undefined} - Nothing is returned.
# sub __hook_acdef {
# 	my $scriptpath = ''; # Store hook script file path.
# 	# ACDEF RegExp file pattern.
# 	my $pattern = '^(.*' . "\\/acdef\\." . '.*?)$';
# 	if ($hpaths =~ /$pattern/m) { $scriptpath = $1; }

# 	# If path does not exist then return from function.
# 	if (!$scriptpath) { return; }

# 	# File checks - Is this needed as any error will be are suppressed?
# 	# if (!(__file_exists($scriptpath) && __file_exec($scriptpath))) { return; }

# 	# Set env variable to access in hook script.
# 	__set_envs('ACDEF');

# 	# Run command string.
# 	my $output = `\"$scriptpath\" 2> /dev/null`;

# 	# Set acdef variable to returned output.
# 	if ($output) { $acdef = $output; }
# }

# # Runs input hook script. This is pre-parsing hook.
# #
# # @return {undefined} - Nothing is returned.
# sub __hook_input {
# 	my $scriptpath = ''; # Store hook script file path.
# 	# Input RegExp file pattern.
# 	my $pattern = '^(.*' . "\\/input\\." . '.*?)$';
# 	if ($hpaths =~ /$pattern/m) { $scriptpath = $1; }

# 	# If path does not exist then return from function.
# 	if (!$scriptpath) { return; }

# 	# File checks - Is this needed as any error will be are suppressed?
# 	# if (!(__file_exists($scriptpath) && __file_exec($scriptpath))) { return; }

# 	# Set env variable to access in hook script.
# 	__set_envs('INPUT');

# 	# Run command string.
# 	my $output = `\"$scriptpath\" 2> /dev/null`;
# 	# Trim newlines from output.
# 	$output =~ s/^\n+|\n+$//g;

# 	# If output is empty then return from function.
# 	if (!$output) { return; };

# 	# Reset variable(s).
# 	$input = $output;
# 	$cline = "$input$input_remainder"; # Original (complete) CLI input.
# 	$cpoint = length($input); # Caret index when [tab] key was pressed.
# 	$lastchar = substr($cline, $cpoint - 1, 1); # Character before caret.
# 	$nextchar = substr($cline, $cpoint, 1); # Character after caret.
# 	$cline_length = length($cline); # Original input's length.
# 	# $input = substr($cline, 0, $cpoint); # CLI input from start to caret index.
# 	# $input_remainder = substr($cline, $cpoint, -1); # CLI input from caret index to input string end.
# }

# # Runs pre hook script.
# #
# # @return {undefined} - Nothing is returned.
# sub __hook_pre {
# 	# Hook directory path.
# 	my $hookdir = "$hdir/.nodecliac/registry/yarn/hooks";
# 	# my $scriptpath = "$hookdir/prehook.sh";

# 	my $scriptpath = ''; # Store hook script file path.
# 	my $pattern = '^(.*' . "\\/prehook\\." . '.*?)$';
# 	if ($hpaths =~ /$pattern/m) { $scriptpath = $1; }

# 	# If path does not exist then return from function.
# 	# [https://www.perlmonks.org/?node_id=510490]
# 	if (!$scriptpath || not -e $scriptpath) { return; }
# 	# if (not -e $scriptpath) { return; }

# 	# Set env variable to access in hook script.
# 	# __set_envs('INPUT', 'ACDEF', 'MAIN_COMMAND');
# 	__set_envs('INPUT', 'MAIN_COMMAND', 'INPUT_ORIGINAL');

# 	# Run command string.
# 	my $output = `\"$scriptpath\" 2> /dev/null`;

# 	# If output is empty then return from function.
# 	if (!$output) { return; };

# 	# Modify input variable if key is in output string.
# 	if (__includes($output, 'input')) {
# 		# Reset variable(s).
# 		$input = `cat $hookdir/.input.data`; # Get file contents.
# 		$cline = "$input$input_remainder"; # Original (complete) CLI input.
# 		$cpoint = length($input); # Caret index when [tab] key was pressed.
# 		$lastchar = substr($cline, $cpoint - 1, 1); # Character before caret.
# 		$nextchar = substr($cline, $cpoint, 1); # Character after caret.
# 		$cline_length = length($cline); # Original input's length.
# 		# $input = substr($cline, 0, $cpoint); # CLI input from start to caret index.
# 		# $input_remainder = substr($cline, $cpoint, -1); # CLI input from caret index to input string end.
# 	}

# 	# Modify acdef variable if key is in output string.
# 	if (__includes($output, 'acdef')) {
# 		# Get file contents and set acdef variable to returned output.
# 		$acdef = `cat "$hookdir/.acdef.data"`;
# 	}
# }

# Parses CLI input. Returns input similar to that of process.argv.slice(2).
#     Adapted from argsplit module.
#
# @param {string} 1) - The string to parse.
# @return {undefined} - Nothing is returned.
sub __parser {
	# Vars.
	my $current = '';
	my $quote_char = '';
	my $l = length($input); # Input length.

	# Input must not be empty.
	if (!$input) { return; }

	# Loop over every input char: [https://stackoverflow.com/q/10487316]
	for (my $i = 0; $i < $cline_length; $i++) {
		# Cache current/previous/next chars.
		my $c = substr($input, $i, 1);
		my $p = substr($input, $i - 1, 1);
		my $n = substr($input, $i + 1, 1);

		# Reset prev word for 1st char as bash gets the last char.
		if (!$i) {
			$p = '';
		# Reset next word for last char as bash gets the first char.
		} elsif ($i == ($cline_length - 1)) {
			$n = '';
		}

		# Stop loop once it hits the caret position character.
		if ($i >= ($l - 1)) {
			# Only add if not a space character.
			if ($c ne ' ' || $c eq ' ' && $p eq "\\") {
				$current .= $c;
			}

			# Store last char.
			$lastchar = $c;
			# If last char is an escaped space then reset lastchar.
			if ($c eq ' ' && $p eq "\\") { $lastchar = ''; }

			last;
		}

		# If char is a space.
		if ($c eq ' ' && $p ne "\\") {
			if (length($quote_char) != 0) {
				$current .= $c;
			} else {
				if ($current) {
					push(@args, $current);
					$current = '';
				}
			}
		# Non space chars.
		} elsif (($c eq '"' || $c eq "'") && $p ne "\\") {
			if ($quote_char) {
				# To end the current string encapsulation, the next
				# char must be a space or nothing (meaning) the end
				# if the input string. This is done to prevent
				# this edge case: 'myapp run "some"--'. Without this
				# check the following args get parsed:
				# args=(myapp run "some" --). What we actually want
				# is args=(myapp run "some"--).
				#
				if ($quote_char eq $c && ($n eq "" || $n eq ' ')) {
					$current .= $c;
					push(@args, $current);
					$quote_char = '';
					$current = '';
				} elsif (($quote_char eq '"' || $quote_char eq "'") && $p ne "\\") {
					$current .= $c;
				} else {
					$current .= $c;
					$quote_char = $c;
				}
			} else {
				$current .= $c;
				$quote_char = $c;
			}
		} else {
			$current .= $c;
		}
	}

	# Add the remaining word.
	if ($current) { push(@args, $current); }

	return;
}

# Lookup command/subcommand/flag definitions from the acdef to return
#     possible completions list.
#
# Test input:
# myapp run example go --global-flag value
# myapp run example go --global-flag value subcommand
# myapp run example go --global-flag value --flag2
# myapp run example go --global-flag value --flag2 value
# myapp run example go --global-flag value --flag2 value subcommand
# myapp run example go --global-flag value --flag2 value subcommand --flag3
# myapp run example go --global-flag --flag2
# myapp run example go --global-flag --flag value subcommand
# myapp run example go --global-flag --flag value subcommand --global-flag --flag value
# myapp run example go --global-flag value subcommand
# myapp run 'some' --flagsin command1 sub1 --flag1 val
# myapp run -rd '' -a config
# myapp --Wno-strict-overflow= config
# myapp run -u $(id -u $USER):$(id -g $USER\ )
# myapp run -u $(id -u $USER):$(id -g $USER )
sub __extractor {
	# Vars.
	my $l = __len(\@args);
	my @oldchains = ();
	# Following variables are used when validating command chain.
	my $last_valid_chain = '';

	# Loop over CLI arguments.
	for (my $i = 1; $i < $l; $i++) {
		# Cache current loop item.
		my $item = $args[$i];
		my $nitem = $args[$i + 1];

		# Skip quoted (string) items.
		if (__is_lquoted($item)) {
			next;
		} else {
			# Else if the argument is not quoted check if item contains
			# an escape sequences. If so skip the item.
			if ($item =~ /\\./) { next; }
		}

		# Reset next item if it's the last iteration.
		if ($i == $l - 1) {
			$nitem = '';
		}

		# If a command (does not start with a hyphen.)
		# [https://stackoverflow.com/a/34951053]
		# [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
		if (!__starts_with_hyphen($item)) {
			# Store default positional argument if flag is set.
			if ($collect_used_pa_args) {
				# Add used argument.
				$used_default_pa_args .= "\n$item";
				# Skip all following logic.
				next;
			}

			# Store command.
			$commandchain .= '.' . __normalize_command($item);

			# Check that command chain exists in acdef.
			# my $pattern = '^' . quotemeta($commandchain) . '.* ';
			my $pattern = '^(?![#|\n])' . quotemeta($commandchain) . '[^ ]*? ';
			if ($acdef =~ /$pattern/m) {
				# If there is a match then store chain.
				$last_valid_chain = $commandchain;
			} else {
				# Revert command chain back to last valid command chain.
				$commandchain = $last_valid_chain;

				# Set flag to start collecting used positional arguments.
				$collect_used_pa_args = 1;
				# Store used argument.
				$used_default_pa_args .= "\n$item";
			}

			# Reset used flags.
			@foundflags = ();
		} else { # We have a flag.
			# Store commandchain to revert to it if needed.
			push(@oldchains, $commandchain);
			$commandchain = '';

			# Clear stored used default positional arguments string.
			$used_default_pa_args = '';
			$collect_used_pa_args = 0;

			# If the flag contains an eq sign don't look ahead.
			if (__includes($item, '=')) {
				push(@foundflags, $item);
				next;
			}

			# Look ahead to check if next item exists. If a word
			# exists then we need to check whether is a value option
			# for the current flag or if it's another flag and do
			# the proper actions for both.
			if ($nitem) {
				# If the next word is a value...
				if (!__starts_with_hyphen($nitem)) {
					# Check whether flag is a boolean:
					# Get the first non empty command chain.
					my $oldchain = '';
					my $skipflagval = 0;
					for (my $j = ($#oldchains); $j >= 0; $j--) {
						my $chain = $oldchains[$j];
						if ($chain) {
							$oldchain = $chain;

							# Lookup flag definitions from acdef.
							my $pattern = '^' . $oldchain . ' (-{1,2}.*)$';
							if ($acdef =~ /$pattern/m) {
								my $pattern = "${item}\\?" . '(\\||$)';
								if ($1 =~ /$pattern/) { $skipflagval = 1; }
							}

							last;
						}
					}

					# If the flag is not found then simply add the
					# next item as its value.
					if (!$skipflagval) {
						push(@foundflags, __validate_flag($item) . "=$nitem");

						# Increase index to skip added flag value.
						$i++;
					} else {
						# It's a boolean flag. Add boolean marker (?).
						$args[$i] = $args[$i] . '?';

						push(@foundflags, __validate_flag($item));
					}

				} else { # The next word is a another flag.
					push(@foundflags, __validate_flag($item));
				}

			} else {
				# Check whether flag is a boolean
				# Get the first non empty command chain.
				my $oldchain = '';
				my $skipflagval = 0;
				for (my $j = ($#oldchains); $j >= 0; $j--) {
					my $chain = $oldchains[$j];
					if ($chain) {
						$oldchain = $chain;

						# Lookup flag definitions from acdef.
						my $pattern = '^' . $oldchain . ' (-{1,2}.*)$';
						if ($acdef =~ /$pattern/m) {
							my $pattern = "${item}\\?" . '(\\||$)';
							if ($1 =~ /$pattern/) { $skipflagval = 1; }
						}

						last;
					}
				}

				# If the flag is found then add marker to item.
				if ($skipflagval != 0) {
					# It's a boolean flag. Add boolean marker (?).
					$args[$i] = $args[$i] . '?';
				}
				push(@foundflags, __validate_flag($item));

			}
		}

	}

	# Revert commandchain to old chain if empty.
	if (!$commandchain) {
		# Get the first non empty command chain.
		my $oldchain = '';
		for (my $i = ($#oldchains); $i >= 0; $i--) {
			my $chain = $oldchains[$i];
			if ($chain) { $oldchain = $chain; last; }
		}

		# Revert commandchain to old chain.
		$commandchain = $oldchain;
	}
	# Prepend main command to chain.
	$commandchain = __validate_command($commandchain);

	# Determine whether to turn off autocompletion or not.
	# Get the last word item.
	my $lword = $args[-1];
	if ($lastchar eq ' ') {
		if (__starts_with_hyphen($lword)) {
			if (__includes($lword, '?') || __includes($lword, '=')) {
				$autocompletion = 1;
			} else {
				$autocompletion = 0;
			}
		}
	} else {
		if (!__starts_with_hyphen($lword)) {
			# Check if the second to last word is a flag.
			my $sword = $args[-2];
			if (__starts_with_hyphen($sword)) {
				if (__includes($sword, '?') || __includes($sword, '=')) {
					$autocompletion = 1;
				} else {
					$autocompletion = 0;
				}
			}
		}
	}

	# Remove boolean indicator from flags.
	for my $i (0 .. $#args) {
		# Check for valid flag pattern?
		if (__starts_with_hyphen($args[$i])) {
			# Remove boolean marker from flag.
			if (substr($args[$i], -1) eq '?') {
				$args[$i] = substr($args[$i], 0, -1);
			}
		}
	}

	# Set last word. If the last char is a space then the last word
	# will be empty. Else set it to the last word.
	# Switch statement: [https://stackoverflow.com/a/22575299]
	$last = ($lastchar eq ' ') ? '' : $args[-1];

	# Check whether last word is quoted or not.
	if (__is_lquoted($last)) { $isquoted = 1; }

	# Note: If autocompletion is off check whether we have one of the
	# following cases: '$ maincommand --flag ' or '$ maincommand --flag val'.
	# If we do then we show the possible value options for the flag or
	# try and complete the currently started value option.
	if (!$autocompletion && $nextchar ne '-') {
		my $islast_aspace = ($lastchar eq ' ');
		# Get correct last word.
		my $nlast = $args[($islast_aspace ? -1 : -2)];
		# acdef commandchain lookup Regex.
		my $pattern = '^' . $commandchain . ' (-{1,2}.*)';
		# The last word (either last or second last word) must be a flag
		# and cannot have contain an eq sign.
		if (__starts_with_hyphen($nlast) && !__includes($nlast, '=')) {
			# Show all available flag option values.
			if ($islast_aspace) {
				# Check if the flag exists in the following format: '--flag='
				if ($acdef =~ /$pattern/m) {
					# Check if flag exists with option(s).
					my $pattern = $nlast . '=(?!\*).*?(\||$)';
					if ($1 =~ /$pattern/) {
						# Reset needed data.
						# Modify last used flag.
						# [https://www.perl.com/article/6/2013/3/28/Find-the-index-of-the-last-element-in-an-array/]
						$foundflags[-1] = $foundflags[-1] . '=';
						$last = $nlast . '=';
						$lastchar = '=';
						$autocompletion = 1;
					}
				}
			} else { # Complete currently started value option.
				# Check if the flag exists in the following format: '--flag='
				if ($acdef =~ /$pattern/m) {
					# Escape special chars: [https://stackoverflow.com/a/576459]
					# [http://perldoc.perl.org/functions/quotemeta.html]
					my $pattern = $nlast . '=' . quotemeta($last) . '.*?(\||$)';

					# Check if flag exists with option(s).
					if ($1 =~ /$pattern/) {
						# Reset needed data.
						$last = $nlast . '=' . $last;
						$lastchar = substr($last, -1);
						$autocompletion = 1;
					}
				}
			}
		}
	}

	# Escape last word pattern.
	# Escape special chars: [https://stackoverflow.com/a/576459]
	# [http://perldoc.perl.org/functions/quotemeta.html]
	# [https://stackoverflow.com/a/2458538]
	$elast_ptn = '^' . quotemeta($last);

	return;
}

# Lookup command/subcommand/flag definitions from the acdef to return
#     possible completions list.
sub __lookup {
	# Skip logic if last word is quoted or completion variable is off.
	if ($isquoted || !$autocompletion) {
		return;
	}

	# Flag completion (last word starts with a hyphen):
	if (__starts_with_hyphen($last)) {
		# Lookup flag definitions from acdef.
		my $pattern = '^' . $commandchain . ' (-{1,2}.*)';

		if ($acdef =~ /$pattern/m) {
			# Continue if rows exist.
			my @used = ();

			# Set completion type:
			$type = 'flag';

			# If no flags exist skip line.
			if ($1 eq '--') { return; }

			# Split by unescaped pipe '|' characters:
			# [https://www.perlmonks.org/bare/?node_id=319761]
			# my @flags = split(/(?<!\\)\|/, $1);
			my @flags = split(/(?:\\\\\|)|(?:(?<!\\)\|)/, $1);

			# Breakup last word into flag/value.
			my @matches = $last =~ /^([^=]+)((=)(\*)?(.*))?/;
			# Default to empty string if no match.
			# [https://perlmaven.com/how-to-set-default-values-in-perl]
			my $last_fkey = $matches[0] // '';
			my $last_eqsign = $matches[2] // '';
			my $last_multif = $matches[3] // '';
			my $last_value = $matches[4] // '';
			# my $nohyphen_last = $last =~ s/^-*//r;
			# my $last_fletter = substr($nohyphen_last, 0, 1);
			my $last_val_quoted = __is_lquoted($last_value);

			# Get the last words first non-hyphen character.
			my ($fchar_last) = $last =~ /([^-])/;
			$fchar_last = $fchar_last // ''; # Set default value.
			my $last_not_hyphens = ($last !~ /^-{1,2}$/);

			# Loop over flags to process.
			foreach my $flag (@flags) {
				# Skip flags not starting with same char as last word.
				my ($fchar_flag) = $flag =~ /([^-])/;
				$fchar_flag = $fchar_flag // ''; # Set default value.
				if ($fchar_last ne $fchar_flag && $last_not_hyphens) { next; }

				# Breakup flag into its components (flag/value/etc.).
				@matches = $flag =~ /^([^?=]+)(\?)?((=)(\*)?(.*))?/;
				# Default to empty string if no match.
				# [https://perlmaven.com/how-to-set-default-values-in-perl]
				my $flag_fkey = $matches[0] // '';
				my $flag_isbool = $matches[1] // '';
				my $flag_eqsign = $matches[3] // '';
				my $flag_multif = $matches[4] // '';
				my $flag_value = $matches[5] // '';
				# my $nohyphen_flag = $flag =~ s/^-*//r;
				# my $flag_fletter = substr($nohyphen_flag, 0, 1);
				# my $flag_val_quoted = __is_lquoted($flag_value);

				# # Preliminary checks:
				# if (
				# # Before continuing with full on flag logic checks, check
				# # whether the flag even starts with the same character. If
				# # the last word is only made up of hyphens then let it
				# # through.
				# 	$nohyphen_last && $last_fletter ne $flag_fletter ||
				# # Flag must start with the last word. Escape special chars:
				# # [https://stackoverflow.com/a/576459]
				# # [http://perldoc.perl.org/functions/quotemeta.html]
				# # $pattern = '^' . $last_fkey;
				# # if (!($flag_fkey =~ /$pattern/)) { next; }
				# 	index($flag_fkey, $last_fkey) != 0
				# ) { next; }

				# Reset flag to only include flag key and possible value.
				$flag = $flag_fkey .
					# Check for value.
					($flag_eqsign ? ($flag_value) ? "=$flag_value" : '=' : '');

				# Track multi-starred flags.
				if ($flag_multif) { $__dc_multiflags{$flag_fkey} = 1; }

				# Unescape flag.
				# $flag = __unescape($flag);

				# If a command-flag: --flag=$("<COMMAND-STRING>"), run
				# command and add returned words to completion options.
				if ($last_eqsign) {
					# If fkey starts with flag and is a command flag.
					if (!index($flag, $last_fkey) && $flag =~ $flagcommand) {
						# *Pass flags array as a ref to access in function.
						# Parse user provided command-flag command.
						__execute_command($1, \@flags, $last_fkey);
						# [https://stackoverflow.com/a/31288153]
						# Skip flag to not add literal command to completions.
						next;
					}
				}

				# Flag must start with the last word.
				if ($flag =~ /$elast_ptn/) {
					# Note: If the last word is "--" or if the last
					# word is not in the form "--form= + a character",
					# don't show flags with values (--flag=value).
					if (!$last_eqsign && $flag =~ $flgoptvalue && !$flag_multif) {
						next;
					}

					# No dupes unless it's a multi-starred flag.
					if (!__dupecheck(
							$flag,
							$flag_fkey,
							$flag_isbool,
							$flag_eqsign,
							$flag_multif,
							$flag_value
						)
					) {
						# If last word is in the form → "--flag=" then we
						# need to remove the last word from the flag to
						# only return its options/values.
						if ($last =~ $flgopt) {
							# Copy flag to later reset flag key if no
							# option was provided for it.
							my $flagcopy = $flag;

							# Reset flag to its option. If option is empty
							# (no option) then default to flag's key.
							# flag+="value"
							$flag = $flag_value ? $flag_value : $flagcopy;
						}

						# Note: This is more of a hack check. Values with
						# special characters will sometime by-pass the
						# previous checks so do one file check. If the
						# flag is in the following form:
						# --flags="value-string" then we do not add is to
						# the completions list. Final option/value check.
						# my $__isquoted = ($flag_eqsign && $flag_val_quoted);

						# Add flag/options if all checks pass.
						# if (!$__isquoted && $flag ne $last) {
						if ($flag && $flag ne $last) {
							push(@completions, $flag);
						}
					} else {
						# If flag exits and is already used then add a
						# space after it.
						if ($flag eq $last) {
							if (!$last_eqsign) {
								push(@used, $last);
							} else {
								$flag = $flag_value;
								if ($flag) {
									push(@completions, $flag);
								}
							}
						}
					}
				}
			}

			# Note: If the last word (the flag in this case) is an
			# options flag (i.e. --flag=val) we need to remove the
			# possible already used value. For example take the
			# following scenario. Say we are completing the following
			# flag '--flag=7' and our two options are '7' and '77'.
			# Since '7' is already used we remove that value to leave
			# '77' so that on the next tab it can be completed to
			# '--flag=77'.
			my $l = $#completions;

			# Note: Account for quoted strings. If the last value is
			# quoted, then add closing quote.
			if ($last_val_quoted) {
				# Get starting quote (i.e. " or ').
				my $quote = substr($last_value, 0, 1);

				# Close string with matching quote if not already.
				if (substr($last_value, -1) ne $quote) {
					$last_value .= $quote;
				}

				# Add quoted indicator to type string to later escape
				# for double quoted strings.
				$type = 'flag;quoted';
				if ($quote eq '"') {
					$type .= ';noescape';
				}

				# If the value is empty return.
				if (length($last_value) == 2) {
					push(@completions, "$quote$quote");
					return;
				}
			}

			# If the last word contains an eq sign, it has a value
			# option, and there are more than 2 possible completions
			# we remove the already used option.
			if ($last_value && ($l + 1) >= 2) {
				for (my $i = $l; $i >= 0; $i--) {
					if (length($completions[$i]) == length($last_value)) {
						# Remove item from array.
						splice(@completions, $i, 1);
					}
				}
			}

			# Note: If there are no completions but there is a single
			# used flag, this means no completions exist and the
			# current flag exist. Therefore, add the current word (the
			# used flag) so that bash appends a space to it.
			if (!@completions && @used == 1) {
				push(@completions, $used[0]);
			}
		}
	} else { # Command completion:

		# Set completion type:
		$type = 'command';

		# Store command completions in a hash to only keep unique entries.
		# [https://stackoverflow.com/a/15894780]
		# [https://stackoverflow.com/a/3810548]
		# [https://stackoverflow.com/a/11437184]
		# my %lookup;

		# If command chain and used flags exits, don't complete.
		if (%usedflags && $commandchain) {
			# Reset commandchain.
			$commandchain = "" . (!$last ? "" : $last);
		}

		# Lookup all command tree rows from acdef once and store.
		# my $pattern = '^' . $commandchain . '.*$'; # Original.
		# my $pattern = '^' . substr($commandchain, 0, 2) . '.*$'; # 2 char RegExp pattern.
		# The following RegExp does not seem to work:
		# my $pattern = '^(?!(\\#|\\s))' . quotemeta(substr($commandchain, 0, 2)) . '.*$';
		# Make initial acdef file lookup. Ignore comments/empty lines.
		# my $pattern = '^(?![#|\n])' . quotemeta(substr($commandchain, 0, 2)) . '.*$';
		# my $pattern = '^(?![#|\n])' . $commandchain . '.+$';

		# Built ACDEF lookup pattern.
		my $minipattern = $last . '$';
		# Escape the command chain.
		my $escaped_cc = quotemeta($commandchain);
		my $pattern = '^(?![#|\n])' .
			(
				# If last variable is set and command chain doesn't equal it...
				($last && $commandchain ne ".$last")
				?
					(
						# If command chain ends with last variable...
						($escaped_cc =~ /$minipattern/)
							# If so, use command chain.
						?  $escaped_cc
							# Else, use command + last variable.
						: ($escaped_cc . quotemeta(".$last"))
					)
					# Else, use first 2 characters of command chain.
				: substr($commandchain, 0, 2)
			)
			. '.+ --'; # Get row from start to first flag indicator ' --'.

		my @data = $acdef =~ /$pattern/mg;
		my @rows = (); # Store filtered data.
		my $lastchar_notspace = ($lastchar ne ' ');

		# Determine last command replacement type and initial data filter.
		$pattern = '^' . $commandchain . '\\.[^.\\s]+ ';
		my $rtype = 1; # Replacement type.
		if ($lastchar_notspace) {
			# [https://stackoverflow.com/questions/15573652/regex-to-exclude-unless-preceded-by]
			# [https://stackoverflow.com/a/7124976]
			# [https://stackoverflow.com/a/9306228]
			# [https://stackoverflow.com/a/11819111]
			# [https://stackoverflow.com/a/6464500]
			# [https://stackoverflow.com/a/6525975]
			$pattern = '^' . $commandchain . '[^\.]([^\\.]|(?<=\\\\)\\.)* ';
			$rtype = 2;
		}
		# Filter rows instead of looking up entire file again.
		@rows = grep(/$pattern/, @data);

		# If no upper level exists for the commandchain check that
		# the current chain is valid. If valid, add the last command
		# to the completions array to bash can append a space when
		# the user presses the [tab] key to show the completion is
		# complete for that word.
		if (!@rows) {
			$pattern = '^' . $commandchain . ' ';
			# Filter rows instead of looking up entire file again.
			@rows = grep(/$pattern/, @data);

			if (@rows && $lastchar_notspace) {
				# Get commandchain length.
				my $lchain = length($commandchain);
				# Get the last command in command chain.
				my $last_command = __last_command($rows[0], $rtype, $lchain);

				# If the last command in the chain is equal to the last word
				# then add the last command to the lookup table.
				if ($last_command eq $last) {
					# Add last command in chain.
					# $lookup{$last_command} = 1;
					push(@completions, $last_command);
				}
			}
		} else {
			# # Last word checks:
			# $pattern = '^' . $commandchain . ' ';
			# # Filter rows instead of looking up entire file again.
			# my $check1 = scalar(grep(/$pattern/, @data));

			# # [https://stackoverflow.com/questions/15573652/regex-to-exclude-unless-preceded-by]
			# # [https://stackoverflow.com/a/7124976]
			# # [https://stackoverflow.com/a/9306228]
			# # [https://stackoverflow.com/a/11819111]
			# # [https://stackoverflow.com/a/6464500]
			# # [https://stackoverflow.com/a/6525975]
			# $pattern = '^' . $commandchain . '([^\\.]|(?<=\\\\)\\.)+ ';
			# # Filter rows instead of looking up entire file again.
			# my $check2 = scalar(grep(/$pattern/, @data));

			# Last word checks:
			# [https://stackoverflow.com/questions/15573652/regex-to-exclude-unless-preceded-by]
			# [https://stackoverflow.com/a/7124976]
			# [https://stackoverflow.com/a/9306228]
			# [https://stackoverflow.com/a/11819111]
			# [https://stackoverflow.com/a/6464500]
			# [https://stackoverflow.com/a/6525975]
			$pattern = '^' . $commandchain . '([^\\.]|(?<=\\\\)\\.)+ ';
			# Filter rows instead of looking up entire file again.
			my @fcheck2 = grep(/$pattern/, @rows);
			my $ccheck2 = scalar(@fcheck2);
			#
			my $ccheck1 = 0;
			if ($ccheck2) {
				# Last word checks:
				$pattern = '^' . $commandchain . ' ';
				# Filter rows instead of looking up entire file again.
				$ccheck1 = scalar(grep(/$pattern/, @fcheck2));
			}

			if (
				# If caret is in the last position (not a space)...
				$lastchar_notspace &&
				# ...the command tree exists...
				$ccheck1 &&
				# ...and the command chain does not contain any upper levels
				# then add the last word so that bash can add a space to it.
				!$ccheck2
			) {
				# $lookup{$last} = 1; # Add last command in chain.
				push(@completions, $last);
			} else {
				# Get commandchain length.
				my $lchain = length($commandchain);
				my %usedcommands;

				# # Filter rows further for type 1 completion.
				# if ($rtype == 1) {
				# 	$pattern = '^' . $commandchain . '\\.[^.\\s]+ ';
				# 	@rows = grep(/$pattern/, @rows);
				# }

				# Split rows by lines: [https://stackoverflow.com/a/11746174]
				foreach my $row (@rows) {
					# Get last command in chain.
					$row = __last_command($row, $rtype, $lchain);

					# Add last command it not yet already added.
					if ($row && !exists($usedcommands{$row})) {
						# If the character before the caret is not a
						# space then we assume we are completing a
						# command. (should we check that the character
						# is one of the allowed command chars,
						# i.e. [a-zA-Z-:]).
						if ($lastchar_notspace) {
							# Since we are completing a command we only
							# want words that start with the current
							# command we are trying to complete.
							if ($row =~ /$elast_ptn/) {
								# $lookup{$row} = 1;
								push(@completions, $row);
							}
						} else {
							# If we are not completing a command then
							# we return all possible word completions.
							# $lookup{$row} = 1;
							push(@completions, $row);
						}

						# Store command in hash.
						$usedcommands{$row} = 1;
					}
				}
			}
		}

		# # Get hash values as an array.
		# # [https://stackoverflow.com/a/2907303]
		# # @completions = values %lookup;
		# # Use a loop for better compatibility.
		# # [https://stackoverflow.com/a/3360]
		# foreach my $key (keys %lookup) { push(@completions, $key); }

		# Note: If there is only one command in the command completions
		# array, check whether the command is already in the commandchain.
		# If so, empty completions array as it has already been used.
		if ($nextchar && @completions == 1) {
			my $pattern = '.' . $completions[0] . '(\\.|$)';
			if ($commandchain =~ /$pattern/) { @completions = (); }
		}

		# If no completions exist run default command if it exists.
		if (!@completions) {
			# Copy commandchain string.
			my $copy_commandchain = $commandchain;
			# Keyword to look for.
			my $keyword = 'default';

			# Loop over command chains to build individual chain levels.
			while ($copy_commandchain) {
				# Get command-string, parse it, then run it...
				my $pattern = '^' . quotemeta($copy_commandchain) . " $keyword" . '[ \t]{1,}(.*?)$';
				if ($acdef =~ /$pattern/m) {
					# Store matched RegExp pattern value.
					my $value = $1;
					# If match exists...
					# Check if it is a command-string.
					my $pattern = '^\$\((.*?)\)$';
					if ($value =~ /$pattern/m) {
						# Get the command-flag.
						# Parse user provided command-flag command.
						__execute_command($1);
					}
					# Else it is a static non command-string value.
					else {
						if ($last) {
							# When last word is present only
							# add words that start with last
							# word.

							# Since we are completing a command we only
							# want words that start with the current
							# command we are trying to complete.
							if ($value =~ /$elast_ptn/) {
								# Finally, add to flags array.
								push(@completions, $value);
							}
						} else {
							# Finally, add to flags array.
							push(@completions, $value);
						}
					}

					# Stop loop once a command-string is found and ran.
					last;
				}

				# Remove last command chain from overall command chain.
				$copy_commandchain =~ s/\.((?:\\\.)|[^\.])+$//; # ((?:\\\.)|[^\.]*?)*$
			}

			# # Note: 'always' keyword has quirks so comment out for now.
			# # Note: When running the 'always' fallback should the current command
			# # chain's fallback be looked and run or should the command chain also
			# # be broken up into levels and run the first available fallback always
			# # command-string?
			# my @chains = ($commandchain);
			# __fallback_cmd_string('always', \@chains);
		}
	}

	return;
}

# Send all possible completions to bash.
sub __printer {
	# Build and contains all completions in a string.
	my $lines = "$type:$last";
	# ^ The first line will contain meta information about the completion.

	# Check whether completing a command.
	my $iscommand = $type eq 'command';
	# Add new line if completing a command.
	if ($iscommand) { $lines .= "\n"; }

	# Determine what list delimiter to use.
	my $sep = ($iscommand) ? ' ' : "\n";
	# Check completing flags.
	my $isflag_type = $type =~ /^f/;

	# Loop over completions and append to list.
	for my $i (0 .. $#completions) {
		# Cache completion.
		my $completion = $completions[$i];

		# Append completion line.
		$lines .= "$sep$completion";

		# Add trailing space to all completions except to flag
		# completions that end with a trailing eq sign, commands
		# that have trailing characters (commands that are being
		# completed in the middle), and flag string completions
		# (i.e. --flag="some-word...).
		if ($isflag_type
			&& !__includes($completion, '=')
			&& !__is_lquoted($completion)
			&& !$nextchar
		) {
			$lines .= ' ';
		}
	}

	# Return data.
	print $lines;

	return;
}

# Completion logic:

# # # Run [pre-parse] hooks.
# __hook_filepaths();
# # # Variable must be populated with hook file paths to run scripts.
# # if ($hpaths) { __hook_acdef();__hook_input(); }
# __hook_pre();

# (cli_input*) → parser → extractor → lookup → printer
# *Supply CLI input from start to caret index.
__parser();__extractor();__lookup();__printer();
