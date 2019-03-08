#!/usr/bin/perl

# [https://stackoverflow.com/questions/8023959/why-use-strict-and-warnings]
# [http://perldoc.perl.org/functions/use.html]
# use strict;
# use warnings;
# use diagnostics;

# Get command name from sourced passed-in argument.
my $maincommand = $ARGV[2];

# Vars.
my @args = ();
my $last = "";
my $type = "";
my $usedflags = "";
my @completions = ();
my $commandchain = "";
my $cline = $ARGV[0]; # Original (complete) CLI input.
my $cpoint = int($ARGV[1]); # Caret index when [tab] key was pressed.
my $lastchar = substr($cline, $cpoint - 1, 1); # Character before caret.
my $nextchar = substr($cline, $cpoint, 1); # Character after caret.
my $cline_length = length($cline); # Original input's length.
my $isquoted = 0;
my $autocompletion = 1;
my $inp = substr($cline, 0, $cpoint); # CLI input from start to caret index.

# Get the acmap definitions file.
my $acmap = $ARGV[3];

# RegExp Patterns:
my $flgopt = '-{1,2}[-.a-zA-Z0-9]*='; # "--flag/-flag="
my $flagstartr = '^-{1,2}[a-zA-Z0-9]([-.a-zA-Z0-9]{1,})?\=\*?'; #"--flag/-flag=*"
my $flgoptvalue = $flagstartr . '.{1,}$'; # "--flag/-flag=value"
my $flagcommand = $flagstartr . '\$\((.{1,})\)$'; # "--flag/-flag=$("<COMMAND-STRING>")"

# Log local variables and their values.
sub __debug {
	print "\n";
	print "  commandchain: '$commandchain'\n";
	print "     usedflags: '$usedflags'\n";
	print "          last: '$last'\n";
	print "         input: '$inp'\n";
	print "  input length: '$cline_length'\n";
	print "   caret index: '$cpoint'\n";
	print "      lastchar: '$lastchar'\n";
	print "      nextchar: '$nextchar'\n";
	print "      isquoted: '$isquoted'\n";
	print "autocompletion: '$autocompletion'\n";
}

# Global flag only to be used for __dupecheck function.
my $__dc_multiflags = "";

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

	# Var boolean.
	my $dupe = 0;
	my $d = "}|{"; # Delimiter.

	# If its a multi-flag then let it through.
	if (__includes($__dc_multiflags, " $flag_fkey ")) {
		$dupe = 0;

		# Although a multi-starred flag, check if value has been used or not.
		if (__includes(" $d $usedflags ", " $d $flag ")) {
			$dupe = 1;
		}

	# Valueless flag dupe check.
	} elsif (!$flag_eqsign) {
		if (__includes(" $d $usedflags ", " $d $flag_fkey ") ||
			# Check is used as a flag with a value. This happens due
			# to how the extractor is implemented. For example, the
			# following flags in 'myapp --SOMETING value --' will be
			# turned into ' }|{ --SOMETING=value }|{ -- '. Therefore,
			# check if the flag was was actually used with a value.
			__includes(" $d $usedflags ", " $d $flag_fkey=")) {
			$dupe = 1;
		}

	# Flag with value dupe check.
	} else {
		# Count substring occurrences:
		# [https://stackoverflow.com/a/9538604]
		$flag_fkey .= "=";
		my @c = $usedflags =~ /$flag_fkey/g;
		my $count = scalar(@c);

		# More than 1 occurrence flag has been used.
		if ($count >= 1) {
			$dupe = 1;
		}

		# If there is exactly 1 occurrence and the flag matches the
		# RegExp pattern we undupe flag as the 1 occurrence is being
		# completed (i.e. a value is being completed).
		if ($count == 1 && $flag =~ /$flgoptvalue/) {
			$dupe = 0;
		}
	}

	# Return dupe boolean result.
	return $dupe;
}

# Check whether string is left quoted (i.e. starts with a quote).
#
# @param {string} 1) - The string to check.
# @return {boolean} - True means it's left quoted.
sub __is_lquoted {
	# Get arguments.
	my ($string) = @_;

	# Default to false.
	my $check = 0;

	# Check for left quote.
	if ($string =~ /^(\"|\')/) {
		$check = 1;
	}

	# Return check output.
	return $check;
}

# Get last command in chain: 'mc.sc1.sc2' → 'sc2'
#
# @param {string} 1) - The row to extract command from.
# @param {number} 2) - The chain replacement type.
# @return {string} - The last command in chain.
sub __last_command {
	# Get arguments.
	my ($row, $type) = @_;

	# Extract command chain from row.
	($row) = $row =~ /^[^ ]*/g;

	# Chain replacement depends on completion type.
	if ($type == 1) {
		$row = $row =~ s/$commandchain\.//r;
	} else {
		my @cparts = split(/(?<!\\)\./, $row);
		$row = pop(@cparts);
	}

	# Extract next command in chain.
	my ($lastcommand) = $row =~ /^.*?(?=(?<!\\)\.)/g;
	if (!$lastcommand) { $lastcommand = $row; }

	# Remove any slashes from command.
	$lastcommand = $lastcommand =~ s/\\//r;

	return $lastcommand;
}

# Check whether string starts with a hyphen.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means it starts with a hyphen.
#
# @resource [https://stackoverflow.com/a/34951053]
# @resource [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
sub __starts_with_hyphen {
	# Get arguments.
	my ($string) = @_;

	return ord($string) == 45;
}

# Check whether string contains provided substring.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means substring is found in string.
sub __includes {
	# Get arguments.
	my ($string, $needle) = @_;

	return (index($string, $needle) == -1) ? 0 : 1;
}

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

# Escape '\' characters and replace unescaped slashes '/' with '.' (dots)
#     command strings
#
# @param {string} 1) - The command string to escape.
# @return {string} - The escaped command string.
sub __normalize_command {
	# Get arguments.
	my ($command) = @_;

	# Escape dots.
	$command = $command =~ s/\./\\\\./r;
	# Replace unescaped '/' with '.' dots.
	$command = $command =~ s/([^\\]|^)\//$1\./r;

	# Returned normalized command string.
	return $command;
}

# Validates whether command/flag (--flag) only contain valid characters.
#     If word command/flag contains invalid characters the script will
#     exit. In turn, terminating auto completion.
#
# @param {string} 1) - The word to check.
# @return {string} - The validated argument.
sub __validate {
	# Get arguments.
	my ($arg, $type) = @_;

	# Determine what matching pattern to use (command/flag).
	my $pattern = ($type eq "command") ? '[^-_.:a-zA-Z0-9\\\/]+' : '[^-_a-zA-Z0-9]+';

	# Exit script if invalid characters are found (failed RegExp).
	if ($arg =~ /$pattern/i) {
		exit;
	}

	# Return word.
	return $arg;
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
	my $argument = "";
	my $cmdstr_length = length($input);
	my $state = "closed";
	my $quote_type = "";
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

		# If character is an unescaped quote.
		if ($char =~ /["']/ && $pchar ne "\\" && $state eq "closed") {
			# Check if the previous character is a dollar sign. This
			# means the command should run as a command.
			if ($pchar && $pchar eq "\$") { $argument .= "\$"; }
			# Set state to open.
			$state = "open";
			# Set quote type.
			$quote_type = $char;
			# Store the character.
			$argument .= $char;

		# If char is an unescaped quote + status is open...reset.
		} elsif (
			$char =~ /["']/ &&
			$pchar ne "\\" &&
			$state eq "open" &&
			$quote_type eq $char
		) {
			# Set state to close.
			$state = "closed";
			# Reset quote type.
			$quote_type = "";
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
		} elsif ($char =~ /[^"']/) {
			# If we hit a comma and the state is closed.
			# We store the current argument and reset
			# everything.
			if ($state eq "closed" && $char eq ",") {
				push(@arguments, $argument);
				$args_count++;
				$argument = "";
			} elsif ($state eq "open") {
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

# Parses CLI input. Returns input similar to that of process.argv.slice(2).
#     Adapted from argsplit module.
#
# @param {string} 1) - The string to parse.
# @return {undefined} - Noting is returned.
sub __parser {
	# Vars.
	my $current = "";
	my ($input) = @_;
	my $quote_char = "";
	my $l = length($input); # Input length.

	# Input must not be empty.
	if (!$input) {
		return;
	}

	# Loop over every input char: [https://stackoverflow.com/q/10487316]
	for (my $i = 0; $i < $cline_length; $i++) {
		# Cache current/previous/next chars.
		my $c = substr($input, $i, 1);
		my $p = substr($input, $i - 1, 1);
		my $n = substr($input, $i + 1, 1);

		# Reset prev word for 1st char as bash gets the last char.
		if ($i == 0) {
			$p = "";
		# Reset next word for last char as bash gets the first char.
		} elsif ($i == ($cline_length - 1)) {
			$n = "";
		}

		# Stop loop once it hits the caret position character.
		if ($i >= ($l - 1)) {
			# Only add if not a space character.
			if ($c ne " " || $c eq " " && $p eq "\\") {
				$current .= $c;
			}

			# Store last char.
			$lastchar = $c;
			# If last char is an escaped space then reset lastchar.
			if ($c eq " " && $p eq "\\") { $lastchar = ""; }

			last;
		}

		# If char is a space.
		if ($c eq " " && $p ne "\\") {
			if (length($quote_char) != 0) {
				$current .= $c;
			} else {
				if ($current ne "") {
					push(@args, $current);
					$current = "";
				}
			}
		# Non space chars.
		} elsif (($c eq '"' || $c eq "'") && $p ne "\\") {
			if ($quote_char ne "") {
				# To end the current string encapsulation, the next
				# char must be a space or nothing (meaning) the end
				# if the input string. This is done to prevent
				# this edge case: 'myapp run "some"--'. Without this
				# check the following args get parsed:
				# args=(myapp run "some" --). What we actually want
				# is args=(myapp run "some"--).
				#
				if ($quote_char eq $c && ($n eq "" || $n eq " ")) {
					$current .= $c;
					push(@args, $current);
					$quote_char = "";
					$current = "";
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
	if ($current ne "") {
		push(@args, $current);
	}
}

# Lookup command/subcommand/flag definitions from the acmap to return
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
# myapp run "some" --flagsin command1 sub1 --flag1 val
# myapp run -rd '' -a config
# myapp --Wno-strict-overflow= config
# myapp run -u $(id -u $USER):$(id -g $USER\ )
# myapp run -u $(id -u $USER):$(id -g $USER )
sub __extractor {
	# Vars.
	my $l = scalar(@args);
	my @oldchains = ();
	my @foundflags = ();

	# Loop over CLI arguments.
	for (my $i = 1; $i < $l; $i++) {
		# Cache current loop item.
		my $item = $args[$i];
		my $nitem = $args[$i + 1];

		# Skip quoted (string) items.
		if (__is_lquoted($item)) {
			next;
		}

		# Reset next item if it's the last iteration.
		if ($i == $l - 1) {
			$nitem = "";
		}

		# If a command (does not start with a hyphen.)
		# [https://stackoverflow.com/a/34951053]
		# [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
		if (!__starts_with_hyphen($item)) {
			# Store command.
			$commandchain .= __validate("." . __normalize_command($item), "command");
			# Reset used flags.
			@foundflags = ();
		} else { # We have a flag.
			# Store commandchain to revert to it if needed.
			push(@oldchains, $commandchain);
			$commandchain = "";

			# If the flag contains an eq sign don't look ahead.
			if (__includes($item, "=")) {
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
					my $oldchain = "";
					my $skipflagval = 0;
					for (my $j = ($#oldchains); $j >= 0; $j--) {
						my $chain = $oldchains[$j];
						if ($chain) {
							$oldchain = $chain;

							# Lookup flag definitions from acmap.
							my $pattern = '^' . "$oldchain" . ' (-{1,2}.*)$';
							if ($acmap =~ /$pattern/m) {
								my $pattern = "${item}\\?" . '(\\||$)';
								if ($1 =~ /$pattern/) {
									$skipflagval = 1;
								}
							}

							last;
						}
					}

					# If the flag is not found then simply add the
					# next item as its value.
					if ($skipflagval == 0) {
						push(@foundflags, __validate($item, "flag") . "=$nitem");

						# Increase index to skip added flag value.
						$i++;
					} else {
						# It's a boolean flag. Add boolean marker (?).
						$args[$i] = $args[$i] . "?";

						push(@foundflags, __validate($item, "flag"));
					}

				} else { # The next word is a another flag.
					push(@foundflags, __validate($item, "flag"));
				}

			} else {
				# Check whether flag is a boolean
				# Get the first non empty command chain.
				my $oldchain = "";
				my $skipflagval = 0;
				for (my $j = ($#oldchains); $j >= 0; $j--) {
					my $chain = $oldchains[$j];
					if ($chain) {
						$oldchain = $chain;

						# Lookup flag definitions from acmap.
						my $pattern = '^' . "$oldchain" . ' (-{1,2}.*)$';
						if ($acmap =~ /$pattern/m) {
							my $pattern = "${item}\\?" . '(\\||$)';
							if ($1 =~ /$pattern/) {
								$skipflagval = 1;
							}
						}

						last;
					}
				}

				# If the flag is found then add marker to item.
				if ($skipflagval != 0) {
					# It's a boolean flag. Add boolean marker (?).
					$args[$i] = $args[$i] . "?";
				}
				push(@foundflags, __validate($item, "flag"));

			}
		}

	}

	# Get the first non empty command chain.
	my $oldchain = "";
	for (my $i = ($#oldchains); $i >= 0; $i--) {
		my $chain = $oldchains[$i];
		if ($chain) {
			$oldchain = $chain;
			last;
		}
	}

	# Revert commandchain to old chain if empty.
	if (!$commandchain) {
		$commandchain = $oldchain;
	} else {
		$commandchain = $commandchain;
	}
	# Prepend main command to chain.
	$commandchain = __validate("$commandchain", "command");

	# Build used flags strings.
	# Switch statement: [https://stackoverflow.com/a/22575299]
	if (scalar(@foundflags) == 0) {
		$usedflags = "";
	} else {
		$usedflags = join(' }|{ ', @foundflags);
	}

	# Determine whether to turn off autocompletion or not.
	# Get the last word item.
	my $lword = $args[-1];
	if ($lastchar eq " ") {
		if (__starts_with_hyphen($lword)) {
			if (__includes($lword, "?") || __includes($lword, "=")) {
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
				if (__includes($sword, "?") || __includes($sword, "=")) {
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
			if (substr($args[$i], -1) eq "?") {
				$args[$i] = substr($args[$i], 0, -1);
			}
		}
	}

	# Set last word. If the last char is a space then the last word
	# will be empty. Else set it to the last word.
	# Switch statement: [https://stackoverflow.com/a/22575299]
	if ($lastchar eq " ") {
		$last = "";
	} else {
		$last = $args[-1];
	}

	# Check whether last word is quoted or not.
	if (__is_lquoted($last)) {
		$isquoted = 1;
	}

	# Note: If autocompletion is off check whether we have one of the
	# following cases: '$ maincommand --flag ' or '$ maincommand --flag val'.
	# If we do then we show the possible value options for the flag or
	# try and complete the currently started value option.
	if (!$autocompletion && $nextchar ne "-") {
		my $islast_aspace = ($lastchar eq " ");
		# Get correct last word.
		my $nlast = $args[($islast_aspace ? -1 : -2)];
		# acmap commandchain lookup Regex.
		my $pattern = '^' . $commandchain . ' (-{1,2}.*)$';

		# The last word (either last or second last word) must be a flag
		# and cannot have contain an eq sign.
		if (__starts_with_hyphen($nlast) && !__includes($nlast, "=")) {
			# Show all available flag option values.
			if ($islast_aspace) {
				# Check if the flag exists in the following format: '--flag='
				if ($acmap =~ /$pattern/m) {
					# Check if flag exists with option(s).
					my $pattern = $nlast . '=(?!\*).*?(\||$)';
					if ($1 && $1 =~ /$pattern/) {
						# Reset needed data.
						$usedflags .= "=";
						$last = $nlast . "=";
						$lastchar = "=";
						$autocompletion = 1;
					}
				}
			} else { # Complete currently started value option.
				# Check if the flag exists in the following format: '--flag='
				if ($acmap =~ /$pattern/m) {
					# Escape special chars: [https://stackoverflow.com/a/576459]
					# [http://perldoc.perl.org/functions/quotemeta.html]
					my $pattern = $nlast . '=' . quotemeta($last) . '.*?(\||$)';

					# Check if flag exists with option(s).
					if ($1 && $1 =~ /$pattern/) {
						# Reset needed data.
						$last = $nlast . "=" . $last;
						$lastchar = substr($last, -1);
						$autocompletion = 1;
					}
				}
			}
		}
	}
}

# Lookup command/subcommand/flag definitions from the acmap to return
#     possible completions list.
sub __lookup {
	# Skip logic if last word is quoted or completion variable is off.
	if ($isquoted || !$autocompletion) {
		return;
	}

	# Flag completion (last word starts with a hyphen):
	if (__starts_with_hyphen($last)) {
		# Lookup flag definitions from acmap.
		my $pattern = '^' . $commandchain . ' (-{1,2}.*)$';
		if ($acmap =~ /$pattern/m) {
			# Continue if rows exist.
			if ($1) {
				my @used = ();

				# Set completion type:
				$type = "flag";

				# If no flags exist skip line.
				if ($1 eq "--") { return; }

				# Split by unescaped pipe '|' characters:
				# [https://www.perlmonks.org/bare/?node_id=319761]
				# my @flags = split(/(?<!\\)\|/, $1);
				my @flags = split(/(?:\\\\\|)|(?:(?<!\\)\|)/, $1);

				# Breakup last word into flag/value.
				my @matches = $last =~ /^(.*?)((=)(\*)?(.*?))?$/;
				# Default to empty string if no match.
				# [https://perlmaven.com/how-to-set-default-values-in-perl]
				my $last_fkey = $matches[0] // "";
				my $last_eqsign = $matches[2] // "";
				my $last_multif = $matches[3] // "";
				my $last_value = $matches[4] // "";
				my $nohyphen_last = $last =~ s/^-*//r;
				my $last_fletter = substr($nohyphen_last, 0, 1);
				my $last_val_quoted = __is_lquoted($last_value);

				# Loop over flags to process.
				foreach my $flag (@flags) {
					# Breakup flag into its components (flag/value/etc.).
					my @matches = $flag =~ /^(.*?)(\?)?((=)(\*)?(.*?))?$/;
					# Default to empty string if no match.
					# [https://perlmaven.com/how-to-set-default-values-in-perl]
					my $flag_fkey = $matches[0] // "";
					my $flag_isbool = $matches[1] // "";
					my $flag_eqsign = $matches[3] // "";
					my $flag_multif = $matches[4] // "";
					my $flag_value = $matches[5] // "";
					my $nohyphen_flag = $flag =~ s/^-*//r;
					my $flag_fletter = substr($nohyphen_flag, 0, 1);
					my $flag_val_quoted = __is_lquoted($flag_value);

					# Preliminary checks:
					if (
					# Before continuing with full on flag logic checks, check
					# whether the flag even starts with the same character. If
					# the last word is only made up of hyphens then let it
					# through.
						$nohyphen_last && $last_fletter ne $flag_fletter ||
					# Flag must start with the last word. Escape special chars:
					# [https://stackoverflow.com/a/576459]
					# [http://perldoc.perl.org/functions/quotemeta.html]
					# $pattern = '^' . $last_fkey;
					# if (!($flag_fkey =~ /$pattern/)) { next; }
						index($flag_fkey, $last_fkey) != 0
					) { next; }

					# Reset flag to only include flag key and possible value.
					$flag = $flag_fkey .
						# Check for value.
						($flag_eqsign ? ($flag_value) ? "=$flag_value" : "=" : "");

					# Track multi-starred flags.
					if ($flag_multif) { $__dc_multiflags .= " $flag_fkey "; }

					# Unescape flag.
					# $flag = __unescape($flag);

					# If a command-flag: --flag=$("<COMMAND-STRING>"), run
					# command and add returned words to completion options.
					if ($last_eqsign) {
						# If fkey starts with flag and is a command flag.
						if (index($flag, $last_fkey) == 0 && $flag =~ /$flagcommand/) {
							# Cache captured string command.
							my @arguments = __paramparse($2);
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
							# following form: `bash -c $command 2> /dev/null`
							my $cmd = "bash -c $arguments[0]";

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

								# Set command.
								$command = $arguments[0];
								# Unescape pipe characters.
								$command = $command =~ s/\\\|/\|/r;

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

										# Run command and append result to
										# command string.
										my $cmdarg = "bash -c $arg 2> /dev/null";
										$cmd .= "$quote_char" . `$cmdarg` . "$quote_char";

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
							$cmd .= " 2> /dev/null";

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

							# Set environment vars so command has access.
							my $prefix = "NODECLIAC_";
							$ENV{"${prefix}COMP_LINE"} = $cline;
							$ENV{"${prefix}COMP_POINT"} = $cpoint;
							$ENV{"${prefix}MAIN_COMMAND"} = $maincommand;
							$ENV{"${prefix}COMMAND_CHAIN"} = $commandchain;
							$ENV{"${prefix}USED_FLAGS"} = $usedflags;
							$ENV{"${prefix}LAST"} = $last;
							$ENV{"${prefix}INPUT"} = $inp;
							$ENV{"${prefix}LAST_CHAR"} = $lastchar;
							$ENV{"${prefix}NEXT_CHAR"} = $nextchar;
							$ENV{"${prefix}COMP_LINE_LENGTH"} = $cline_length;

							# Run the command.
							my $lines = `$command`;
							# Note: $2 (the provided command string) will be
							# injected as is. Meaning it will be provided to
							# 'bash' with the provided surrounding quotes. User
							# needs to make sure to properly use and escape
							# quotes as needed. ' 2> /dev/null' will suppress
							# all errors in the event the command fails.

							# Unset environment vars once command is ran.
							# [https://stackoverflow.com/a/8770380]
							# Is this needed?
							# delete $ENV{"${prefix}COMP_LINE"};
							# delete $ENV{"${prefix}COMP_POINT"};
							# delete $ENV{"${prefix}MAIN_COMMAND"};
							# delete $ENV{"${prefix}COMMAND_CHAIN"};
							# delete $ENV{"${prefix}USED_FLAGS"};
							# delete $ENV{"${prefix}LAST"};
							# delete $ENV{"${prefix}INPUT"};
							# delete $ENV{"${prefix}LAST_CHAR"};
							# delete $ENV{"${prefix}NEXT_CHAR"};
							# delete $ENV{"${prefix}COMP_LINE_LENGTH"};

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

								# Add each line to flags array.
								foreach my $line (@lines) {
									# # Remove starting left line break in line,
									# # if it exists, before adding to flags.
									# if ($delimiter eq "\$") {
									# 	$line = $line =~ s/^\n//r;
									# }

									# Line cannot be empty.
									if ($line) {
										# Finally, add to flags array.
										push(@flags, $last_fkey . "=$line");
									}
								}
							}

							# Skip flag to not add literal command to completions.
							next;
						}
					}

					# Flag must start with the last word.
					# Escape special chars: [https://stackoverflow.com/a/576459]
					# [http://perldoc.perl.org/functions/quotemeta.html]
					my $pattern = '^' . quotemeta($last);
					if ($flag =~ /$pattern/) {
						# Note: If the last word is "--" or if the last
						# word is not in the form "--form= + a character",
						# don't show flags with values (--flag=value).
						if (!$last_eqsign && $flag =~ /$flgoptvalue/ && !$flag_multif) {
							next;
						}

						# No dupes unless it's a multi-starred flag.
						if (!__dupecheck($flag,
							$flag_fkey,
							$flag_isbool,
							$flag_eqsign,
							$flag_multif,
							$flag_value)
						) {
							# If last word is in the form → "--flag=" then we
							# need to remove the last word from the flag to
							# only return its options/values.
							if ($last =~ /$flgopt/) {
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
					$type = "flag;quoted";
					if ($quote eq "\"") {
						$type .= ";noescape";
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
				if (scalar(@completions) == 0 && scalar(@used) == 1) {
					push(@completions, $used[0]);
				}
			}
		}
	} else { # Command completion:

		# Set completion type:
		$type = "command";

		# Store command completions in a hash to only keep unique entries.
		# [https://stackoverflow.com/a/15894780]
		# [https://stackoverflow.com/a/3810548]
		# [https://stackoverflow.com/a/11437184]
		my %lookup;

		# If command chain and used flags exits, don't complete.
		if ($usedflags && $commandchain) {
			# Reset commandchain and usedflags.
			$commandchain = "" . (!$last ? "" : $last);
			$usedflags = "";
		}

		# Lookup all command tree rows from acmap once and store.
		# my $pattern = '^' . $commandchain . '.*$'; # Original.
		# my $pattern = '^' . substr($commandchain, 0, 2) . '.*$'; # 2 char RegExp pattern.
		# The following RegExp does not seem to work:
		# my $pattern = '^(?!(\\#|\\s))' . quotemeta(substr($commandchain, 0, 2)) . '.*$';
		# Make initial acdef file lookup. Ignore comments/empty lines.
		# my $pattern = '^(?![#|\n])' . quotemeta(substr($commandchain, 0, 2)) . '.*$';
		# my $pattern = '^(?![#|\n])' . $commandchain . '.+$';
		my $pattern = '^(?![#|\n])' . substr($commandchain, 0, 2) . '.+$';
		my @data = $acmap =~ /$pattern/mg;
		my @rows = (); # Store filtered data.
		my $lastchar_notspace = ($lastchar ne " ");

		# Determine last command replacement type and initial data filter.
		$pattern = '^(' . $commandchain . '\\..*)$';
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
		if (scalar(@rows) == 0) {
			my $pattern = '^' . $commandchain . ' ';
			# Filter rows instead of looking up entire file again.
			@rows = grep(/$pattern/, @data);

			if (scalar(@rows) && $lastchar_notspace) {
				# Add last command in chain.
				$lookup{__last_command($rows[0], $rtype)} = 1;
			}
		} else {
			# Last word checks:
			$pattern = '^' . $commandchain . ' ';
			# Filter rows instead of looking up entire file again.
			my $check1 = scalar(grep(/$pattern/, @data));

			# [https://stackoverflow.com/questions/15573652/regex-to-exclude-unless-preceded-by]
			# [https://stackoverflow.com/a/7124976]
			# [https://stackoverflow.com/a/9306228]
			# [https://stackoverflow.com/a/11819111]
			# [https://stackoverflow.com/a/6464500]
			# [https://stackoverflow.com/a/6525975]
			$pattern = '^' . $commandchain . '([^\\.]|(?<=\\\\)\\.)+ ';
			# Filter rows instead of looking up entire file again.
			my $check2 = scalar(grep(/$pattern/, @data));

			# If caret is in the last position (not a space), the
			# command tree exists, and the command tree does not
			# contain any upper levels then we simply add the last
			# word so that bash can add a space to it.
			if ($check1 && !$check2 && $lastchar_notspace) {
				# Add last command in chain.
				$lookup{$last} = 1;
			} else {
				# Split rows by lines: [https://stackoverflow.com/a/11746174]
				foreach my $row (@rows) {
					# Get last command in chain.
					$row = __last_command($row, $rtype);

					# Add last command if it exists.
					if ($row) {
						# If the character before the caret is not a
						# space then we assume we are completing a
						# command. (should we check that the character
						# is one of the allowed command chars,
						# i.e. [a-zA-Z-:]).
						if ($lastchar_notspace) {
							# Since we are completing a command we only
							# want words that start with the current
							# command we are trying to complete.
							my $pattern = '^' . $last;
							if ($row =~ /$pattern/) {
								$lookup{$row} = 1;
							}
						} else {
							# If we are not completing a command then
							# we return all possible word completions.
							$lookup{$row} = 1;
						}
					}
				}
			}
		}

		# Get hash values as an array.
		# [https://stackoverflow.com/a/2907303]
		# @completions = values %lookup;
		# Use a loop for better compatibility.
		# [https://stackoverflow.com/a/3360]
		foreach my $key (keys %lookup) {
			push(@completions, $key);
		}

		# Note: If there is only one command in the command completions
		# array, check whether the command is already in the commandchain.
		# If so, empty completions array as it has already been used.
		if ($nextchar && scalar(@completions) == 1) {
			my $pattern = '.' . $completions[0] . '(\\.|$)';
			if ($commandchain =~ /$pattern/) {
				@completions = ();
			}
		}
	}
}

# Send all possible completions to bash.
sub __printer {
	# Build and contains all completions in a string.
	my $lines = "$type:$last";
	# ^ The first line will contain meta information about the completion.

	# Check whether completing a command.
	my $iscommand = $type eq "command";
	# Add new line if completing a command.
	if ($iscommand) { $lines .= "\n"; }

	# Determine what list delimiter to use.
	my $sep = ($iscommand) ? " " : "\n";
	# Check completing flags.
	my $isflag_type = __includes($type, "flag");

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
			&& !__includes($completion, "=")
			&& !__is_lquoted($completion)
			&& !$nextchar
		) {
			$lines .= " ";
		}
	}

	# Return data.
	print $lines;
}

# Completion logic:
# <cli_input> → parser → extractor → lookup → printer
# Note: Supply CLI input from start to caret index.
__parser($inp);__extractor();__lookup();__printer();
