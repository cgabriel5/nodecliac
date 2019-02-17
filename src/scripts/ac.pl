#!/usr/bin/perl
use strict;
use warnings;

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

# Get the acmap definitions file.
my $acmap = $ARGV[3];

# Log local variables and their values.
sub __debug {
	my $inp = substr($cline, 0, $cpoint);
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
	my ($flag) = @_;

	# Var boolean.
	my $dupe = 0;
	my $d = "}|{"; # Delimiter.

	# Get individual components from flag.
	my ($ckey) = $flag =~ /^([^=]*)/;

	# Regex → "--flag=value"
	my $flgoptvalue = "^\\-{1,2}[a-zA-Z0-9]([a-zA-Z0-9\\-]{1,})?\\=\\*?.{1,}\$";

	# If its a multi-flag then let it through.
	if (includes($__dc_multiflags, " $ckey ")) {
		$dupe = 0;

	# Valueless flag dupe check.
	} elsif (!includes($flag, "=")) {
		if (includes(" ${d} $usedflags ", " ${d} ${ckey} ")) {
			$dupe = 1;
		}

	# Flag with value dupe check.
	} else {
		# Count substring occurrences:
		# [https://stackoverflow.com/a/9538604]
		$ckey .= "=";
		my @c = $usedflags =~ /$ckey/g;
		my $count = scalar(@c);

		# More than 1 occurrence flag has been used.
		if ($count >= 1) {
			$dupe = 1;
		}

		# If there is exactly 1 occurrence and the flag matches the
		# ReGex pattern we undupe flag as the 1 occurrence is being
		# completed (i.e. a value is being completed).
		if ($count == 1 && $flag =~ /$flgoptvalue/) {
			$dupe = 0;
		}
	}

	# Return dupe boolean result.
	return "$dupe";
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
		my $nrow = substr($row, 0, rindex($row, "."));
		$row = $row =~ s/$nrow\.//r;
	}

	# Extract next command in chain.
	my ($lastcommand) = $row =~ /^[^.]*/g;

	return $lastcommand;
}

# Check whether string starts with a hyphen.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means it starts with a hyphen.
#
# @resource [https://stackoverflow.com/a/34951053]
# @resource [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
sub starts_with_hyphen {
	# Get arguments.
	my ($string) = @_;

	return ord($string) == 45;
}

# Check whether string contains provided substring.
#
# @param {string} 1) - The string to check.
# @return {boolean} - 1 means substring is found in string.
sub includes {
	# Get arguments.
	my ($string, $needle) = @_;

	return (index($string, $needle) == -1) ? 0 : 1;
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
	for my $i (0 .. ($cline_length - 1)) {
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
				$current .= "$c";
			}

			# Store last char.
			$lastchar = "$c";
			# If last char is an escaped space then reset lastchar.
			if ($c eq " " && $p eq "\\") { $lastchar = ""; }

			last;
		}

		# If char is a space.
		if ($c eq " " && $p ne "\\") {
			if (length($quote_char) != 0) {
				$current .= "$c";
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
					$current .= "$c";
					push(@args, $current);
					$quote_char = "";
					$current = "";
				} elsif (($quote_char eq '"' || $quote_char eq "'") && $p ne "\\") {
					$current .= "$c";
				} else {
					$current .= "$c";
					$quote_char = "$c";
				}
			} else {
				$current .= "$c";
				$quote_char = "$c";
			}
		} else {
			$current .= "$c";
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
sub __extracter {
	# Vars.
	my $l = $#args;
	my @oldchains = ();
	my @foundflags = ();

	# Loop over CLI arguments.
	for my $i (1 .. $l) {
		# Cache current loop item.
		my $item = $args[$i];
		my $nitem = $args[$i + 1];

		# Skip quoted (string) items.
		if (__is_lquoted($item)) {
			next;
		}

		# Reset next item if it's the last iteration.
		if ($i == $l) {
			$nitem = "";
		}

		# If a command (does not start with a hyphen.)
		# [https://stackoverflow.com/a/34951053]
		# [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
		if (!starts_with_hyphen($item)) {
			# Store command.
			$commandchain .= ".$item";
			# Reset used flags.
			@foundflags = ();
		} else { # We have a flag.
			# Store commandchain to revert to it if needed.
			push(@oldchains, $commandchain);
			$commandchain = "";

			# If the flag contains an eq sign don't look ahead.
			if (includes($item, "=")) {
				push(@foundflags, $item);
				next;
			}

			# Look ahead to check if next item exists. If a word
			# exists then we need to check whether is a value option
			# for the current flag or if it's another flag and do
			# the proper actions for both.
			if ($nitem) {
				# If the next word is a value...
				if (!starts_with_hyphen($nitem)) {
					# Check whether flag is a boolean:
					# Get the first non empty command chain.
					my $oldchain = "";
					my $skipflagval = 0;
					for (my $j = ($#oldchains); $j >= 0; $j--) {
						my $chain = $oldchains[$j];
						if ($chain) {
							$oldchain = "$chain";

							# Lookup flag definitions from acmap.
							my $pattern = '^' . "$maincommand$oldchain" . ' (\\-\\-.*)$';
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
						push(@foundflags, "$item = $nitem");

						# Increase index to skip added flag value.
						$i++;
					} else {
						# It's a boolean flag. Add boolean marker (?).
						$args[$i] = $args[$i] . "?";

						push(@foundflags, $item);
					}

				} else { # The next word is a another flag.
					push(@foundflags, $item);
				}

			} else {
				# Check whether flag is a boolean
				# Get the first non empty command chain.
				my $oldchain = "";
				my $skipflagval = 0;
				for (my $j = ($#oldchains); $j >= 0; $j--) {
					my $chain = $oldchains[$j];
					if ($chain) {
						$oldchain = "$chain";

						# Lookup flag definitions from acmap.
						my $pattern = '^' . "$maincommand$oldchain" . ' (\\-\\-.*)$';
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
				push(@foundflags, $item);

			}
		}

	}

	# Get the first non empty command chain.
	my $oldchain = "";
	for (my $i = ($#oldchains); $i >= 0; $i--) {
		my $chain = $oldchains[$i];
		if ($chain) {
			$oldchain = "$chain";
			last;
		}
	}

	# Revert commandchain to old chain if empty.
	if (!$commandchain) {
		$commandchain = "$oldchain";
	} else {
		$commandchain = "$commandchain";
	}
	# Prepend main command to chain.
	$commandchain = "$maincommand$commandchain";

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
		if (starts_with_hyphen($lword)) {
			if (includes($lword, "?") || includes($lword, "=")) {
				$autocompletion = 1;
			} else {
				$autocompletion = 0;
			}
		}
	} else {
		if (!starts_with_hyphen($lword)) {
			# Check if the second to last word is a flag.
			my $sword = $args[-2];
			if (starts_with_hyphen($sword)) {
				if (includes($sword, "?") || includes($sword, "=")) {
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
		if (starts_with_hyphen($args[$i])) {
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
}

# Lookup command/subcommand/flag definitions from the acmap to return
#     possible completions list.
sub __lookup {
	# Flag ReGex test patterns.
	# Regex → "--flag="
	my $flgopt = '--?[a-z0-9-]*=';
	# Regex → "--flag=value"
	my $flgoptvalue = '^\-{1,2}[a-zA-Z0-9]([a-zA-Z0-9\-]{1,})?\=\*?.{1,}$';

	# Skip logic if last word is quoted or completion variable is off.
	if ($isquoted || !$autocompletion) {
		return;
	}

	# Flag completion (last word starts with a hyphen):
	if (starts_with_hyphen($last)) {
		# Lookup flag definitions from acmap.
		my $pattern = '^' . "$commandchain" . ' (\\-\\-.*)$';
		if ($acmap =~ /$pattern/m) {
			# Continue if rows exist.
			if ($1) {
				my @used = ();

				# Set completion type:
				$type = "flag";

				# # Split rows by lines: [https://stackoverflow.com/a/11746174]
				# while read -r row; do
				# # ^ Note: Since there is to be only a single row for
				# # a command which includes all it's flags, looping over
				# # the found 'rows' is not really needed. Leave/remove??

				# If no flags exist skip line.
				if ($1 eq "--") { return; }

				# # Split by unescaped pipe '|' characters:
				# [https://www.perlmonks.org/bare/?node_id=319761]
				# my @ff = split(/(?<!\\)\|/, $ss);
				my @flags = split(/(?:\\\\\|)|(?:(?<!\\)\|)/, $1);

				# Loop over flags to process.
				foreach my $flag (@flags) {
					# Remove boolean indicator from flag if present.
					if ($flag =~ /\?$/) {
						$flag = substr($flag, 0, -1);
					}

					# Track multi-starred flags.
					if ($flag =~ /\=\*/) {
						my $rpl = $flag =~ s/\=\*//r;
						$__dc_multiflags .= " $rpl ";
					}

					# Unescape flag.
					# $flag = __unescape($flag);

					# Flag must start with the last word.
					# Escape special chars: [https://stackoverflow.com/a/576459]
					# [http://perldoc.perl.org/functions/quotemeta.html]
					my $pattern = '^' . quotemeta($last);
					if ($flag =~ /$pattern/) {

						# Note: If the last word is "--" or if the last
						# word is not in the form "--form= + a character",
						# don't show flags with values (--flag=value).
						if (!includes($last, "=") && $flag =~ /$flgoptvalue/ && substr($flag, -1) ne "\*") {
							next;
						}

						# No dupes unless it's a multi-starred flag.
						if (!__dupecheck($flag)) {
							# Remove "*" multi-flag marker from flag.
							$flag =~ s/\=\*/=/;

							# If last word is in the form → "--flag=" then we
							# need to remove the last word from the flag to
							# only return its options/values.
							if ($last =~ /$flgopt/) {
								# Copy flag to later reset flag key if no
								# option was provided for it.
								my $flagcopy = "$flag";

								# Reset flag to its option. If option is empty
								# (no option) then default to flag's key.
								# flag+="value"
								($flag) = $flag =~ /=(.*)$/;
								if (!$flag) {
									$flag = "$flagcopy";
								}
							}

							# Note: This is more of a hack check.
							# Values with special characters will
							# sometime by-pass the previous checks
							# so do one file check. If the flag
							# is in the following form:
							# ----flags="value-string" then we do
							# not add is to the completions list.
							# Final option/value check.
							my $__isquoted = 0;
							if (includes($flag, "=")) {
								my ($ff) = $flag =~ /=(.*)$/;
								if (__is_lquoted(substr($ff || "", 0, 1))) {
									$__isquoted = 1;
								}
							}

							# Add flag/options if all checks pass.
							if ($__isquoted == 0 && $flag ne $last) {
								if ($flag) {
									push(@completions, $flag);
								}
							}
						} else {
							# If flag exits and is already used then add a space after it.
							if ($flag eq $last) {
								if (!includes($last, "=")) {
									push(@used, $last);
								} else {
									($flag) = $flag =~ /=(.*)$/;
									if ($flag) {
										push(@completions, $flag);
									}
								}
							}
						}
					}
				}
				# done <<< "$rows"

				# Note: If the last word (the flag in this case) is an
				# options flag (i.e. --flag=val) we need to remove the
				# possible already used value. For example take the
				# following scenario. Say we are completing the following
				# flag '--flag=7' and our two options are '7' and '77'.
				# Since '7' is already used we remove that value to leave
				# '77' so that on the next tab it can be completed to
				# '--flag=77'.
				my $l = $#completions;
				# Get the value from the last word.
				my ($val) = $last =~ /=(.*)$/;
				$val = $val || "";

				# Note: Account for quoted strings. If the last value is
				# quoted, then add closing quote.
				if (__is_lquoted($val)) {
					# Get starting quote (i.e. " or ').
					my $quote = substr($val, 0, 1);
					if (substr($val, -1) ne "$quote") {
						$val .= "$quote";
					}

					# Escape for double quoted strings.
					$type = "flag;quoted";
					if ($quote eq "\"") {
						$type .= ";noescape";
					}

					# If the value is empty return.
					if (length($val) == 2) {
						push(@completions, "${quote}${quote}");
						return;
					}
				}

				# If the last word contains an eq sign, it has a value
				# option, and there are more than 2 possible completions
				# we remove the already used option.
				if (includes($last, "=") && $val && ($l + 1) >= 2) {
					for (my $i = $l; $i >= 0; $i--) {
						if (length($completions[$i]) == length($val)) {
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

		# If command chain and used flags exits, don't complete.
		if ($usedflags && $commandchain) {
			# Reset commandchain and usedflags.
			$commandchain = "$maincommand.$last";
			$usedflags = "";
		}

		# Lookup command tree rows from acmap.
		my @rows = ();
		# Replacement type.
		my $rtype = "";
		# Switch statement: [https://stackoverflow.com/a/22575299]
		if ($lastchar eq " ") {
			my $pattern = '^(' . "$commandchain" . '\\..*)$';
			@rows = $acmap =~ /$pattern/mg;
			$rtype = 1;
		} else {
			my $pattern = '^' . "$commandchain" . '.[-:a-zA-Z0-9]* ';
			@rows = $acmap =~ /$pattern/mg;
			$rtype = 2;
		}

		# If no upper level exists for the commandchain check that
		# the current chain is valid. If valid, add the last command
		# to the completions array to bash can append a space when
		# the user presses the [tab] key to show the completion is
		# complete for that word.
		if (scalar(@rows) == 0) {
			my $pattern = '^' . "$commandchain" . ' ';
			@rows = $acmap =~ /$pattern/mg;
			if (scalar(@rows) && $lastchar ne " ") {
				# Add last command in chain.
				@completions = (__last_command($rows[0], $rtype));
			}
		} else {
			# If caret is in the last position, the command tree
			# exists, and the command tree does not contains any
			# upper levels then we simply add the last word so
			# that bash can add a space to it.
			my $pattern = '^' . "$commandchain" . ' ';
			my @row = $acmap =~ /$pattern/mg;
			my $check1 = scalar(@row);

			$pattern = '^' . "$commandchain" . '[-:a-zA-Z0-9]+ ';
			@row = $acmap =~ /$pattern/mg;
			my $check2 = scalar(@row);

			if ($check1 && !$check2 && $lastchar ne " ") {
				@completions = ($last);
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
						if ($lastchar ne " ") {
							# Since we are completing a command we only
							# want words that start with the current
							# command we are trying to complete.
							my $pattern = '^' . "$last";
							if ($row =~ /$pattern/) {
								push(@completions, $row);
							}
						} else {
							# If we are not completing a command then
							# we return all possible word completions.
							push(@completions, $row);
						}
					}
				}
			}
		}
	}
}

# Send all possible completions to bash.
sub __printer {
	# Build and contains all completions in a string.
	my $lines = "$type:$last";
	# ^ The first line will contain meta information about the completion.

	# Loop over completions and append to list.
	for my $i (0 .. $#completions) {
		$lines .= "\n" . $completions[$i];
	}

	# Return data.
	print $lines;
}

# Completion logic:
# <cli_input> → parser → extracter → lookup → printer
# Note: Supply CLI input from start to caret index.
__parser(substr($cline, 0, $cpoint));__extracter();__lookup();__printer();
