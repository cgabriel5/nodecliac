#!/usr/bin/perl
# '-d:NYTProf' to profile script.

# use strict;
# use warnings;
# use diagnostics;

use Term::ANSIColor; # qw(:constants); # [https://stackoverflow.com/a/22224983]
# [https://stackoverflow.com/a/5741454] , [https://stackoverflow.com/a/3201613]
# use Data::Dump qw(dump); # Install: $ perl -MCPAN -e install Data::Dump
use Data::Dumper; # [https://stackoverflow.com/q/11261854]
$Data::Dumper::Indent=0; $Data::Dumper::Terse = 1;

my $oinput = $ARGV[0]; # Original unmodified CLI input.
my $cline = $ARGV[1]; # CLI input (could be modified via pre-parse).
my $cpoint = int($ARGV[2]); # Caret index when [tab] key was pressed.
my $maincommand = $ARGV[3]; # Get command name from sourced passed-in argument.
my $acdef = $ARGV[4]; # Get the acdef definitions file.
my $posthook = $ARGV[5]; # Get the posthook file path.
my $singletons = int($ARGV[6]); # Show singleton flags?

my @args = ();
my @cargs = ();
my @posargs = ();
my $afcount = 0;
# Arguments meta data: [eq-sign index, isBool]
my @ameta = ();
my $last = '';
my $quote_open = 0;
# Parsed last (flag) data.
my $dflag = (); # [flag, eq, value]
my $type = '';
my @foundflags = ();
my @completions = ();
my $commandchain = '';
my $lastchar; # Character before caret.
my $nextchar = substr($cline, $cpoint, 1); # Character after caret.
my $cline_length = length($cline); # Original input's length.
my $isquoted = 0;
# my $autocompletion = 1;
my $input = substr($cline, 0, $cpoint); # CLI input from start to caret index.
my $input_remainder = substr($cline, $cpoint, -1); # CLI input from caret index to input string end.
my $hdir = $ENV{'HOME'};
my $TESTMODE = $ENV{'TESTMODE'};
my $DEBUGMODE = 1;
my @debuglines = ();
my $filedir = '';

my %db;
$db{'defaults'} = {};
$db{'filedirs'} = {};
$db{'contexts'} = {};

my %usedflags;
my %usedflags_valueless;
my %usedflags_multi;
my %usedflags_counts;

my $used_default_pa_args = '';
my $prefix = 'NODECLIAC_';

my $pstart = colored("[", "bold");
my $pend = colored("]", "bold");
my $decor = "------------";
my $header = colored("DEBUGMODE", "bold magenta");
my $script = colored("Perl", "bold");
my $dheader = "\n$decor [$header $script] $decor";

# Adds line to debug line array.
#
# @param  {string} line - The line to add.
# @param  {bool} skip - Whether to skip line.
# @return {string} - The header string.
sub __dline {
	my ($line, $skip) = @_;
	$skip //= 0;

	if (!$skip) { push(@debuglines, $line); }
	else { # If last entry is a "newline" (empty) skip it.
		if ($debuglines[-1] ne "\n") { push(@debuglines, $line); }
	}
}

# Prints a debug header.
#
# @param  {string} name - Header name.
# @param  {string} message - Optional trailing message.
# @return {string} - The header string.
sub __dhd {
	my ($name, $message) = @_;
	my $result = " " . colored($name, "underline bold") . ":";
	if ($message) { $result .= "$pstart$message$pend"; }
	return $result;
}

# Prints a debug function row.
#
# @param  {string} name - Function name.
# @param  {string} message - Optional trailing message.
# @return {string} - The function string.
sub __dfn {
	my ($name, $message) = @_;
	my $result = colored("fn", "magenta bold");
	$result .= " " . colored($name, "underline bold") .  ":";
	if ($message) { $result .= " $message"; }
	return $result;
}

# Prints a debug variable row.
#
# @param  {string} name - Variable name.
# @param  {string} message - Optional trailing message.
# @return {string} - The variable string.
sub __dvar {
	my ($name, $string) = @_;
	my $result = "  - " . colored($name, "cyan") . ": ";
	return $result;
}

if ($DEBUGMODE) {
	__dline("$dheader (" . colored("exit", "bold") . ": nodecliac debug --disable)\n\n");
	__dline(__dhd("Arguments") . "\n");
	__dline(__dvar("oinput") . "$pstart$oinput$pend\n");
	__dline(__dvar("cline") . "$pstart$cline$pend\n");
	__dline(__dvar("cline.len") . $pstart . length($cline) . "$pend\n");
	__dline(__dvar("cpoint") . "$pstart$cpoint$pend\n");
	__dline(__dvar("maincommand") . "$pstart$maincommand$pend\n");
	my $p = "~/.nodecliac/registry/$maincommand/$maincommand.acdef";
	__dline(__dvar("acdef") . "$pstart$p$pend\n");
	__dline("\n");
}

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
				# $command .= " \"$($qchar" . $arg . "$qchar)\"";
				# Wrap command with ticks to target the common shell 'sh'.
				$command .= " $qchar`" . $arg . "`$qchar";
			} else {
				$arg = substr($arg, 1, -1); # Unquote.
				$command .= " $arg";
			}
		}
	}

	__set_envs();
	my $res = do { open(EPIPE, '-|', $command); local $/; <EPIPE>; };
	if ($res) { @r = split(/$delimiter/m, $res); }

	if ($DEBUGMODE) {
		__dline("\n");
		__dline(__dfn("execCommand") . "\n");
		__dline(__dvar("command") . "$pstart$command$pend\n");
		__dline(__dvar("res") . "$pstart$res$pend\n");
		__dline("\n");
	}

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
			} elsif (@arguments && $c eq '$' && !$argument) { $argument .= $c; }
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
	my ($params) = @_;
	my $l = $#args + 1;
	my $post = $params->{post}; # [https://stackoverflow.com/a/8124745]
	my @arguments = @{ $params->{arguments} };
	my $ctype = (rindex($type, 'c', 0) == 0 ? "command" : "flag");
	my $prev = $args[(!$post ? -2 : -1)];

	# Get any used flags to pass along. [https://stackoverflow.com/a/30094856]
	my @usedflags = (keys %usedflags);

	my %envs = (
		# nodecliac exposed Bash env vars.

		"${prefix}COMP_LINE" => $cline, # Original (unmodified) CLI input.
		# Caret index when [tab] key was pressed.
		"${prefix}COMP_POINT" => $cpoint,

		# nodecliac env vars.

		# The command auto completion is being performed for.
		"${prefix}MAIN_COMMAND" => $maincommand,
		"${prefix}COMMAND_CHAIN" => $commandchain, # The parsed command chain.
		"${prefix}USED_FLAGS" => join("\n", @usedflags), # The parsed used flags.
		# The last parsed word item (note: could be a partial word item.
		# This happens when the [tab] key gets pressed within a word item.
		# For example, take the input 'maincommand command'. If
		# the [tab] key was pressed like so: 'maincommand comm[tab]and' then
		# the last word item is 'comm' and it is a partial as its remaining
		# text is 'and'. This will result in using 'comm' to determine
		# possible auto completion word possibilities.).
		"${prefix}LAST" => $last,
		# The word item preceding last word item.
		"${prefix}PREV" => $prev,
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
		"${prefix}USED_DEFAULT_POSITIONAL_ARGS" => $used_default_pa_args,
		# Whether completion is being done for a command or a flag.
		"${prefix}COMP_TYPE" => $ctype
	);

# If completion is for a flag, set flag data for quick access in script.
	if ($ctype eq "flag") {
		$envs{"${prefix}FLAG_NAME"} = $dflag[0];
		$envs{"${prefix}FLAG_EQSIGN"} = $dflag[1];
		$envs{"${prefix}FLAG_VALUE"} = $dflag[2];
		# Indicates if last word is an open quoted value.
		$envs{"${prefix}QUOTE_OPEN"} = $quote_open;
	}

	# Set completion index (index where completion is being attempted) to
	# better mimic bash's $COMP_CWORD builtin variable.
	my $comp_index = !$lastchar ||
		(length($last) > 0 && (
			substr($last, 0, 1) =~ tr/"'// || $quote_open ||
			substr($last, -2, 1) eq '\\'
		)) ? $l - 1 : $l;
	$envs{"${prefix}COMP_INDEX"} = $comp_index;
	# Also, ensure NODECLIAC_PREV is reset to the second last argument
	# if it exists only when the lastchar is empty to To better mimic
	# prev=${COMP_WORDS[COMP_CWORD-1]}.
	if ($lastchar eq '' && $l > $l - 2) { $envs{"${prefix}PREV"} = $args[$l - 2]; }

	if ($DEBUGMODE) {
		__dline("\n", 1);
		__dline(__dfn("setEnvs") . "\n");
		__dline(__dvar("${prefix}COMP_INDEX") . "$pstart$comp_index$pend\n");
		__dline(__dvar("${prefix}COMP_LINE") . "$pstart$cline$pend\n");
		__dline(__dvar("${prefix}COMP_POINT") . "$pstart$cpoint$pend\n");
		__dline(__dvar("${prefix}MAIN_COMMAND") . "$pstart$maincommand$pend\n");
		__dline(__dvar("${prefix}COMMAND_CHAIN") . "$pstart$commandchain$pend\n");
		__dline(__dvar("${prefix}USED_FLAGS") . "$pstart" . Dumper(\@usedflags) . "$pend\n");
		__dline(__dvar("${prefix}LAST") . "$pstart$last$pend\n");
		__dline(__dvar("${prefix}PREV") . "$pstart$prev$pend\n");
		__dline(__dvar("${prefix}INPUT") . "$pstart$input$pend\n");
		__dline(__dvar("${prefix}INPUT_ORIGINAL") . "$pstart$oinput$pend\n");
		__dline(__dvar("${prefix}INPUT_REMAINDER") . "$pstart$input_remainder$pend\n");
		__dline(__dvar("${prefix}LAST_CHAR") . "$pstart$lastchar$pend\n");
		__dline(__dvar("${prefix}NEXT_CHAR") . "$pstart$nextchar$pend\n");
		__dline(__dvar("${prefix}COMP_LINE_LENGTH") . "$pstart$cline_length$pend\n");
		__dline(__dvar("${prefix}INPUT_LINE_LENGTH") . $pstart . length($input) . "$pend\n");
		__dline(__dvar("${prefix}ARG_COUNT") . "$pstart$l$pend\n");
		__dline(__dvar("${prefix}USED_DEFAULT_POSITIONAL_ARGS") . "$pstart$used_default_pa_args$pend\n");
		__dline(__dvar("${prefix}COMP_TYPE") . "$pstart$ctype$pend\n");
		__dline(__dvar("${prefix}FLAG_NAME") . "$pstart" . $dflag[0] . "$pend\n");
		__dline(__dvar("${prefix}FLAG_EQSIGN") . "$pstart" . $dflag[1] . "$pend\n");
		__dline(__dvar("${prefix}FLAG_VALUE") . "$pstart" . $dflag[2] . "$pend\n");
		__dline(__dvar("${prefix}QUOTE_OPEN") . "$pstart$quote_open$pend\n");
	}

	# Add parsed arguments as individual env variables.
	my $i = 0; foreach my $arg (@args) {
		__dline(__dvar("${prefix}ARG_${i}") . "$pstart$arg$pend\n");
		$envs{"${prefix}ARG_${i}"} = $arg; $i++;
	}

	# Set all env variables.
	if (@arguments == 0) { foreach my $key (keys %envs) { $ENV{$key} = $envs{$key}; }
	} else { # Set requested ones only.
		foreach my $env_name (@arguments) {
			my $key = "${prefix}$env_name";
			if (exists($envs{$key})) { $ENV{$key} = $envs{$key}; }
		}
	}

	# if ($DEBUGMODE) {
	# 	__dline("\n");
	# 	__dline(__dfn("setEnvs") . "\n");
	# 	__dline(__dvar("envs") . $pstart . Dumper(\%envs) . "$pend\n");
	# }
}

# --------------------------------------------------------------- MAIN-FUNCTIONS

# Parses CLI input.
#
# @return - Nothing is returned.
sub __tokenize {
	my $argument = '';
	my $qchar = '';
	my $input = $input;
	my $delindex = -1;
	my $c; my $p;

	if (!$input) { return; }

	# [TODO]: Re-do spread function; needs to be simplified/robust.

	# Spreads input, ex: '-n5 -abc "val"' => '-n 5 -a -b -c "val"'
	#
	# @param  {string} argument - The string to spread.
	# @return {string} - The remaining argument.
	sub spread {
		my ($argument) = @_;

		if (length($argument) >= 3 && substr($argument, 1, 1) ne '-'
			&& $argument =~ tr/=//) {
			substr($argument, 0, 1, "");
			my $lchar = chop($argument);
			$argument .= $lchar;

			if ($lchar =~ tr/1234567890//) {
				my $argletter = substr($argument, 0, 1);
				substr($argument, 0, 1, "");
				push(@ameta, [$delindex, 0]); $delindex = -1;
				push(@args, "-$argletter");
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
					elsif ($i == $max) { last; }

					push(@ameta, [$delindex, 0]); $delindex = -1;
					push(@args, "-$char"); $i++;
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
				# if ($input && rindex($input, ' ', 0) != 0) { next; }

				push(@ameta, [$delindex, 0]); $delindex = -1;
				push(@args, rindex($argument, '-', 0) ? $argument : spread($argument));
				$argument = '';
				$qchar = '';
			}
		} else {
			if ($c =~ tr/"'// && $p ne '\\') {
				$qchar = $c;
				$argument .= $c;

			} elsif ($c =~ tr/ \t// && $p ne '\\') {
				if (!$argument) { next; }

				push(@ameta, [$delindex, 0]); $delindex = -1;
				push(@args, rindex($argument, '-', 0) ? $argument : spread($argument));
				$argument = '';
				$qchar = '';

			} else {
				if ($c =~ tr/=:// && $delindex == -1 && length($argument) > 0 && rindex($argument, '-', 0) == 0) {
					$delindex = length($argument);
					$c = '='; # Normalize ':' to '='.
				}
				$argument .= $c;
			}
		}
	}

	# If the qchar is set, there was an unclosed string like:
	# '$ op list itema --categories="Outdoor '
	if ($qchar) { $quote_open = 1; }

	# Get last argument.
	if ($argument) {
		push(@ameta, [$delindex, 0]); $delindex = -1;
		push(@args, rindex($argument, '-', 0) ? $argument : spread($argument));
	}

	# Get/store last char of input.
	$lastchar = !($c ne ' ' && $p ne '\\') ? $c : '';

	if ($DEBUGMODE) {
		__dline(__dfn("tokenize") . "\n");
		__dline(__dvar("ameta") . $pstart . Dumper(\@ameta) . "$pend\n");
		__dline(__dvar("args") . $pstart . Dumper(\@args) . "$pend\n");
		__dline(__dvar("lastchar") . "$pstart$lastchar$pend\n");
		__dline("\n");
	}
}

# Determine command chain, used flags, and set needed variables.
#
# @return - Nothing is returned.
sub __analyze {
	my $l = $#args + 1;
	my @commands = ('');
	my @chainstrings = (' ');
	my @chainflags = (['']);
	my @delindices = ([0]);
	my @bounds = (0);
	my $aindex = 0;
	my $start = 0;
	my $end = 0;

	for (my $i = 1; $i < $l; $i++) {
		my $item = $args[$i];
		my $nitem = $args[$i + 1];

		# # Skip quoted or escaped items.
		# if (substr($item, 0, 1) =~ tr/"'// || $item =~ tr/\\//) {
		# 	push(@posargs, $item);
		# 	push(@cargs, $item);
		# 	next;
		# }

		if (rindex($item, '-', 0)) {
			my $command = __normalize_command($item);
			my $chain = join('.', @commands) . '.' . $command;
			if (rindex($chain, '.', 0) != 0) { $chain = '.' . $chain; }

			# [https://stackoverflow.com/a/87504]
			my $pattern = '^' . quotemeta($chain) . '[^ ]* ';
			$start = 0; $end = 0;
			if ($acdef =~ /$pattern/m) {
				$start = $-[0]; $end = $+[0]; }
			if ($start) {
				push(@chainstrings, substr($acdef, $start, $end - $start));
				push(@chainflags, []);
				push(@delindices, []);
				push(@bounds, $start);
				push(@commands, $command);
				$aindex++;
			} else { push(@posargs, $item); }

			push(@cargs, $item);

		} else {
			$afcount++; # Increment flag counter.

			if ($ameta[$i]->[0] > -1) {
				push(@cargs, $item);
				push(@{$chainflags[-1]}, $item);
				push(@{$delindices[-1]}, $ameta[$i]->[0]);
				next;
			}

			my $flag = __validate_flag($item);
			my $pattern = '^' . quotemeta($chainstrings[-1]) . '(.+)$';
			$start = 0; $end = 0;
			pos($acdef) = $bounds[$aindex];
			if ($acdef =~ /$pattern/m) { $start = $-[0]; $end = $+[0]; }
			pos($acdef) = 0; # [https://stackoverflow.com/a/4587683]
			my $row = substr($acdef, $start, $end - $start);

			$pattern = $flag . '\?(\||$)';
			if ($row =~ /$pattern/m) {
				push(@cargs, $flag);
				$ameta[$i]->[1] = 1;
				push(@{$chainflags[-1]}, $flag);
				push(@{$delindices[-1]}, $ameta[$i]->[0]);

			} else {
				if ($nitem && rindex($nitem, '-', 0) != 0) {
					my $vitem = $flag . '=' . $nitem;
					push(@cargs, $vitem);
					push(@{$chainflags[-1]}, $vitem);
					$ameta[$i]->[0] = length($flag);
					push(@{$delindices[-1]}, $ameta[$i]->[0]);
					$i++;
				} else {
					push(@cargs, $flag);
					push(@{$chainflags[-1]}, $flag);
					push(@{$delindices[-1]}, $ameta[$i]->[0]);
				}
			}
		}
	}

	# Set needed data: cc, pos args, last word, and found flags.

	$commandchain = __validate_command(join('.', @commands));
	if (rindex($commandchain, '.', 0)) { $commandchain = '.' . $commandchain; }
	if ($commandchain eq '.') { $commandchain = ''; }

	if (@posargs) { $used_default_pa_args = join("\n", @posargs); }

	$last = ($lastchar eq ' ') ? '' : $cargs[-1];
	# Reset if completion is being attempted for a quoted/escaped string.
	if ($lastchar eq ' ' && scalar(@cargs) > 0) {
		my $litem = $cargs[-1];
		my $lchar = substr($litem, 0, 1);
		$quote_open = ($quote_open && $lchar eq '-');
		if ($lchar =~ tr/"'// || $quote_open || substr($litem, -2, 1) eq '\\') {
			$last = $litem;
		}
	}
	if (substr($last, 0, 1) =~ tr/"'//) { $isquoted = 1; }

	# Handle case: 'nodecliac print --command [TAB]'
	if ($last eq '' && @cargs && rindex($cargs[-1], '-', 0) == 0 &&
		$cargs[-1] !~ tr/=// && $ameta[-1][0] == -1 && $ameta[-1][1] == 0) {
		my $r = $cargs[-1] . '=';
		my $l = length($r) - 1;
		$lastchar = '';
		$last = $r;
		$cargs[-1] = $r;
		$args[-1] = $r;
		$ameta[-1][0] = $l;
		$chainflags[-1][scalar(@{$chainflags[-1]}) - 1] = $r;
		$delindices[-1][scalar(@{$delindices[-1]}) - 1] = $l;
	}

	# Store used flags for later lookup.
	@foundflags = @{$chainflags[-1]};
	my @usedflags_meta = @{$delindices[-1]};
	my $i = 0;
	foreach my $uflag (@foundflags) {
		my $uflag_fkey = $uflag;
		my $uflag_value = '';

		my $eqsign_index = $usedflags_meta[$i];
		if ($eqsign_index > -1) {
			my $eqsign_index = index($uflag, '=');
			$uflag_fkey = substr($uflag, 0, $eqsign_index);
			$uflag_value = substr($uflag, $eqsign_index + 1);
		}

		if ($uflag_value) {$usedflags{$uflag_fkey}{$uflag_value} = 1;}
		else { $usedflags_valueless{$uflag_fkey} = undef; }

		# Track times flag was used.
		if ($uflag_fkey && ($uflag_fkey ne '--' || $uflag_fkey ne '-')) {
			$usedflags_counts{$uflag_fkey}++;
		}

		$i++;
	}

	if ($DEBUGMODE) {
		__dline(__dfn("analyze") . "\n");
		__dline(__dvar("commandchain") . $pstart . $commandchain . "$pend\n");
		__dline(__dvar("ameta") . $pstart . Dumper(\@ameta) . "$pend\n");
		__dline(__dvar("args") . $pstart . Dumper(\@args) . "$pend\n");
		__dline(__dvar("cargs") . $pstart . Dumper(\@cargs) . "$pend\n");
		__dline(__dvar("commands") . $pstart . Dumper(\@commands) . "$pend\n");
		__dline(__dvar("lastchar") . $pstart . $lastchar . "$pend\n");
		__dline(__dvar("last") . $pstart . $last . "$pend\n");
		__dline(__dvar("chainstrings") . $pstart . Dumper(\@chainstrings) . "$pend\n");
		__dline(__dvar("chainflags") . $pstart . Dumper(\@chainflags) . "$pend\n");
		__dline(__dvar("foundflags") . $pstart . Dumper(\@foundflags) . "$pend\n");
		__dline(__dvar("delindices") . $pstart . Dumper(\@delindices) . "$pend\n");
		__dline(__dvar("posargs") . $pstart . Dumper(\@posargs) . "$pend\n");
		__dline(__dvar("used_default_pa_args") . $pstart . $used_default_pa_args . "$pend\n");
		__dline(__dvar("isquoted") . $pstart . $isquoted . "$pend\n");
		__dline(__dvar("usedflags") . $pstart . Dumper(\%usedflags) . "$pend\n");
		__dline(__dvar("usedflags_valueless") . $pstart . Dumper(\%usedflags_valueless) . "$pend\n");
		__dline(__dvar("usedflags_multi") . $pstart . Dumper(\%usedflags_multi) . "$pend\n");
		__dline(__dvar("usedflags_counts") . $pstart . Dumper(\%usedflags_counts) . "$pend\n");
		__dline("\n");
	}
}

# Lookup acdef definitions.
#
# @return - Nothing is returned.
sub __lookup {
	# if ($isquoted || !$autocompletion) { return; }

	if (rindex($last, '-', 0) == 0) {
		if ($DEBUGMODE) { __dline(__dfn("lookup", "(flag)") . "\n"); }

		$type = 'flag';

		my $letter = substr($commandchain, 1, 1) // '';

		if ($DEBUGMODE) {
			__dline(__dvar("letter") . "$pstart$letter$pend\n");
			__dline(__dvar("commandchain") . "$pstart$commandchain$pend\n");
		}

		if ($db{dict}{$letter}{$commandchain}) {
			my %parsedflags;
			my %excluded;
			my $excluded_all = 0;
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

			if ($DEBUGMODE) { __dline(__dvar("flags") . $pstart . Dumper(\@flags) . "$pend\n"); }

			# Context string logic: start --------------------------------------

			my $cchain = ($commandchain eq '_' ? '' : quotemeta($commandchain));
			if ($DEBUGMODE) { __dline(__dvar("cchain") . "$pstart$cchain$pend\n"); }
			my $pattern = '^' . $cchain . ' context ("|\')(.+)\1$';
			if ($acdef =~ /$pattern/m) {
				my @ctxs = split(/;/, $2);
				foreach my $_c (@ctxs) {
					(my $ctx = $_c) =~ s/\s+//g;
					if (length($ctx) == 0) { next; }
					if (rindex($ctx, '{', 0) == 0 && substr($ctx, -1) ne '}') { # Mutual exclusion.
						$ctx =~ s/^{|}$//g;
						my @flags = map {
							(length($_) == 1 ? '-' : '--') . $_;
						} (split(/\|/, $ctx));
						my $exclude = '';
						foreach my $flag (@flags) {
							if (exists($usedflags_counts{$flag_fkey})) {
								$exclude = $flag;
								last;
							}
						}
						if ($exclude ne '') {
							foreach my $flag (@flags) {
								if ($exclude ne $flag) { $excluded{$flag} = 1; }
							}
							delete $excluded{$exclude};
						}
					} else {
						my $r = 0;
						if ($ctx =~ tr/://) {
							my @parts = split(/:/, $ctx);
							my @flags = split(/,/, $parts[0]);
							my @conditions = split(/,/, $parts[1]);
							# Examples:
							# flags:      !help,!version
							# conditions: #fge1, #ale4, !#fge0, !flag-name
							# [TODO?] index-conditions: 1follow, 1!follow
							foreach my $condition (@conditions) {
								my $invert = 0;
								my $condition = $condition;
								# Check for inversion.
								if (rindex($condition, '!', 0) == 0) {
									substr($condition, 0, 1, '');
									$invert = 0;
								}

								my $fchar = substr($condition, 0, 1);
								if ($fchar eq '#') {
									my $operator = substr($condition, 2, 2);
									my $n = int(substr($condition, 4));
									my $c = 0;
									if (substr($condition, 1, 1) eq 'f') {
										# [https://stackoverflow.com/a/37438262]
										$c = keys(%{$usedflags_counts});
										# Account for used '--' flag.
										if ($c == 1 && exists($usedflags_counts{'--'})) { $c = 0; }
										if (!$lastchar) { $c--; }
									} else { $c = $#posargs + 1; }
									if    ($operator eq "eq") { $r = ($c == $n ? 1 : 0); }
									elsif ($operator eq "ne") { $r = ($c != $n ? 1 : 0); }
									elsif ($operator eq "gt") { $r = ($c >  $n ? 1 : 0); }
									elsif ($operator eq "ge") { $r = ($c >= $n ? 1 : 0); }
									elsif ($operator eq "lt") { $r = ($c <  $n ? 1 : 0); }
									elsif ($operator eq "le") { $r = ($c <= $n ? 1 : 0); }
									if ($invert) { $r = ($r == 1) ? 0 : 1; }
								# elsif ($fchar in {'1'..'9'}) { next; } # [TODO?]
								} else { # Just a flag name.
									if ($fchar eq '!') {
										if (exists($usedflags_counts{$condition})) { $r = 0; }
									} else {
										if (exists($usedflags_counts{$condition})) { $r = 1; }
									}
								}
								# Once any condition fails exit loop.
								if ($r == 0) { last; }
							}
							if ($r == 1) {
								(my $llast = $last) =~ s/^-*//g;
								foreach my $flag (@flags) {
									# my $flag = flag;
									my $fchar = substr($flag, 0, 1);
									$flag =~ s/\!//g;

									if ($flag eq '*') {
										$excluded_all = 1;
										my $found = 0;
										for (@conditions) {
											if ($_ eq $llast) {
												$found = 1;
												last;
											}
										}
										if ($found == 1) { $excluded_all = 0; }
										next;
									}

									$flag = (length($flag) == 1 ? '-' : '--') . $flag;
									if ($fchar eq '!') { $excluded{$flag} = 1; }
									else { delete $excluded{$flag}; }
								}
							}
						} else {
							if ($fchar eq '!') {
								if (exists($usedflags_counts{$condition})) { $r = 0; }
							} else {
								if (exists($usedflags_counts{$condition})) { $r = 1; }
							}
							if ($r == 1) {
								my $flag = $ctx;
								my $fchar = substr($flag, 0, 1);
								$flag =~ s/\!//g;
								$flag = (length($flag) == 1 ? '-' : '--') . $flag;
								if ($fchar eq '!') { $excluded{$flag} = 1; }
								else { delete $excluded{$flag}; }
							}
						}
					}
				}
			}

			if ($DEBUGMODE) { __dline(__dvar("excluded") . $pstart . Dumper(\%db{excluded}) . "$pend\n"); }

			# Context string logic: end ----------------------------------------

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

			# Store data for env variables.
			push(@dflag, $last_fkey, $last_eqsign, $last_value);

			if ($excluded_all == 1) { @flags = (); }

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
				if ($flag_fkey =~ tr/\=//) {
					my $eqsign_index = index($flag, '=');
					$flag_fkey = substr($flag, 0, $eqsign_index);
					$flag_value = substr($flag, $eqsign_index + 1);
					$flag_eqsign = '=';

					if (rindex($flag_fkey, '?') > -1) { chop($flag_fkey); }
					# Skip flag if it's mutually exclusivity.
					if (exists($excluded{$flag_fkey})) { next; }

					if (rindex($flag_value, '*', 0) == 0) {
						$flag_multif = '*';
						$flag_value = substr($flag_value, 1);

						# Track multi-starred flags.
						$usedflags_multi{$flag_fkey} = undef;
					}

					# Create completion flag item.
					$cflag = "$flag_fkey=$flag_value";

					# If a command-flag, run it and add items to array.
					if (rindex($flag_value, "\$(", 0) == 0 && substr($flag_value, -1) eq ')' && $last_eqsign == '=') {
						$type = "flag;nocache";
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
					# Skip flag if it's mutually exclusivity.
					if (exists($excluded{$flag_fkey})) { next; }

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
				if (exists($usedflags_multi{$flag_fkey})) {

					# Check if multi-starred flag value has been used.
					if ($flag_value && exists($usedflags{$flag_fkey}{$flag_value})) { $dupe = 1; }

				} elsif (!$flag_eqsign) {

					# Valueless --flag (no-value) dupe check.
					if (exists($usedflags_valueless{$flag_fkey}) || (
					# Check if flag was used with a value already.
						exists($usedflags{$flag_fkey}) &&
						$usedflags_counts{$flag_fkey} < 2 &&
						!$lastchar
					)) { $dupe = 1; }

				} else { # --flag=<value> (with value) dupe check.

					# If usedflags contains <flag:value> at root level.
					if (exists($usedflags{$flag_fkey})) {
						# If no values exists.
						if (!$flag_value) { $dupe = 1; # subl -n 2, subl -n 23

						# Else check that value exists...
						} elsif (exists($usedflags{$flag_fkey}{$flag_value})) {
							$dupe = 1; # subl -n 23 -n

						} elsif (exists($usedflags_counts{$flag_fkey})) {
							if ($usedflags_counts{$flag_fkey} > 1) { $dupe = 1; }
						}

					# If no root level entry.
					} else {
						if ($last ne $flag_fkey
							&& exists($usedflags_valueless{$flag_fkey})) {

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
				if (!$singletons && length($flag_fkey) == 2 && !$flag_value) { next; }

				# If last word is in the form '--flag=', remove the last
				# word from the flag to only return its option/value.
				if ($last_eqsign) {
					if (rindex($flag_value, $last_value, 0) != 0 || !$flag_value) { next; }
					$cflag = $flag_value;
				}

				# Don't add multi-starred flag item as its non-starred
				# counterpart has already been added.
				if ($flag_multif) { next; }

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
				if (exists($parsedflags{$key}) && ($last_value ne '' || substr($last, -1) ne '=')) {
					push(@completions, $item);
				}
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

		if ($DEBUGMODE) {
			__dline(__dfn("lookup", "(command)") . "\n");
			__dline(__dvar("commandchain") . "$pstart$commandchain$pend\n");
		}

		$type = 'command';

		# # If command chain and used flags exits, don't complete.
		# if (%usedflags && $commandchain) {
		# 	$commandchain = "" . (!$last ? "" : $last);
		# }

		# If no cc get first level commands.
		if (!$commandchain && !$last) {
			if (!@posargs) { @completions = keys %{ $db{levels}{1} }; }
		} else {
			my $letter = substr($commandchain, 1, 1);
			if ($DEBUGMODE) { __dline(__dvar("letter") . "$pstart$letter$pend\n"); }
			my @rows = (keys %{ $db{dict}{$letter} });
			if ($DEBUGMODE) { __dline(__dvar("rows") . $pstart . Dumper(\@rows) . "$pend\n"); }
			my $lastchar_notspace = ($lastchar ne ' ');

			if (!@rows) { return; }

			# When there is only 1 completion item and it's the last command
			# in the command chain, clear the completions array to not re-add
			# the same command.
			# if (@rows == 1 && $rows[0] eq substr($commandchain, -length($rows[0]))) {
			# 	@rows = ();
			# }

			my %usedcommands;
			my @commands = split(/(?<!\\)\./, $commandchain);
			my $level = $#commands;
			# Increment level if completing a new command level.
			if ($lastchar eq ' ') { $level++; }

			# If level does not match argument length, return. As the
			# parsed arguments do not match that of a valid commandchain.
			my $la = (scalar(@cargs) + 1) - $afcount;
			if ($DEBUGMODE) { __dline(__dvar("level") . "$pstart$level$pend\n"); }

			if (!(($la == $level + 1 && $lastchar) ||
				($la > $level && $lastchar) || ($la - $level > 1))) {

				# Get commandchains for specific letter outside of loop.
				my %h = %{ $db{dict}{$letter} };

				foreach my $row (@rows) {
					my @cmds = @{ $h{$row}{commands} };
					$row = $cmds[$level] // undef;

					# Add last command if not yet already added.
					if (!$row || exists($usedcommands{$row})) { next; }
					# If char before caret isn't a space, completing a command.
					if ($lastchar_notspace) {
						if (rindex($row, $last, 0) == 0) {
							my $c = rindex($commandchain, ".$row") + 1;
							if ((!$c || ($c && !$lastchar)) ||
								(!$used_default_pa_args && !$lastchar)) {
								push(@completions, $row);
							}
						}
					} else { push(@completions, $row); } # Allow all.

					$usedcommands{$row} = undef;
				}
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
				my $command_str = $db{defaults}{$copy_commandchain};
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

					$type .= ";nocache";
					last; # Stop once a command-string is found/ran.
				}

				# Remove last command chain from overall command chain.
				$copy_commandchain =~ s/$pattern//;
			}
		}
		if ($DEBUGMODE) { __dline(__dvar("completions") . $pstart . Dumper(\@completions) . "$pend\n"); }
	}

	# Get filedir of command chain.
	if (!@completions) {
		my $pattern = '^' . quotemeta($commandchain) . ' filedir ("|\')(.+)\1$';
		if ($acdef =~ /$pattern/m) { $filedir = $2; }
	}

	if ($DEBUGMODE) {
		__dline(__dvar("filedir") . "$pstart$filedir$pend\n");
		__dline("\n");
	}

	# Run posthook if it exists.
	if ($posthook) {
		my $delimiter = "\$\\r\?\\n";
		my @r = ();
		__set_envs({post => 1});
		# [https://stackoverflow.com/a/3871265]
		substr($posthook, 0, 1, $hdir) if rindex($posthook, '~', 0) == 0;
		my $res = do { open(EPIPE, '-|', $posthook); local $/; <EPIPE>; };
		$res =~ s/^\s+|\s+$//g;
		@r = split(/$delimiter/m, $res);
		if ($res) { @r = split(/$delimiter/m, $res); }
		my $dsl = 0; # Delimiter Separated List.

		if ($DEBUGMODE) {
			__dline("\n");
			__dline(__dfn("posthook") . "\n");
			__dline(__dvar("command") . "$pstart$posthook$pend\n");
			__dline(__dvar("res") . "$pstart$res$pend\n");
		}

		if (@r) {
			my $l = length($last);
			my @filtered = ();
			my @useditems = ();
			my $eqsign_index = index($last, '=');
			for my $i (0 .. $#r) {
				my $c = $r[$i];
				if ($c eq '__DSL__') { $dsl = 1; }
				if (rindex($c, '!', 0) == 0) {
					push(@useditems, substr($c, 1));
					next;
				}
				if (rindex($c, $last, 0) != 0) { next; }
				# When completing a delimited separated list, ensure to remove
				# the flag from every completion item to leave the values only.
				# [https://unix.stackexchange.com/q/124539]
				# [https://github.com/scop/bash-completion/issues/240]
				# [https://github.com/scop/bash-completion/blob/master/completions/usermod]
				# [https://github.com/scop/bash-completion/commit/021058b38ad7279c33ffbaa36d73041d607385ba]
				if ($dsl && length($c) >= $l) { $c = substr($c, $eqsign_index + 1); }
				push(@filtered, $c);
			}
			@completions = @filtered;

			if ($DEBUGMODE) {
				__dline(__dvar("__DSL__") . "$pstart$dsl$pend\n");
				__dline("\n");
			}

			if (scalar(@completions) == 0 && $dsl) {
				for my $i (0 .. $#useditems) {
					my $c = $useditems[$i];
					if (rindex($c, $last, 0) != 0) { next; }
					if ($dsl && length($c) >= $l) { $c = substr($c, $eqsign_index + 1); }
					push(@completions, $c);
				}
			}
		} else {
			if ($DEBUGMODE) {
				__dline(__dvar("__DSL__") . "$pstart$dsl$pend\n");
				__dline("\n");
			}
		}
	}
}

# Send all possible completions to bash.
sub __printer {
	my $sep = "\n";
	my $skip_map = 0;
	my $isflag = rindex($type, 'f', 0) == 0;
	my $iscommand = !$isflag;
	my $lines = "$type:$last+$filedir";

	# Note: When providing flag completions and only "--" is provided,
	# collapse (don't show) flags with the same prefix. This aims to
	# help reduce the `display all n possibilities? (y or n)` message
	# prompt. Instead, only show the prefix in the following format:
	# "--prefix..." along with the shortest completion item.
	if (@completions >= 10 && !$iscommand && $last eq '--') {

		# Finds all common prefixes in a list of strings.
		#
		# @param  {array} strs - The list of strings.
		# @return {array} - The found/collected prefixes.
		#
		# @resource [https://stackoverflow.com/q/6634480]
		# @resource [https://stackoverflow.com/a/6634498]
		# @resource [https://stackoverflow.com/a/1917041]
		# @resource [https://softwareengineering.stackexchange.com/q/262242]
		# @resource [https://stackoverflow.com/q/11397137]
		sub lcp {
			my (
				$list,
				$charloop_startindex, # Index where char loop will start at.
				$min_frqz_prefix_len, # Min length string should be to store frqz.
				$min_prefix_len, # Min length prefixes should be.
				$min_frqz_count, # Min frqz required to be considered a prefix.
				$min_src_list_size, # Min size source array must be to proceed.
				$prepend, # Prefix to prepend to final prefix.
				$append, # Suffix to append to final prefix.
				# [https://nim-lang.org/docs/tut1.html#advanced-types-open-arrays]
				@char_break_points, # Hitting these chars will break the inner loop.
			) = @_;
			my @strs = @$list; # [https://stackoverflow.com/a/45262748]
			$charloop_startindex //= 0;
			$min_frqz_prefix_len //= 1;
			$min_prefix_len //= 1;
			$min_frqz_count //= 2;
			$min_src_list_size //= 0;
			$prepend //= "";
			$append //= "";

			my $l = @strs;
			my %frqz;
			my %indices;
			my %aindices;
			my @prxs = ();
			my %xids;

			# Prepend/append prefix/suffix to string.
			#
			# @param  {string} s - The string to modidy.
			# @return {string} - The string with prepended/appended strings.
			sub __decorate { return "$_[1]$_[0]$_[2]"; }

			# If char breakpoints are provided create lookup table.
			my %char_bps;
			for my $char (@char_break_points) { $char_bps{$char} = 1; }

			if ($l < $min_src_list_size) {
				my %r = (prefixes => \@prxs, indices => \%xids);
				return \%r;
			}

			# Short-circuits.
			if ($l <= 2) {
				# Get string from startpoint to any character  breakpoints.
				#
				# @param  {string} s - String to loop.
				# @return {string} - Resulting string from any trimming/clipping.
				sub __stringloop {
					my ($s, $prepend, $append, $char_bps_ref, $charloop_startindex) = @_;
					my %char_bps = %{ $char_bps_ref };

					my $prefix = "";
					for my $i ($charloop_startindex..length($s)-1){
						my $char = substr($s, $i, 1);
						if (exists($char_bps{$char})) { last; }
						$prefix .= $char
					}
					return __decorate($prefix, $prepend, $append);
				}

				if ($l == 0) {
					my %r = (prefixes => \@prxs, indices => \%xids);
					return \%r;
				} elsif ($l == 1) {
					$xids{0} = 0;
					push(@prxs, __stringloop(
							$strs[0], $prepend,
							$append, \%char_bps,
							$charloop_startindex
						)
					);
					my %r = (prefixes => \@prxs, indices => \%xids);
					return \%r;
				} elsif ($l == 2) {
					if ($strs[0] eq $strs[1]) {
						$xids{0} = 0;
						$xids{1} = 1;
						push(@prxs, __stringloop(
								$strs[0], $prepend,
								$append, \%char_bps,
								$charloop_startindex
							)
						);
						my %r = (prefixes => \@prxs, indices => \%xids);
						return \%r;
					}

					# [https://stackoverflow.com/a/35838357]
					@strs = sort { length($b) cmp length($a) } @strs;
					my $first = $strs[0];
					my $last = $strs[1];
					my $lastlen = length($last);
					my $ep = $charloop_startindex; # Endpoint.
					while (substr($first, $ep, 1) eq substr($last, $ep, 1)) { $ep++; }
					my $prefix = substr($first, 0, $ep);

					if ($prefix) {
						my $isfirst_prefixed = (rindex($first, $prefix, 0) == 0);
						$xids{0} = (!$isfirst_prefixed);
						$xids{1} = ($isfirst_prefixed);
						push(@prxs, __stringloop(
								$prefix, $prepend, $append,
								\%char_bps,
								$charloop_startindex
							)
						);
					}

					my %r = (prefixes => \@prxs, indices => \%xids);
					return \%r;
				}
			}

			# Loop over each completion string.
			for (my $i = 0; $i < $l; $i++) {
				my $str = $strs[$i];
				my $prefix = "";

				# Loop over each char in string.
				my $ll = length($str);
				for (my $j = $charloop_startindex; $j < $ll; $j++) {
					my $char = substr($str, $j, 1);
					$prefix .= $char;

					if (exists($char_bps{$char})) { last; }

					# Store if min length satisfied.
					if (length($prefix) >= $min_frqz_prefix_len) {
						if (!exists($frqz{$prefix})) { $frqz{$prefix} = 0; }
						$frqz{$prefix}++;

						if (!exists($indices{$prefix})) { $indices{$prefix} = {}; }
						$indices{$prefix}{$i} = 1;

						if (!exists($aindices{$prefix})) { $aindices{$prefix} = []; }
						push(@{ $aindices{$prefix} }, $i);
					}
				}
			}

			my @aprefixes = ();
			my %tprefixes;

			# Use array to sort hash keys.
			my @ofrqz = ();
			foreach my $key (keys %frqz) { push(@ofrqz, $key) }
			@ofrqz = sort { lc($a) cmp lc($b) } @ofrqz;

			# Loop over each prefix in frequency table.
			loop1: foreach my $str (@ofrqz) {
				my $count = $frqz{$str};
				if (!exists($tprefixes{$str}) && $count >= 2) {
					my $prevkey = substr($str, 0, -1);
					my $prevcount = exists($tprefixes{$prevkey}) ? $tprefixes{$prevkey} : 0;

					if ($prevcount > $count) { next; }

					my $l = scalar(@aprefixes);
					if ($l) {
						for (my $i = 0; $i < $l; $i++) {
							my $prefix = $aprefixes[$i];

							if (rindex($str, $prefix, 0) == 0 && $tprefixes{$prefix} > $count) {
								next loop1;
							}
						}
					}

					if ($prevcount) {
						pop(@aprefixes);
						delete $tprefixes{$prevkey};
					}

					push(@aprefixes, $str);
					$tprefixes{$str} = $count;
				}
			}

			# Filter prefixes based on length and frqz count.
			for my $prefix (@aprefixes) {
				if (length($prefix) > $min_prefix_len && $tprefixes{$prefix} >= $min_frqz_count) {
					# Reset internal iterator so prior iteration doesn't affect loop.
					keys %{ $indices{$prefix} }; # [https://stackoverflow.com/a/3360]
					while(my($k, $v) = each %{ $indices{$prefix} }) {
						$xids{$k} = ($aindices{$prefix}[0] == $k ? 0 : $v);
					}
					push(@prxs, __decorate($prefix, $prepend, $append));
				}
			}

			my %r = (prefixes => \@prxs, indices => \%xids);
			return \%r;
		}

		# [https://stackoverflow.com/a/7446317]
		# use lib "$ENV{HOME}/.nodecliac/src/ac/utils";
		# eval "use LCP"; die $@ if $@; # [https://stackoverflow.com/a/3945763]
		# Get completion's common prefixes.
		my $res = lcp(\@completions, 2, 2, 3, 3, 0, "--", "...", ('='));
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
				$isflag
				&& !(rindex($_, '=') + 1)
				# Item cannot be quoted.
				&& ((rindex $_, '"', 0) == -1 || (rindex $_, '\'', 0) == -1)
				&& !$nextchar
			) ? ' ' : '';

			"$sep$_$final_space";
		} @completions;
	}

	# Note: bash-completion already sorts completions so this is not needed.
	# However, when testing the results are never returned to bash-completion
	# so the completions need to be sorted for testing purposes.
	if ($TESTMODE) { @completions = sort(@completions); }

	if ($DEBUGMODE) {
		@completions = sort(@completions);
		my $output = $lines . join('', @completions);
		__dline(__dfn("printer") . "\n");
		__dline(__dvar("output") . "$pstart$output$pend\n");
		__dline("$dheader\n");

		foreach my $x (@debuglines) { print $x; }

	} else { print $lines . join('', @completions); }
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

			if ($DEBUGMODE) {
				__dline(__dfn("makedb", "(first level commands only)") . "\n");
				__dline(__dvar("commandchain") . "$pstart$commandchain$pend\n");
				__dline(__dvar("db_levels") . $pstart . Dumper(\%db{levels}) . "$pend\n");
				__dline("\n");
			}

		} else { # First level flags.
			if ($acdef =~ /^ ([^\n]+)/m) {$db{dict}{''}{''} = { flags => $1 };}

			if ($DEBUGMODE) {
				__dline(__dfn("makedb", "(first level flags only)") . "\n");
				__dline(__dvar("commandchain") . "$pstart$commandchain$pend\n");
				__dline(__dvar("db_dict") . $pstart . Dumper(\%letters) . "$pend\n");
				__dline("\n");
			}
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

			# Remove starting '.'?
			my @commands = split(/(?<!\\)\./, $chain);

			# Cleanup remainder (flag/command-string).
			if (ord($line) == 45) {
				my %h = ("commands", \@commands, "flags", $line);
				$letters{substr($chain, 1, 1)}{$chain} = \%h;
			} else { # Store keywords.
				my $keyword = substr($line, 0, 7);
				my $value = substr($line, 8);
				if ($keyword eq "default") { $db{defaults}{$chain} = $value; }
				elsif ($keyword eq "filedir") { $db{filedirs}{$chain} = $value; }
				elsif ($keyword eq "context") { $db{context}{$chain} = $value; }
			}
		}

		if ($DEBUGMODE) {
			__dline(__dfn("makedb", "(entire .acdef file contents)") . "\n");
			__dline(__dvar("commandchain") . "$pstart$commandchain$pend\n");
			__dline(__dvar("db_defaults") . $pstart . Dumper(\%db_defaults) . "$pend\n");
			__dline(__dvar("db_filedirs") . $pstart . Dumper(\%db_filedirs) . "$pend\n");
			__dline(__dvar("db_contexts") . $pstart . Dumper(\%db_contexts) . "$pend\n");
			__dline(__dvar("db_dict") . $pstart . Dumper(\%letters) . "$pend\n");
			__dline("\n");
		}

		# Add letters hash to db (main) hash.
		$db{dict} = \%letters;
	}
}

__tokenize();__analyze();__makedb();__lookup();__printer();
