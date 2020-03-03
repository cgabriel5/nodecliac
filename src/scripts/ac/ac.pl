#!/usr/bin/perl
# '-d:NYTProf' to profile script.

# use strict;
# use warnings;
# use diagnostics;

my $oinput = $ARGV[0]; # Original unmodified CLI input.
my $cline = $ARGV[1]; # CLI input (could be modified via pre-parse).
my $cpoint = int($ARGV[2]); # Caret index when [tab] key was pressed.
my $maincommand = $ARGV[3]; # Get command name from sourced passed-in argument.
my $acdef = $ARGV[4]; # Get the acdef definitions file.

my @args = ();
my $last = '';
my $type = '';
my @foundflags = ();
my @completions = ();
my $commandchain = '';
my $lastchar; # Character before caret.
my $nextchar = substr($cline, $cpoint, 1); # Character after caret.
my $cline_length = length($cline); # Original input's length.
my $isquoted = 0;
my $autocompletion = 1;
my $input = substr($cline, 0, $cpoint); # CLI input from start to caret index.
my $input_remainder = substr($cline, $cpoint, -1); # CLI input from caret index to input string end.
my $hdir = $ENV{'HOME'};

my %db;
$db{'fallbacks'} = {};

my %usedflags;
$usedflags{'valueless'};
$usedflags{'multi'};
$usedflags{'counts'};

my $used_default_pa_args = '';
my $prefix = 'NODECLIAC_';

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

# --------------------------------------------------------- VALIDATION-FUNCTIONS

# Peek string for '/'/'~'. If contained assume it's a file/dir.
#
# @param  {string} item - The string to check.
# @return {number} - 0: false, 1: true
sub __is_file_or_dir {
	my ($item) = @_;
	return ($item =~ tr/\/// || $item eq '~');
}

# Escape '\' chars and replace unescaped slashes '/' with '.'.
#
# @param  {string} item - The item (command) string to escape.
# @return {string} - The escaped item (command) string.
sub __normalize_command {
	my ($item) = @_;

	if (__is_file_or_dir($item)) { return $item; }
	return $item =~ s/\./\\\\./r; # Escape periods.
}

# Validates whether command/flag (--flag) only contain valid characters.
#     Containing invalid chars exits script - terminating completion.
#
# @param  {string} item - The word to check.
# @return {string} - The validated argument.
sub __validate_flag {
	my ($item) = @_;

	if (__is_file_or_dir($item)) { return $item; }
	if ($item =~ tr/-_a-zA-Z0-9//c) { exit; }

	# Note: tr///c does not do any variable interpolation so character
	# sets need to be hardcoded: [https://www.perlmonks.org/?node_id=445971]
	# [https://stackoverflow.com/a/15534516]

	return $item;
}

# Look at __validate_flag for function details.
sub __validate_command {
	my ($item) = @_;
	if (__is_file_or_dir($item)) { return $item; }
	if ($item =~ tr/-._:\\a-zA-Z0-9//c) { exit; }
	return $item;
}

# ------------------------------------------------------------------------------

# Parse and run command-flag (flag) or default command chain.
#
# @param {string} - The command to run in string.
# @return - Nothing is returned.
#
# Create cmd-string: `$command 2> /dev/null`
# 'bash -c' with arguments documentation:
# @resource [https://stackoverflow.com/q/26167803]
# @resource [https://unix.stackexchange.com/a/144519]
# @resource [https://stackoverflow.com/a/1711985]
# @resource [https://stackoverflow.com/a/15678831]
# @resource [https://stackoverflow.com/a/3374285]
sub __exec_command {
	my ($command_str) = @_;

	my @arguments = @{ __parse_cmdstr($command_str) };
	my $count = $#arguments + 1;
	my $command = substr($arguments[0], 1, -1); # Unquote.
	my $delimiter = "\$\\r\?\\n";
	my @r = ();

	if ($count > 1) { # Add arguments.
		for (my $i = 1; $i < $count; $i++) {
			my $arg = $arguments[$i];

			# Run '$' string.
			if (rindex($arg, '$', 0) == 0) {
				$arg = substr($arg, 1);
				my $qchar = substr($arg, 0, 1);
				$arg = substr($arg, 1, -1); # Unquote.
				$command .= " \"$($qchar" . $arg . "$qchar)\"";
			} else {
				$arg = substr($arg, 1, -1); # Unquote.
				$command .= " $arg";
			}
		}
	}

	__set_envs();
	my $res = do { open(EPIPE, '-|', $command); local $/; <EPIPE>; };
	if ($res) { @r = split(/$delimiter/m, $res); }
	return \@r;
}

# Parse command string `$("")` and returns its arguments.
#
# Syntax:
# $("COMMAND-STRING" [, [<ARG1>, <ARGN> [, "<DELIMITER>"]]])
#
# @param  {string} input - The string command-flag to parse.
# @return {string} - The cleaned command-flag string.
sub __parse_cmdstr {
	my ($input) = @_;

	my $argument = '';
	my @arguments = ();
	my $qchar = '';
	my $c; my $p;

	if (!$input) { return \@arguments; }

	while ($input) {
		$c = substr($input, 0, 1, '');
		$p = chop($argument);
		$argument .= $p;

		if (!$qchar) {
			if ($c =~ tr/"'// && $p ne '\\') {
				$qchar = $c;
				$argument .= $c;
			}
		} else {
			if ($c eq '|' && $p eq '\\') { chop($argument); }
			$argument .= $c;

			if ($c eq $qchar && $p ne '\\') {
				push(@arguments, $argument);
				$argument = '';
				$qchar = '';
			}
		}
	}

	if ($argument) { push(@arguments, $argument); }
	return \@arguments; # [https://stackoverflow.com/a/11303607]
}

# Set environment variables to access in custom scripts.
#
# @param  {string} arguments - N amount of env names to set.
# @return - Nothing is returned.
sub __set_envs {
	my $l = $#args + 1;

	my %envs = (
		# nodecliac exposed Bash env vars.

		"${prefix}COMP_LINE" => $cline, # Original (unmodified) CLI input.
		# Caret index when [tab] key was pressed.
		"${prefix}COMP_POINT" => $cpoint,

		# nodecliac env vars.

		# The command auto completion is being performed for.
		"${prefix}MAIN_COMMAND" => $maincommand,
		"${prefix}COMMAND_CHAIN" => $commandchain, # The parsed command chain.
		# "${prefix}USED_FLAGS" => $usedflags, # The parsed used flags.
		# The last parsed word item (note: could be a partial word item.
		# This happens when the [tab] key gets pressed within a word item.
		# For example, take the input 'maincommand command'. If
		# the [tab] key was pressed like so: 'maincommand comm[tab]and' then
		# the last word item is 'comm' and it is a partial as its remaining
		# text is 'and'. This will result in using 'comm' to determine
		# possible auto completion word possibilities.).
		"${prefix}LAST" => $last,
		"${prefix}PREV" => $args[-2], # The word item preceding last word item.
		"${prefix}INPUT" => $input, # CLI input from start to caret index.
		"${prefix}INPUT_ORIGINAL" => $oinput, # Original unmodified CLI input.
		# CLI input from start to caret index.
		"${prefix}INPUT_REMAINDER" => $input_remainder,
		"${prefix}LAST_CHAR" => $lastchar, # Character before caret.
		# Character after caret. If char is not '' (empty) then the last word
		# item is a partial word.
		"${prefix}NEXT_CHAR" => $nextchar,
		# Original input's length.
		"${prefix}COMP_LINE_LENGTH" => $cline_length,
		# CLI input length from beginning of string to caret position.
		"${prefix}INPUT_LINE_LENGTH" => length($input),
		# Amount arguments parsed before caret position/index.
		"${prefix}ARG_COUNT" => $l,
		# Store collected positional arguments after validating the
		# command-chain to access in plugin auto-completion scripts.
		"${prefix}USED_DEFAULT_POSITIONAL_ARGS" => $used_default_pa_args
	);

	# Add parsed arguments as individual env variables.
	my $i = 0; foreach my $arg (@args) { $envs{"${prefix}ARG_${i}"} = $arg; $i++; }

	# Set all env variables.
	if (@_ == 0) { foreach my $key (keys %envs) { $ENV{$key} = $envs{$key}; }
	} else { # Set requested ones only.
		foreach my $env_name (@_) {
			my $key = "${prefix}$env_name";
			if (exists($envs{$key})) { $ENV{$key} = $envs{$key}; }
		}
	}
}

# --------------------------------------------------------------- MAIN-FUNCTIONS

# Parses CLI input.
#
# @return - Nothing is returned.
sub __parser {
	my $argument = '';
	my $qchar = '';
	my $input = $input;
	my $c; my $p;

	if (!$input) { return; }

	# Spreads input, ex: '-n5 -abc "val"' => '-n 5 -a -b -c "val"'
	#
	# @param  {string} argument - The string to spread.
	# @return {string} - The remaining argument.
	sub spread {
		my ($argument, $args) = @_;

		if (length($argument) >= 3 && substr($argument, 1, 1) ne '-') {
			substr($argument, 0, 1, "");
			my $lchar = chop($argument);
			$argument .= $lchar;

			if ($lchar =~ tr/1234567890//) {
				my $argletter = substr($argument, 0, 1);
				substr($argument, 0, 1, "");
				push(@$args, "-$argletter");
			} else {
				my @chars = split(//, $argument);
				my $max = $#chars;
				my $i = 0; my $hyphenref = 0; foreach my $char (@chars) {
					# Handle: 'sudo wget -qO- https://foo.sh':
					# Hitting a hyphen breaks loop. All characters at hyphen
					# and beyond are now the value of the last argument.
					if ($char eq '-') { $hyphenref = 1; last; }

					# Note: If the argument is not a hyphen and is the last
					# item in the array, remove it from the array as it will
					# get added back later in the main loop.
					elsif (i == max) { last; }

					push(@$args, "-$char"); $i++;
				}

				# Reset value to final argument.
				$argument = !$hyphenref ? "-$lchar" : substr($argument, $i);
			}
		}

		return $argument;
	}

	while ($input) {
		$c = substr($input, 0, 1, '');
		$p = chop($argument);
		$argument .= $p;

		if ($qchar) {
			$argument .= $c;

			if ($c eq $qchar && $p ne '\\') {
				# Note: Check that argument is spaced out. For example, this
				# is invalid: '$ nodecliac format --indent="t:1"--sa'
				# ----------------------------------------------^. Should be:
				#          '$ nodecliac format --indent="t:1" --sa'
				# -------------------------------------------^Whitespace char.
				# If argument is not spaced out or at the end of the input
				# do not add it to the array. Just skip to next iteration.
				if ($input && rindex($input, ' ', 0) != 0) { next; }

				push(@args, rindex($argument, '-', 0) ? $argument : spread($argument, \@args));
				$argument = '';
				$qchar = '';
			}
		} else {
			if ($c =~ tr/"'// && $p ne '\\') {
				$qchar = $c;
				$argument .= $c;
			} elsif ($c =~ tr/ \t// && $p ne '\\') {
				if (!$argument) { next; }

				push(@args, rindex($argument, '-', 0) ? $argument : spread($argument, \@args));
				$argument = '';
				$qchar = '';
			} else { $argument .= $c; }
		}
	}

	# Get last argument.
	if ($argument) { push(@args, rindex($argument, '-', 0) ? $argument : spread($argument, \@args)); }
	# Get/store last char of input.
	$lastchar = !($c ne ' ' && $p ne '\\') ? $c : '';
}

# Determine command chain, used flags, and set needed variables.
#
# @return - Nothing is returned.
sub __extractor {
	my $l = $#args + 1;
	my @oldchains = ();
	my $last_valid_chain = '';
	my $collect_used_pa_args = '';
	my %normalized;

	for (my $i = 1; $i < $l; $i++) {
		my $item = $args[$i];
		my $nitem = $args[$i + 1];

		# Skip quoted or escaped items.
		if (substr($item, 0, 1) =~ tr/"'// || $item =~ tr/\\//) { next; }

		if (rindex($item, '-', 0)) {
			if ($collect_used_pa_args) {
				$used_default_pa_args .= "$item\n";
				next;
			}

			$commandchain .= '.' . __normalize_command($item);

			# Validate command chain.
			my $pattern = '^' . quotemeta($commandchain) . '[^ ]* ';
			if ($acdef =~ /$pattern/m) { $last_valid_chain = $commandchain;
			} else {
				# Revert to last valid chain.
				$commandchain = $last_valid_chain;
				$collect_used_pa_args = 1;
				$used_default_pa_args .= "$item\n";
			}

			@foundflags = ();

		} else { # Flag...

			# Store to revert if needed.
			if ($commandchain) { push(@oldchains, $commandchain); }

			$commandchain = '';
			$used_default_pa_args = '';
			$collect_used_pa_args = 0;

			# Normalize colons: '--flag:value' to '--flag=value'.
			if (!exists($normalized{$i}) && $item =~ tr/://) {
				$item =~ s/[:=]/=/;
				$args[$i] = $item;
				$normalized{$i} = undef; # Memoize.
			}

			if ($item =~ tr/=//) { push(@foundflags, $item); next; }

			my $vitem = __validate_flag($item);
			my $skipflagval = 0;

			# If next item exists check if it's a value for the current flag
			# or if it's another flag and do the proper actions for both.
			if ($nitem) {
				# Normalize colons: '--flag:value' to '--flag=value'.
				if (!exists($normalized{$i}) && $nitem =~ tr/://) {
					$nitem =~ s/[:=]/=/;
					$args[$i] = $nitem;
					$normalized{$i} = undef; # Memoize.
				}

				# If next word is a value (not a flag).
				if (rindex($nitem, '-', 0)) {
					my $pattern = '^' . quotemeta($oldchains[-1]) . ' (.+)$';
					if ($acdef =~ /$pattern/m) {
						# If flag is boolean set flag.
						$pattern = "$item\\?(\\||\$)";
						if ($1 =~ /$pattern/) { $skipflagval = 1; }
					}

					# If flag isn't found, add it as its value.
					if (!$skipflagval) {
						$vitem .= "=$nitem";
						$i++;

					# Boolean flag so add marker.
					} else { $args[$i] = $args[$i] . '?'; }
				}

				push(@foundflags, $vitem);

			} else {
				my $pattern = '^' . quotemeta($oldchains[-1]) . ' (.+)$';
				if ($acdef =~ /$pattern/m) {
					# If flag is boolean set flag.
					$pattern = "$item\\?(\\||\$)";
					if ($1 =~ /$pattern/) { $skipflagval = 1; }
				}

				# Boolean flag so add marker.
				if ($skipflagval) { $args[$i] = $args[$i] . '?'; }

				push(@foundflags, $vitem);
			}
		}

	}

	# Validate command chain.
	$commandchain = __validate_command($commandchain || $oldchains[-1]);

	# Determine whether to turn off autocompletion.
	my $lword = $args[-1];
	if ($lastchar eq ' ') {
		if (rindex($lword, '-', 0) == 0) {
			$autocompletion = ($lword =~ tr/=?//);
		}
	} else {
		if (rindex($lword, '-', 0)) {
			my $sword = $args[-2];
			if (rindex($sword, '-', 0) == 0) {
				$autocompletion = ($sword =~ tr/=?//);
			}
		}
	}

	# Remove boolean markers from flags.
	for my $i (0 .. $#args) {
		my $arg = $args[$i];
		if (rindex($arg, '-', 0) == 0 && $arg !~ tr/=// && chop($arg) eq '?') {
			$args[$i] = $arg;
		}
	}

	# Set last word.
	$last = ($lastchar eq ' ') ? '' : $args[-1];

	# Check if last word is quoted.
	if (substr($last, 0, 1) =~ tr/"'//) { $isquoted = 1; }

	# Note: If autocompletion is off check for one of following cases:
	# '$ maincommand --flag ' or '$ maincommand --flag val'. If so, show
	# value options for the flag or complete started value option.
	if (!$autocompletion && $nextchar ne '-') {
		my $islast_aspace = ($lastchar eq ' ');
		my $nlast = $args[($islast_aspace ? -1 : -2)];
		my $pattern = '^' . $commandchain . ' (.*)$';

		if (rindex($nlast, '-', 0) == 0 && $nlast !~ tr/=//) {
			if ($islast_aspace) {
				# Check if flag exists like: '--flag='
				if ($acdef =~ /$pattern/m) {
					# Check if flag exists with option(s).
					my $pattern = $nlast . '=(?!\*).*?(\||$)';
					if ($1 =~ /$pattern/) {
						# Modify last used flag.
						$foundflags[-1] = $foundflags[-1] . '=';
						$last = $nlast . '=';
						$lastchar = '=';
						$autocompletion = 1;
					}
				}
			} else { # Complete currently started value option.
				# Check if flag exists like: '--flag='
				if ($acdef =~ /$pattern/m) {
					# Check if flag exists with option(s).
					my $pattern = $nlast . '=(' . quotemeta($last) . '|\$\().*?(\||$)';
					if ($1 =~ /$pattern/) {
						$last = $nlast . '=' . $last;
						$lastchar = substr($last, -1);
						$autocompletion = 1;
					}
				}
			}
		}
	}

	# Store used flags for later lookup.
	foreach my $uflag (@foundflags) {
		my $uflag_fkey = $uflag;
		my $uflag_value = '';

		# [https://stackoverflow.com/a/87565]
		if ($uflag_fkey =~ tr/\=//) {
			my $eqsign_index = index($uflag, '=');
			$uflag_fkey = substr($uflag, 0, $eqsign_index);
			$uflag_value = substr($uflag, $eqsign_index + 1);
		}

		if ($uflag_value) {$usedflags{$uflag_fkey}{$uflag_value} = 1;}
		else { $usedflags{valueless}{$uflag_fkey} = undef; }

		# Track times flag was used.
		$usedflags{counts}{$uflag_fkey}++;
	}
}

# Lookup acdef definitions.
#
# @return - Nothing is returned.
sub __lookup {
	if ($isquoted || !$autocompletion) { return; }

	if (rindex($last, '-', 0) == 0) {
		$type = 'flag';

		my $letter = substr($commandchain, 1, 1) // '';
		if ($db{dict}{$letter}{$commandchain}) {
			my %parsedflags;
			my $flag_list = $db{dict}{$letter}{$commandchain}{flags};

			# If a placeholder get its contents.
			my $pattern = '^--p#(.{6})$';
			if ($flag_list =~ /$pattern/) {
				$flag_list = do{local(@ARGV,$/)="$hdir/.nodecliac/registry/$maincommand/placeholders/$1";<>};
			}

			if ($flag_list eq '--') { return; }

			# Split by unescaped pipe '|' characters:
			# [https://www.perlmonks.org/bare/?node_id=319761]
			# my @flags = split(/(?:\\\\\|)|(?:(?<!\\)\|)/, $flag_list);
			my @flags = split(/(?<!\\)\|/, $flag_list);

			my $last_fkey = $last;
			my $last_eqsign = '';
			# my $last_multif = '';
			my $last_value = '';

			if ($last_fkey =~ tr/\=//) {
				my $eqsign_index = index($last, '=');
				$last_fkey = substr($last, 0, $eqsign_index);
				$last_value = substr($last, $eqsign_index + 1);

				if (rindex($last_value, '*', 0) == 0) {
					# $last_multif = '*';
					$last_value = substr($last_value, 1);
				}

				$last_eqsign = '=';
			}

			my $last_val_quoted = (substr($last_value, 0, 1) =~ tr/"'//);

			# Process flags.
			foreach my $flag (@flags) {
				if (rindex($flag, $last_fkey, 0) != 0) { next; }

				my $flag_fkey = $flag;
				# my $flag_isbool = '';
				my $flag_eqsign = '';
				my $flag_multif = '';
				my $flag_value = '';
				my $cflag = '';

				# If flag contains an eq sign.
				# [https://stackoverflow.com/a/87565]
				if ($flag_fkey =~ tr/\=//) {
					my $eqsign_index = index($flag, '=');
					$flag_fkey = substr($flag, 0, $eqsign_index);
					$flag_value = substr($flag, $eqsign_index + 1);
					$flag_eqsign = '=';

					if (rindex($flag_fkey, '?') > -1) { chop($flag_fkey); }

					if (rindex($flag_value, '*', 0) == 0) {
						$flag_multif = '*';
						$flag_value = substr($flag_value, 1);

						# Track multi-starred flags.
						$usedflags{multi}{$flag_fkey} = undef;
					}

					# Create completion flag item.
					$cflag = "$flag_fkey=$flag_value";

					# If a command-flag, run it and add items to array.
					if (rindex($flag_value, "\$(", 0) == 0 && substr($flag_value, -1) eq ')') {
						my @lines = @{ __exec_command($flag_value) };
						foreach my $line (@lines) {
							if ($line) { push(@flags, $last_fkey . "=$line"); }
						}
						next; # Don't add literal command to completions.
					}

					# Store for later checks.
					$parsedflags{"$flag_fkey=$flag_value"} = undef;
				} else {
					if (rindex($flag_fkey, '?') > -1) { chop($flag_fkey); }
					# Create completion flag item.
					$cflag = $flag_fkey;
					# Store for later checks.
					$parsedflags{"$flag_fkey"} = undef;
				}

				# If the last flag/word does not have an eq-sign, skip flags
				# with values as it's pointless to parse them. Basically, if
				# the last word is not in the form "--form= + a character",
				# don't show flags with values (--flag=value).
				if (!$last_eqsign && $flag_value && !$flag_multif) { next; }

				# [Start] Remove duplicate flag logic --------------------------

				my $dupe = 0;

				# Let multi-flags through.
				if (exists($usedflags{multi}{$flag_fkey})) {

					# Check if multi-starred flag value has been used.
					if ($flag_value && exists($usedflags{$flag_fkey}{$flag_value})) { $dupe = 1; }

				} elsif (!$flag_eqsign) {

					# Valueless --flag (no-value) dupe check.
					if (exists($usedflags{valueless}{$flag_fkey})) { $dupe = 1; }

				} else { # --flag=<value> (with value) dupe check.

					# If usedflags contains <flag:value> at root level.
					if (exists($usedflags{$flag_fkey})) {
						# If no values exists.
						if (!$flag_value) { $dupe = 1; # subl -n 2, subl -n 23

						# Else check that value exists...
						} elsif (exists($usedflags{$flag_fkey}{$flag_value})) {
							$dupe = 1; # subl -n 23 -n

						} elsif (exists($usedflags{counts}{$flag_fkey})) {
							if ($usedflags{counts}{$flag_fkey} > 1) { $dupe = 1; }
						}

					# If no root level entry.
					} else {
						if ($last ne $flag_fkey
							&& exists($usedflags{valueless}{$flag_fkey})) {

							# Autovivication: [https://perlmaven.com/multi-dimensional-hashes]
							# [https://perlmaven.com/autovivification]
							if (!exists($usedflags{$flag_fkey}{$flag_value})) {
								$dupe = 1; # subl --type=, subl --type= --
							}

							# The following code does the same as the
							# autovivification line from above:

							# # Add flag to usedflags root level.
							# if (!exists($usedflags{$flag_fkey})) {
							# 	$usedflags{$flag_fkey} = {};
							# }
							# if (!exists($usedflags{$flag_fkey}{$flag_value})) {
							# 	$dupe = 1; # subl --type=, subl --type= --
							# }
						}
					}
				}

				if ($dupe) { next; } # Skip if dupe.

				# [End] Remove duplicate flag logic ----------------------------

				# Note: Don't list single letter flags. Listing them along
				# with double hyphen flags is awkward. Therefore, only list
				# them when completing or showing its value(s).
				if (length($flag_fkey) == 2 && !$flag_value) { next; }

				# If last word is in the form '--flag=', remove the last
				# word from the flag to only return its option/value.
				if ($last_eqsign) {
					if (rindex($flag_value, $last_value, 0) != 0 || !$flag_value) { next; }
					$cflag = $flag_value;
				}

				push(@completions, $cflag);
			}

			# Account for quoted strings. Add trailing quote if needed.
			if ($last_val_quoted) {
				my $quote = substr($last_value, 0, 1);
				if (substr($last_value, -1) ne $quote) { $last_value .= $quote; }

				# Add quoted indicator to later escape double quoted strings.
				$type = 'flag;quoted';
				if ($quote eq '"') { $type .= ';noescape'; }

				# If value is empty return.
				if (length($last_value) == 2) {
					push(@completions, "$quote$quote");
					return;
				}
			}

			# If no completions, add last item so Bash compl. can add a space.
			if (!@completions) {
				my $key = $last_fkey . (!$last_value ? "" : "=$last_value");
				my $item = (!$last_value ? $last : $last_value);
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
					# Remove values same length as current value.
					@completions = grep {length != $last_val_length} @completions;
				}
			}
		}

	} else {

		$type = 'command';

		# If command chain and used flags exits, don't complete.
		if (%usedflags && $commandchain) {
			$commandchain = "" . (!$last ? "" : $last);
		}

		# If no cc get first level commands.
		if (!$commandchain && !$last) {
			@completions = keys %{ $db{levels}{1} };
		} else {
			my $letter = substr($commandchain, 1, 1);
			my @rows = (keys %{ $db{dict}{$letter} });
			my $lastchar_notspace = ($lastchar ne ' ');

			if (!@rows) { return; }

			my %usedcommands;
			my @commands = split(/(?<!\\)\./, substr($commandchain, 1));
			my $level = $#commands;
			# Increment level if completing a new command level.
			if ($lastchar eq ' ') { $level++; }

			# Get commandchains for specific letter outside of loop.
			my %h = %{ $db{dict}{$letter} };

			foreach my $row (@rows) {
				my @cmds = @{ $h{$row}{commands} };
				$row = $cmds[$level] // undef;

				# Add last command it not yet already added.
				if (!$row || exists($usedcommands{$row})) { next; }
				# If char before caret isn't a space, completing a command.
				if ($lastchar_notspace) {
					if (rindex($row, $last, 0) == 0) { push(@completions, $row); }
				} else { push(@completions, $row); } # Allow all.

				$usedcommands{$row} = undef;
			}
		}

		# Note: If only 1 completion exists, check if command exists in
		# commandchain. If so, it's already used so clear completions.
		if ($nextchar && @completions == 1) {
			my $pattern = '.' . $completions[0] . '(\\.|$)';
			if ($commandchain =~ /$pattern/) { @completions = (); }
		}

		# Run default command if no completions were found.
		if (!@completions) {
			my $copy_commandchain = $commandchain;
			my $pattern = '\.((?:\\\.)|[^\.])+$'; # ((?:\\\.)|[^\.]*?)*$

			# Loop over command chains to build individual chain levels.
			while ($copy_commandchain) {
				# Get command-string, parse and run it.
				my $command_str = $db{fallbacks}{$copy_commandchain};
				if ($command_str) {
					my $lchar = chop($command_str);

					# Run command string.
					if (rindex($command_str, '$(', 0) == 0 && $lchar eq ')') {
						substr($command_str, 0, 2, "");
						my @lines = @{ __exec_command($command_str) };
						foreach my $line (@lines) {
							if ($line) {
								if ($last) {
									# Must start with command.
									if (rindex($line, $last, 0) == 0) {
										push(@completions, $line);
									}
								} else {
									if (rindex($line, '!', 0) == 0) { next; }
									push(@completions, $line);
								}
							}
						}

						# If no completions and last word is a valid completion
						# item, add it to completions to add a trailing space.
						if (!@completions) {
							my $pattern = '^\!?' . quotemeta($last) . '$';
							if (join('\n', @lines) =~ /$pattern/m) {
								push(@completions, $last);
							}
						}

					# Static value.
					} else {
						$command_str .= $lchar;

						if ($last) {
							# Must start with command.
							if (rindex($command_str, $last, 0) == 0) {
								push(@completions, $command_str);
							}
						} else { push(@completions, $command_str); }
					}

					last; # Stop once a command-string is found/ran.
				}

				# Remove last command chain from overall command chain.
				$copy_commandchain =~ s/$pattern//;
			}
		}
	}
}

# Send all possible completions to bash.
sub __printer {
	my $lines = "$type:$last";

	my $iscommand = $type eq 'command';
	if ($iscommand) { $lines .= "\n"; }

	my $sep = ($iscommand) ? ' ' : "\n";
	my $isflag_type = rindex($type, 'f', 0) == 0;
	my $skip_map = 0;

	# Note: When providing flag completions and only "--" is provided,
	# collapse (don't show) flags with the same prefix. This aims to
	# help reduce the `display all n possibilities? (y or n)` message
	# prompt. Instead, only show the prefix in the following format:
	# "--prefix..." along with the shortest completion item.
	if (@completions >= 10 && !$iscommand && $last eq '--') {
		# [https://stackoverflow.com/a/7446317]
		use lib "$ENV{HOME}/.nodecliac/src/ac/utils";
		eval "use LCP"; die $@ if $@; # [https://stackoverflow.com/a/3945763]
		# Get completion's common prefixes.
		my $res = LCP::lcp(\@completions, 2, 2, 3, 3, 0, "--", "...", ('='));
		my @prefixes = @{ $res->{prefixes} }; # Array ref/deref.
		my %rm_indices = %{ $res->{indices} }; # Indices ref/deref.

		# Remove strings (collapse) from main array.
		my $index = -1;
		@completions = grep {
			$index++;
			# If the index exists in the remove indices table and it's
			# value is set to `true` then do not remove from completions.
			!(exists($rm_indices{$index}) && $rm_indices{$index});
		} @completions;

		# Add prefix stubs to completions array.
		@completions = (@completions, @prefixes);
	}

	# When for example, completing 'nodecliac print --command' we remove
	# the first and only completion item's '='. This is better suited for
	# CLI programs that implement/allow for a colon ':' separator. Maybe
	# something that should be opted for via an acmap setting?
	if (@completions == 1 && !$iscommand) {
		my $fcompletion = $completions[0];
		if ($fcompletion =~ /^--?[-a-zA-Z0-9]+\=$/ &&
			$last ne $fcompletion
			&& (length($fcompletion) - length($last) > 1)
		) {
			chop($fcompletion);
			$completions[0] = "\n" . $fcompletion;
			$skip_map = 1;
		}
	}

	if (!$skip_map) {
		# Loop over completions and append to list.
		@completions = map {
			# Add trailing space to all completions except to flag
			# completions that end with a trailing eq sign, commands
			# that have trailing characters (commands that are being
			# completed in the middle), and flag string completions
			# (i.e. --flag="some-word...).
			my $final_space = (
				$isflag_type
				&& !(rindex($_, '=') + 1)
				# Item cannot be quoted.
				&& ((rindex $_, '"', 0) == -1 || (rindex $_, '\'', 0) == -1)
				&& !$nextchar
			) ? ' ' : '';

			"$sep$_$final_space";
		} @completions;
	}

	print $lines . join('', @completions);
}

sub __makedb {
	if (!$commandchain) { # First level commands only.
		if (!$last) {
			foreach my $line (split /\n/, $acdef) {
				next if rindex($line, '.', 0) != 0;

				my $space_index = index($line, ' ');
				my $chain = substr($line, 1, $space_index - 1);

				my $dot_index = index($chain, '.');
				my $command = substr($chain, 0, $dot_index != -1 ? $dot_index : $space_index);
				$db{levels}{1}{$command} = undef;
			}
		} else { # First level flags.
			if ($acdef =~ /^ ([^\n]+)/m) {$db{dict}{''}{''} = { flags => $1 };}
		}
	} else { # Go through entire .acdef file contents.
		my %letters;

		foreach my $line (split /\n/, $acdef) {
			next if (rindex($line, $commandchain, 0) != 0);

			my $chain = substr($line, 0, index($line, ' ') + 1, '');
			chop($chain); # Flag list left remaining.

			# If retrieving next possible levels for the command chain,
			# lastchar must be an empty space and the commandchain does
			# not equal the chain of the line, skip the line.
			next if ($lastchar eq ' ' && rindex($chain . '.', $commandchain . '.', 0) != 0);

			my @commands = split(/(?<!\\)\./, substr($chain, 1));

			# Cleanup remainder (flag/command-string).
			if (ord($line) == 45) {
				my %h = ("commands", \@commands, "flags", $line);
				$letters{substr($chain, 1, 1)}{$chain} = \%h;
			} else { # Store fallback.
				$db{fallbacks}{$chain} = substr($line, 8);
			}
		}

		# Add letters hash to db (main) hash.
		$db{dict} = \%letters;
	}
}

__parser();__extractor();__makedb();__lookup();__printer();
