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

# Vars - ACDEF file parsing variables.
my %db;
my %seen;
# $db{'levels'};
$db{'fallbacks'} = {};

# # Get the command's ACDEF file.
# my $acdefpath = "$hdir/.nodecliac/registry/$maincommand/$maincommand.acdef";
# # If the ACDEF file does not exist then exit script.
# exit if (not -f $acdefpath);
# my $acdef = do{local(@ARGV,$/)="$acdefpath";<>}; # Get the acdef definitions file.

# Vars.
my @args = ();
my $last = '';
# my $elast_ptn = ''; # Escaped last word pattern.
my $type = '';
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

# Used flags variables.
my %usedflags;
$usedflags{'valueless'};
$usedflags{'multi'};

# Vars to be used for storing used default positional arguments.
my $used_default_pa_args = '';
my $collect_used_pa_args = '';

# # Store hook scripts paths.
# my $hpaths = '';

# Set environment vars so command has access.
my $prefix = 'NODECLIAC_';

# RegExp Patterns: [https://stackoverflow.com/a/953076]
# my $flgopt = qr/-{1,2}[^=]*\=/; # "--flag/-flag="
# my $flgoptvalue = qr/^-{1,2}[^=*]*\=\*?.{1,}/; # "--flag/-flag=value"
# my $flagcommand = qr/^-{1,2}[^=*]*\=\*?\$\((.{1,})\)$/; # "--flag/-flag=$("<COMMAND-STRING>")"
# my $flagcommand = qr/^\$\(.{1,}\)$/; # "--flag/-flag=$("<COMMAND-STRING>")"

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

# # Return provided arrays length.
# #
# # @param {array} 1) - The array's reference.
# # @return {number} - The array's size.
# #
# # @resource [https://perlmaven.com/passing-two-arrays-to-a-function]
# sub __len {
# 	# Get arguments.
# 	my ($array_ref) = @_;
# 	# Dereference and use array.
# 	my @array = @{ $array_ref };

# 	# [https://alvinalexander.com/blog/post/perl/how-determine-size-number-elements-length-perl-array]
# 	# [https://stackoverflow.com/questions/7406807/find-size-of-an-array-in-perl]
# 	return $#array + 1; # scalar(@array);
# }

# Check whether string is left quoted (i.e. starts with a quote).
#
# @param {string} 1) - The string to check.
# @return {boolean} - True means it's left quoted.
sub __is_lquoted {
	# Get first character's numerical value.
	# my $res = ord($_[0]);
	# return ($res == 34 || $res == 39); # Single quote: 39, double quote: 34.
	# return (rindex($_[0], '"', 0) == 0 || rindex($_[0], '\'', 0) == 0); # Single quote: 39, double quote: 34.
	return (substr($_[0], 0, 1) =~ tr/"'//); # Single quote: 39, double quote: 34.
}

# # Get last command in chain: 'mc.sc1.sc2' → 'sc2'
# #
# # @param {string} 1) - The row to extract command from.
# # @param {number} 2) - The chain replacement type.
# # @return {string} - The last command in chain.
# sub __last_command {
# 	# Get arguments.
# 	my ($row, $type, $lchain) = @_;

# 	# Extract command chain from row.
# 	# ($row) = $row =~ /^[^ ]*/g;
# 	if ($row =~ /^([^ ]*)/) { $row = $1; }

# 	# Chain replacement depends on completion type.
# 	if ($type == 2) {
# 		# # Get the last command in chain.
# 		# my @cparts = split(/(?<!\\)\./, $row);
# 		# $row = pop(@cparts);

# 		# Get the last command in chain.
# 		$row = (split(/(?<!\\)\./, $row))[-1];

# 		# Slower then split/pop^.
# 		# if ($row =~ /((?!\.)((?:\\\.)|[^\.])+)$/) { $row = $1; }
# 	} else {
# 		$row = substr($row, $lchain + 1, length($row));
# 		# $row =~ s/$commandchain\.//;
# 	}

# 	# Extract next command in chain.
# 	my $lastcommand;
# 	if ($row =~ /^([^\s]*)(?=(?<!\\)\.)/) { $lastcommand = $1; }
# 	$lastcommand //= $row;

# 	# Remove any slashes from command.
# 	if (__includes($lastcommand, "\\")) { $lastcommand =~ s/\\//; }

# 	return $lastcommand;
# }

# Check whether string starts with a hyphen.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means it starts with a hyphen.
#
# @resource [https://stackoverflow.com/a/34951053]
# @resource [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
# sub __starts_with_hyphen { return ord($_[0]) == 45; }
sub __starts_with_hyphen { return rindex($_[0], '-', 0) == 0; }
# sub __starts_with_hyphen { return substr($_[0], 0, 1) =~ tr/-//; }
# sub __starts_with_hyphen { return substr($_[0], 0, 1) eq '-'; }

# Check whether string contains provided substring.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means substring is found in string.
sub __includes { return rindex($_[0], $_[1]) + 1; }

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
	return ($item =~ tr/\/// || $item eq '~');
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
			if (rindex($arg, '$', 0) == 0) {
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
						if (rindex($line, $last, 0) == 0) {
							# Finally, add to flags array.
							push(@completions, $line);
						}
					} else {
						# Finally, add to flags array.
						push(@completions, $line);
					}
				}
			}

			# If completions array is still empty then add last word to
			# completions array to append a trailing space.
			if (!@completions) { push(@completions, $last); }
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

	# Vars.
	my $argument = '';
	my @arguments = ();
	my $l = length($input);
	my $ll = $l - 1;
	my $args_count = 0;
	my $qchar = '';
	# Loop character variables (current, previous, next characters).
	my $c; my $p; my $n;

	# Input must not be empty.
	if (!$input) { push(@arguments, 0); return; }

	# Command flag syntax:
	# $("COMMAND-STRING" [, [<ARG1>, <ARGN> [, "<DELIMITER>"]]])

	# Loop over every input char: [https://stackoverflow.com/q/10487316]
	# [https://stackoverflow.com/q/18906514]
	# [https://stackoverflow.com/q/13952870]
	# [https://stackoverflow.com/q/1007981]
	for (my $i = 0; $i < $l; $i++) {
		# Cache current/previous/next chars.
		# Note: Reset prev word for 1st char as Perl gets the last string char.
		# [https://perlmaven.com/how-to-set-default-values-in-perl]
		$p = $c // substr($input, $i - 1, !($i - 1 < 0) || 0);
		$c = $n // substr($input, $i, 1);
		# Note: Reset next word for last char as Perl gets the first char.
		# Can't cache for next word by looking back. One must look forward
		# which breaks the point of caching.
		$n = substr($input, $i + 1, !($i == $ll) || 0);

		# State is open and looking for an unescaped quote character.
		if (!$qchar) {
			if (($c eq '"' || $c eq "'") && $p ne '\\') {
				# Set qchar as the opening quote character.
				$qchar = $c;
				# Capture character.
				$argument .= $c;
			}

			# Continuing will ignore all characters outside of quotes.
			# For example, take the example input string: "'name', 'age'".
			# Since the ", " (minus the quotes) is outside of a quoted
			# region and only serve as a delimiter, they don't need to be
			# captured. This means they can be ignored.
			next;

		# Else if state is open (qchar is set), grab all characters until an
		# unescaped qchar is hit.
		} else {
			# Unescape '|' (pipe) characters.
			if ($c eq '\\' && $n eq '|') { next; }

			# Capture character.
			$argument .= $c;

			if ($c eq $qchar && $p ne '\\') {
				# Store argument and reset vars.
				push(@arguments, $argument);
				$args_count++;
				# Clear/reset variables.
				$argument = '';
				$qchar = '';
			}
		}
	}

	# Get last argument.
	if ($argument) { push(@arguments, $argument); }

	# Push argument counter to array.
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
	# my $l = __len(\@args);
	my $l = $#args + 1;

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
	my $argument = '';
	my $qchar = '';
	my $l = length($input);  # Input length.
	my $ll = $l - 1;
	# Loop character variables (current, previous, next characters).
	my $c; my $p; my $n;

	# Input must not be empty.
	if (!$input) { return; }

	# Loop over every input char: [https://stackoverflow.com/q/10487316]
	for (my $i = 0; $i < $l; $i++) {
		# Cache current/previous/next chars.
		# Note: Reset prev word for 1st char as Perl gets the last string char.
		# [https://perlmaven.com/how-to-set-default-values-in-perl]
		$p = $c // substr($input, $i - 1, !($i - 1 < 0) || 0);
		$c = $n // substr($input, $i, 1);
		# Note: Reset next word for last char as Perl gets the first char.
		# Can't cache for next word by looking back. One must look forward
		# which breaks the point of caching.
		$n = substr($input, $i + 1, !($i == $ll) || 0);

		# State is open and looking for an unescaped quote character.
		if (!$qchar) {
			# Check if current character is a quote character.
			if (($c eq '"' || $c eq "'") && $p ne '\\') {
				# Set qchar as the opening quote character.
				$qchar = $c;
				# Capture character.
				$argument .= $c;

			# For non quote characters add all except non-escaped spaces.
			} elsif ($p ne '\\' && $c =~ /[ \t]/) {
				# Store argument and reset vars.
				push(@args, $argument);
				# Clear/reset variables.
				$argument = '';
				$qchar = '';
			} else {
				# Capture character.
				$argument .= $c;
			}

		# Else if state is open (qchar is set), grab all characters until an
		# unescaped qchar is hit.
		} else {
			# Capture character.
			$argument .= $c;

			if ($c eq $qchar && $p ne '\\') {
				# Store argument and reset vars.
				push(@args, $argument);
				# Clear/reset variables.
				$argument = '';
				$qchar = '';
			}
		}
	}

	# Get last argument.
	if ($argument) { push(@args, $argument); }

	# Get/store last character of input.
	$lastchar = !($c ne ' ' && $p ne '\\') ? $c : '';

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
	# my $l = __len(\@args);
	my $l = $#args + 1;

	my @oldchains = ();
	# Following variables are used when validating command chain.
	my $last_valid_chain = '';

	# my @list;

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

			# if (!@list) {
			# 	@list = keys %{ $db{'dict'}{substr($commandchain, 1, 1)} };
			# }
			# # Check that command chain exists in acdef.
			# my $pattern = '^' . quotemeta($commandchain);
			# if (grep(/$pattern/o, @list)) {

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
			if ($item =~ tr/=//) {
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

							# # Lookup flag definitions from acdef.
							# my $letter = substr($oldchain, 1, 1);
							# if ($db{dict}{$letter}{$oldchain}) {
							# 	my $pattern = "${item}\\?(\\||\$)";
							# 	if ($db{dict}{$letter}{$oldchain}{flags} =~ /$pattern/) { $skipflagval = 1; }
							# }

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

						# # Lookup flag definitions from acdef.
						# my $letter = substr($oldchain, 1, 1);
						# if ($db{dict}{$letter}{$oldchain}) {
						# 	my $pattern = "${item}\\?(\\||\$)";
						# 	if ($db{dict}{$letter}{$oldchain}{flags} =~ /$pattern/) { $skipflagval = 1; }
						# }

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
			$autocompletion = ($lword =~ tr/=?//);
		}
	} else {
		if (!__starts_with_hyphen($lword)) {
			# Check if the second to last word is a flag.
			my $sword = $args[-2];
			if (__starts_with_hyphen($sword)) {
				$autocompletion = ($sword =~ tr/=?//);
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

	# # Note: If autocompletion is off check whether we have one of the
	# # following cases: '$ maincommand --flag ' or '$ maincommand --flag val'.
	# # If we do then we show the possible value options for the flag or
	# # try and complete the currently started value option.
	# if (!$autocompletion && $nextchar ne '-') {
	# 	my $islast_aspace = ($lastchar eq ' ');
	# 	# Get correct last word.
	# 	my $nlast = $args[($islast_aspace ? -1 : -2)];
	# 	# acdef commandchain lookup Regex.
	# 	my $pattern = '^' . $commandchain . ' (-{1,2}.*)';
	# 	my $letter = substr($commandchain, 1, 1);
	# 	# The last word (either last or second last word) must be a flag
	# 	# and cannot have contain an eq sign.
	# 	if (__starts_with_hyphen($nlast) && !__includes($nlast, '=')) {
	# 		# Show all available flag option values.
	# 		if ($islast_aspace) {
	# 			# Check if the flag exists in the following format: '--flag='
	# 			if ($db{dict}{$letter}{$commandchain}) {
	# 				# Check if flag exists with option(s).
	# 				my $pattern = $nlast . '=(?!\*).*?(\||$)';
	# 				if ($db{dict}{$letter}{$commandchain}{flags} =~ /$pattern/) {
	# 					# Reset needed data.
	# 					# Modify last used flag.
	# 					# [https://www.perl.com/article/6/2013/3/28/Find-the-index-of-the-last-element-in-an-array/]
	# 					$foundflags[-1] = $foundflags[-1] . '=';
	# 					$last = $nlast . '=';
	# 					$lastchar = '=';
	# 					$autocompletion = 1;
	# 				}
	# 			}
	# 		} else { # Complete currently started value option.
	# 			# Check if the flag exists in the following format: '--flag='
	# 			if ($db{dict}{$letter}{$commandchain}) {
	# 				# Escape special chars: [https://stackoverflow.com/a/576459]
	# 				# [http://perldoc.perl.org/functions/quotemeta.html]
	# 				my $pattern = $nlast . '=' . quotemeta($last) . '.*?(\||$)';

	# 				# Check if flag exists with option(s).
	# 				if ($db{dict}{$letter}{$commandchain}{flags} =~ /$pattern/) {
	# 					# Reset needed data.
	# 					$last = $nlast . '=' . $last;
	# 					$lastchar = substr($last, -1);
	# 					$autocompletion = 1;
	# 				}
	# 			}
	# 		}
	# 	}
	# }

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
		if (__starts_with_hyphen($nlast) && $nlast !~ tr/=//) {
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

	# # Escape last word pattern.
	# # Escape special chars: [https://stackoverflow.com/a/576459]
	# # [http://perldoc.perl.org/functions/quotemeta.html]
	# # [https://stackoverflow.com/a/2458538]
	# $elast_ptn = '^' . quotemeta($last);

	# Parse used flags into a hash for quick lookup later on.
	# [https://perlmaven.com/multi-dimensional-hashes]
	foreach my $uflag (@foundflags) {
		# Parse used flag without RegEx.
		my $uflag_fkey = $uflag;
		my $uflag_value = '';

		# If flag contains an eq sign.
		# [https://stackoverflow.com/a/87565]
		# [https://perldoc.perl.org/perlvar.html]
		# [https://www.perlmonks.org/?node_id=327021]
		if ($uflag_fkey =~ tr/\=//) {
			# Get eq sign index.
			my $eqsign_index = index($uflag, '=');
			$uflag_fkey = substr($uflag, 0, $eqsign_index);
			$uflag_value = substr($uflag, $eqsign_index + 1);
		}

		# Store flag key and its value in hashes.
		# [https://perlmaven.com/multi-dimensional-hashes]

		if ($uflag_value) {$usedflags{$uflag_fkey}{$uflag_value} = 1;}
		else { $usedflags{valueless}{$uflag_fkey} = undef; }
	}

	return;
}

# Lookup command/subcommand/flag definitions from the acdef to return
#     possible completions list.
sub __lookup {
	# Skip logic if last word is quoted or completion variable is off.
	if ($isquoted || !$autocompletion) { return; }

	# Flag completion (last word starts with a hyphen):
	if (__starts_with_hyphen($last)) {
		# Lookup flag definitions from acdef.
		my $letter = substr($commandchain, 1, 1) // '';
		if ($db{dict}{$letter}{$commandchain}) {
			# Continue if rows exist.
			my %parsedflags;

			# Get flags list.
			my $flag_list = $db{dict}{$letter}{$commandchain}{flags};

			# Set completion type:
			$type = 'flag';

			# If no flags exist skip line.
			if ($flag_list eq '--') { return; }

			# Split by unescaped pipe '|' characters:
			# [https://www.perlmonks.org/bare/?node_id=319761]
			# my @flags = split(/(?:\\\\\|)|(?:(?<!\\)\|)/, $flag_list);
			my @flags = split(/(?<!\\)\|/, $flag_list);

			# Parse last flag without RegEx.
			my $last_fkey = $last;
			# my $flag_isbool
			my $last_eqsign = '';
			my $last_multif = '';
			my $last_value = '';

			# If flag contains an eq sign.
			# [https://stackoverflow.com/a/87565]
			# [https://perldoc.perl.org/perlvar.html]
			# [https://www.perlmonks.org/?node_id=327021]
			if ($last_fkey =~ tr/\=//) {
				# Get eq sign index.
				my $eqsign_index = index($last, '=');
				$last_fkey = substr($last, 0, $eqsign_index);
				$last_value = substr($last, $eqsign_index + 1);

				# Check for multi-flag indicator.
				if (rindex($last_value, '*', 0) == 0) {
					$last_multif = '*';
					$last_value = substr($last_value, 1);
				}

				$last_eqsign = '=';
			}
			my $last_val_quoted = __is_lquoted($last_value);

			# Loop over flags to process.
			foreach my $flag (@flags) {
				# # Skip flags not starting with same char as last word.
				# [https://stackoverflow.com/a/55455061]
				if (rindex($flag, $last_fkey, 0) != 0) { next; }

				# Breakup flag into its components (flag/value/etc.).
				# [https://stackoverflow.com/q/19968618]

				my $flag_fkey = $flag;
				my $flag_isbool = '';
				my $flag_eqsign = '';
				my $flag_multif = '';
				my $flag_value = '';
				my $cflag = '';

				# If flag contains an eq sign.
				# [https://stackoverflow.com/a/87565]
				# [https://perldoc.perl.org/perlvar.html]
				# [https://www.perlmonks.org/?node_id=327021]
				if ($flag_fkey =~ tr/\=//) {
					my $eqsign_index = index($flag, '=');
					$flag_fkey = substr($flag, 0, $eqsign_index);
					$flag_value = substr($flag, $eqsign_index + 1);
					$flag_eqsign = '=';

					# Extract boolean indicator.
					if (rindex($flag_fkey, '?') > -1) {
						# Remove boolean indicator.
						$flag_isbool = chop($flag_fkey);
					}

					# Check for multi-flag indicator.
					if (rindex($flag_value, '*', 0) == 0) {
						$flag_multif = '*';
						$flag_value = substr($flag_value, 1);

						# Track multi-starred flags.
						$usedflags{multi}{$flag_fkey} = undef;
					}

					# Create completion item flag.
					$cflag = "$flag_fkey=$flag_value";

					# If value is a command-flag: --flag=$("<COMMAND-STRING>"),
					# run command and add returned words to flags array.
					if (rindex($flag_value, "\$(", 0) == 0 && substr($flag_value, -1) eq ')') {
						__execute_command($flag_value, \@flags, $last_fkey);
						# [https://stackoverflow.com/a/31288153]
						# Skip flag to not add literal command to completions.
						next;
					}

					# Store flag for later checks...
					$parsedflags{"$flag_fkey=$flag_value"} = undef;
				} else {
					# Check for boolean indicator.
					if (rindex($flag_fkey, '?') > -1) {
						# Remove boolean indicator and reset vars.
						$flag_isbool = chop($flag_fkey);
					}

					# Create completion item flag.
					$cflag = $flag_fkey;

					# Store flag for later checks...
					$parsedflags{"$flag_fkey"} = undef;
				}

				# Unescape flag?
				# $flag = __unescape($flag);

				# If the last flag/word does not have an eq-sign, skip flags
				# with values as it's pointless to parse them. Basically, if
				# the last word is not in the form "--form= + a character",
				# don't show flags with values (--flag=value).
				if (!$last_eqsign && $flag_value && !$flag_multif) { next; }

				# START: Remove duplicate flag logic. ==========================

				# Dupe value defaults to false.
				my $dupe = 0;

				# If it's a multi-flag then let it through.
				if (exists($usedflags{multi}{$flag_fkey})) {

					# Although a multi-starred flag, check if value has been used or not.
					if ($flag_value && exists($usedflags{$flag_fkey}{$flag_value})) { $dupe = 1; }

				} elsif (!$flag_eqsign) {

					# Valueless --flag (no-value) dupe check.
					if (exists($usedflags{valueless}{$flag_fkey})) { $dupe = 1; }

				} else { # --flag=<value> (with value) dupe check.

					# Count substring occurrences: [https://stackoverflow.com/a/9538604]
					# Dereference before use: [https://stackoverflow.com/a/37438262]
					my $flag_values = $usedflags{$flag_fkey};
					# my @count = (keys %$flag_values);

					# If at least 1 occurrence in used hash, flag has been used.
					# if (@count && $flag_value) { $dupe = 1; }
					# if (@count) { $dupe = 1; }
					if ($flag_values && !$flag_value) { $dupe = 1; }

					# If there is exactly 1 occurrence and the flag matches the
					# RegExp pattern we undupe flag as the 1 occurrence is being
					# completed (i.e. a value is being completed).
					# if ($flag_value) { $dupe = 0; }
				}

				# If flag is a dupe skip it.
				if ($dupe) { next; }

				# END: Remove duplicate flag logic. ============================

				# If last word is in the form → "--flag=" then we need to
				# remove the last word from the flag to only return its
				# options/values.
				if ($last_eqsign) {
					# Flag value has to start with last flag value.
					if (rindex($flag_value, $last_value, 0) != 0 || (!$flag_value)) { next; }
					# Reset completions array value.
					$cflag = $flag_value;
				}

				# Note: This is more of a hack check. Values with
				# special characters will sometime by-pass the
				# previous checks so do one file check. If the
				# flag is in the following form:
				# --flags="value-string" then we do not add is to
				# the completions list. Final option/value check.
				# my $__isquoted = ($flag_eqsign && $flag_val_quoted);
				# if (!$__isquoted && $flag ne $last) {

				push(@completions, $cflag);
			}

			# # Note: If the last word (the flag in this case) is an
			# # options flag (i.e. --flag=val) we need to remove the
			# # possible already used value. For example take the
			# # following scenario. Say we are completing the following
			# # flag '--flag=7' and our two options are '7' and '77'.
			# # Since '7' is already used we remove that value to leave
			# # '77' so that on the next tab it can be completed to
			# # '--flag=77'.
			# my $l = $#completions;

			# # Note: Account for quoted strings. If the last value is
			# # quoted, then add closing quote.
			# if ($last_val_quoted) {
			# 	# Get starting quote (i.e. " or ').
			# 	my $quote = substr($last_value, 0, 1);

			# 	# Close string with matching quote if not already.
			# 	if (substr($last_value, -1) ne $quote) {
			# 		$last_value .= $quote;
			# 	}

			# 	# Add quoted indicator to type string to later escape
			# 	# for double quoted strings.
			# 	$type = 'flag;quoted';
			# 	if ($quote eq '"') {
			# 		$type .= ';noescape';
			# 	}

			# 	# If the value is empty return.
			# 	if (length($last_value) == 2) {
			# 		push(@completions, "$quote$quote");
			# 		return;
			# 	}
			# }

			# # If the last word contains an eq sign, it has a value
			# # option, and there are more than 2 possible completions
			# # we remove the already used option.
			# if ($last_value && ($l + 1) >= 2) {
			# 	for (my $i = $l; $i >= 0; $i--) {
			# 		if (length($completions[$i]) == length($last_value)) {
			# 			# Remove item from array.
			# 			splice(@completions, $i, 1);
			# 		}
			# 	}
			# }

			# If no completions exists then simply add last item to Bash
			# completion can add append a space to it.
			if (!@completions) {
				my $key = $last_fkey . (!$last_value ? "" : "=$last_value");
				my $item = (!$last_value ? $last : $last_value);
				# [https://www.perlmonks.org/?node_id=1003939]
				if (exists($parsedflags{$key})) { push(@completions, $item); }
			} else {
				# Note: If the last word (the flag in this case) is an options
				# flag (i.e. --flag=val) we need to remove the possibly already
				# used value. For example take the following scenario. Say we
				# are completing the following flag '--flag=7' and our two
				# options are '7' and '77'. Since '7' is already used we remove
				# that value to leave '77' so that on the next tab it can be
				# completed to '--flag=77'.
				if ($last_value && @completions >= 2) {
					my $last_val_length = length($last_value);
					# Remove values of same length as current value.
					# [https://stackoverflow.com/a/15952649]
					@completions = grep {length != $last_val_length} @completions;
				}
			}
		}
	} else { # Command completion:

		# Set completion type:
		$type = 'command';

		# If command chain and used flags exits, don't complete.
		if (%usedflags && $commandchain) {
			# Reset commandchain.
			$commandchain = "" . (!$last ? "" : $last);
		}

		# my $pattern = '^' . quotemeta($commandchain);
		my $pattern = '^' . $commandchain;

		# When there is no command chain get the first level commands.
		if (!$commandchain && !$last) {
			@completions = keys %{ $db{levels}{1} };
		} else {
			my $letter = substr($commandchain, 1, 1);
			# [https://stackoverflow.com/a/33102092]
			my @rows = (keys %{ $db{dict}{$letter} } );
			my $lastchar_notspace = ($lastchar ne ' ');

			# If no rows...
			if (!@rows) { return;}

			my %usedcommands;
			my @commands = split(/(?<!\\)\./, substr($commandchain, 1));
			my $level = $#commands;
			# Increment level if completing a new command level.
			if ($lastchar eq ' ') { $level++; }

			# Get commandchains for specific letter outside of loop.
			my %h = %{ $db{dict}{$letter} };

			# Split rows by lines: [https://stackoverflow.com/a/11746174]
			foreach my $row (@rows) {
				# Skip rows not passing pattern.
				# if (index($row, $commandchain)) { next; }
				if (rindex($row, $commandchain, 0)) { next; }

				my @cmds = @{ $h{$row}{commands} };
				# Get the needed level.
				$row = $cmds[$level] // undef;

				# Add last command it not yet already added.
				if (!$row || exists($usedcommands{$row})) { next; }
				# If the character before the caret is not a
				# space then we assume we are completing a
				# command.
				if ($lastchar_notspace) {
					# Since we are completing a command we only
					# want words that start with the current
					# command we are trying to complete.
					if (rindex($row, $last, 0) == 0) { push(@completions, $row); }
					# if (index($row, $last) == 0) { push(@completions, $row); }
				} else {
					# If we are not completing a command then
					# we return all possible word completions.
					push(@completions, $row);
				}

				# Store command in hash.
				$usedcommands{$row} = undef;
			}
		}

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
				my $command_str = $db{fallbacks}{$copy_commandchain};
				if ($command_str) {
					# Store matched RegExp pattern value.
					my $value = $command_str;
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
							if (rindex($value, $last, 0) == 0) {
							# if ($value =~ /$elast_ptn/) {
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
	my $isflag_type = rindex($type, 'f', 0) == 0;

	# [https://perlmaven.com/transforming-a-perl-array-using-map]
	# [https://stackoverflow.com/a/2725641]
	# Loop over completions and append to list.
	@completions = map {
		# Add trailing space to all completions except to flag
		# completions that end with a trailing eq sign, commands
		# that have trailing characters (commands that are being
		# completed in the middle), and flag string completions
		# (i.e. --flag="some-word...).
		my $final_space = (
			$isflag_type
			# Item cannot be quoted.
			&& !(rindex($_, '=') + 1)
			&& ((rindex $_, '"', 0) == -1 || (rindex $_, '\'', 0) == -1)
			&& !$nextchar
		) ? ' ' : '';

		# Final returned item.
		"$sep$_$final_space";
	} @completions;

	# Return data.
	print $lines . join('', @completions);

	return;
}

# Completion logic:

# # # Run [pre-parse] hooks.
# __hook_filepaths();
# # # Variable must be populated with hook file paths to run scripts.
# # if ($hpaths) { __hook_acdef();__hook_input(); }
# __hook_pre();

sub __makedb {
	# # Set cache variable to false.
	# my $cache = 0;
	# my $last_mtime;
	# my $basedir = "$hdir/.nodecliac/registry/$maincommand";
	# my $cachedir = "$basedir/cache";
	# # Check for cached db data directory exists.
	# if (-d $cachedir) {
	# 	# Get last modified .acdef file time to compare.
	# 	my $resourcepath = "$cachedir/last_modified.text";
	# 	if (-f $resourcepath) {
	# 		my $last_modified = do{local(@ARGV,$/)=$resourcepath;<>};
	# 		chomp($last_modified); # Remove trailing new line.
	# 		# Get ACDEF file's last modified time.
	# 		$last_mtime = (stat("$basedir/$maincommand.acdef"))[9];
	# 		# Set cache variable.
	# 		$cache = (($last_modified > $last_mtime) || 0);
	# 	}
	# }

	# To list all commandchains/flags without a commandchain.
	if (!$commandchain) {

		# Note: Although not DRY, per say, dedicating specific logic routes
		# speeds up auto-completion tremendously.

		# For first level commands only...
		if (!$last) {

			# if ($cache) {
			# 	# Get the command's ACDEF file.
			# 	my $resourcepath = "$cachedir/l1commands.text";
			# 	# If the ACDEF file does not exist then exit script.
			# 	# exit if (not -f $acdefpath);
			# 	my $commands = do{local(@ARGV,$/)=$resourcepath;<>}; # Get the acdef definitions file.
			# 	chomp($commands); # Remove trailing new line.

			# 	# for (split /\n/, $commands) { $db{levels}{1}{$_} = undef; }
			# 	# [https://stackoverflow.com/a/16157433]
			# 	$db{levels}{1}{$_}++ for (split /\n/, $commands);

			# 	return;
			# }

			for my $line (split /\n/, $acdef) {
				# First character must be a period or a space.
				if (rindex($line, '.', 0) != 0) { next; }

				# Get command/flags/fallbacks from each line.
				my $space_index = index($line, ' ');
				my $chain = substr($line, 1, $space_index - 1 );

				# Parse chain.
				my $dot_index = index($chain, '.');
				my $command = substr($chain, 0, $dot_index != -1 ? $dot_index : $space_index);
				$db{levels}{1}{$command} = undef;
				# $db{levels}{1}{$command}++;
			}

		# For first level flags...
		} else {

			# Get main command flags.
			if ($acdef =~ /^ ([^\n]+)/m) {$db{dict}{''}{''} = { flags => $1 }; }

			# my %letters;
			# for my $line (split /\n/, $acdef) {
			# 	# First character must be a period or a space.
			# 	if (rindex($line, '.', 0) != 0) { next; }

			# 	# Get command/flags/fallbacks from each line.
			# 	my $space_index = index($line, ' ');
			# 	my $chain = substr($line, 0, $space_index - 1);

			# 	# Create dict entry if it doesn't already exist.
			# 	$letters{substr($chain, 1, 1)}{$chain} = {
			# 		flags => substr($line, $space_index + 1)
			# 	};
			# }
			# # Add letters hash to db (main) hash.
			# $db{dict} = \%letters;
		}

	# General auto-completion. Parse entire .acdef file contents.
	} else {
		# Get the first letter of commandchain to better filter ACDEF data.
		my $fletter = substr($commandchain, 1, 1);
		my %letters;

		# Extract and place command chains and fallbacks into their own arrays.
		# [https://www.perlmonks.org/?node_id=745018], [https://perlmaven.com/for-loop-in-perl]
		for my $line (split /\n/, $acdef) {
			# Get first and second characters.
			my $schar = substr($line, 1, 1);

			# First character must be a period or a space. Or if the command
			# line does not start with the first letter of the command chain
			# then we skip all line parsing logic.
			if ($schar ne $fletter) { next; }

			# Get command/flags/fallbacks from each line.
			my $space_index = index($line, ' ');
			my $chain = substr($line, 1, $space_index - 1);
			my $remainder = substr($line, $space_index + 1);

			# Parse chain.
			# [https://stackoverflow.com/questions/87380/how-can-i-find-the-location-of-a-regex-match-in-perl]
			my @commands = split(/(?<!\\)\./, $chain);
			$db{levels}{1}{$commands[0]} = undef;

			# [https://stackoverflow.com/a/6973660]
			# $db{levels}{$counter++}{$commands[0]} = undef;
			# push(@{ $db{'levels'}{$counter} }, $command);

			# Cleanup remainder (flag/command-string).
			if (ord($remainder) == 45) {
				# Create dict entry letter/command chain.
				# [https://stackoverflow.com/questions/6565286/storing-a-hash-in-a-hash]
				# [https://perlmonks.org/?node=References+quick+reference]
				my %h = ("commands", \@commands, "flags", $remainder);
				$letters{$schar}{".$chain"} = \%h;

				# $db{dict}{$letter}{$chain ? ".$chain" : ''} = {
				# 	commands => \@commands,
				# 	flags => $remainder
				# };
			} else {
				# Store fallback.
				$db{fallbacks}{".$chain"} = substr($remainder, 8);
			}
		}

		# Add letters hash to db (main) hash.
		$db{dict} = \%letters;
	}

	# delete($db{'levels'});
	# delete($db{'dict'});
	# delete($db{'fallbacks'});
	# use Data::Dumper qw(Dumper);
	# print Dumper \%db;
}


# (cli_input*) → parser → extractor → lookup → printer
# *Supply CLI input from start to caret index.
__parser();__extractor();__makedb();__lookup();__printer();
