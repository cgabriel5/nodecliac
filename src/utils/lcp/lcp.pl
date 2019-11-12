#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

# Finds all common prefixes in a list of strings.
#
# @param  {array} strs - The list of strings.
# @return {array} - The found/collected prefixes.
#
# @resource [https://www.perlmonks.org/?node_id=274114]
# @resource [https://stackoverflow.com/q/6634480]
# @resource [https://stackoverflow.com/a/6634498]
# @resource [https://stackoverflow.com/a/35588015]
# @resource [https://stackoverflow.com/a/35838357]
# @resource [https://stackoverflow.com/a/1917041]
# @resource [https://davidwells.io/snippets/traverse-object-unknown-size-javascript]
# @resource [https://jonlabelle.com/snippets/view/javascript/calculate-mean-median-mode-and-range-in-javascript]
#
# @resource [http://perlmeme.org/faqs/perl_thinking/returning.html]
# @resource [https://stackoverflow.com/a/7094747]
# @resource [https://perlmaven.com/dereference-hash-array]
# @resource [https://stackoverflow.com/a/35792849]
# @resource [http://perlmeme.org/howtos/using_perl/dereferencing.html]
# @resource [https://perlmaven.com/array-references-in-perl]
# @resource [http://archive.oreilly.com/oreillyschool/courses/Perl3/Perl3-08.html]
# @resource [https://stackoverflow.com/a/16558903]
# @resource [https://stackoverflow.com/a/45262748]
# @resource [https://www.perl.com/article/80/2014/3/27/Perl-references--create--dereference-and-debug-with-confidence/]
# @resource [https://stackoverflow.com/a/37438262]
# @resource [https://stackoverflow.com/a/3054954]
# @resource [https://stackoverflow.com/a/12535442]
# @resource [https://stackoverflow.com/a/4893176]
# @resource [https://stackoverflow.com/a/23918269]
# @resource [https://www.perlmonks.org/?node_id=188283]
sub __lcp {
	# Get arguments.
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
	# Set argument defaults.
	my @strs = @$list; # Dereference array to make it use-able.
	$charloop_startindex //= 0;
	$min_frqz_prefix_len //= 1;
	$min_prefix_len //= 1;
	$min_frqz_count //= 2;
	$min_src_list_size //= 0;
	$prepend //= "";
	$append //= "";

	# Vars.
	my $l = @strs;
	my %frqz; # Frequency of prefixes.
	my %indices; # Track indices of strings containing any found prefixes.
	my %aindices; # Track indices order.
	# my @prefixes = (); # Final collection of found prefixes.

	# Final result tuple and its sequence values.
	my @prxs = ();
	my %xids;

	# Prepend/append provided prefix/suffix to string.
	#
	# @param  {string} s - The string to modidy.
	# @return {string} - The string with prepended/appended strings.
	sub __decorate { return "$_[1]$_[0]$_[2]"; }

	# If char breakpoints are provided turn into a lookup table.
	my %char_bps;
	for my $char (@char_break_points) { $char_bps{$char} = 1; }

	# If source array is not the min size then short-circuit.
	if ($l < $min_src_list_size) {
		my %r = (prefixes => \@prxs, indices => \%xids);
		return \%r;
	}

	# If array size is <= 2 strings use one of the following short-circuit methods.
	if ($l <= 2) {
		# Quick loop to get string from provided startpoint and end at
		#     any provided character breakpoints.
		#
		# @param  {string} s - The string to loop.
		# @return {string} - The resulting string from any trimming/clipping.
		#
		sub __stringloop {
			# Get arguments.
			my ($s, $prepend, $append, $char_bps_ref, $charloop_startindex) = @_;
			my %char_bps = %{ $char_bps_ref }; # Dereference `char_bps` hash.

			my $prefix = "";
			for my $i ($charloop_startindex..length($s)-1){
				my $char = substr($s, $i, 1); # Get current char.

				if (exists($char_bps{$char})) { last; } # Stop loop if breakpoint char is hit.
				$prefix .= $char # Gradually build prefix.
			}
			return __decorate($prefix, $prepend, $append);
		}

		if ($l == 0) {
			# If source array is empty return empty array.
			my %r = (prefixes => \@prxs, indices => \%xids);
			return \%r;
		} elsif ($l == 1) {
			# If only a single string is in array return that string.
			$xids{0} = 0; # Add string index to table.
			push(@prxs, __stringloop(
					$strs[0], $prepend,
					$append, \%char_bps,
					$charloop_startindex
				)
			);
			my %r = (prefixes => \@prxs, indices => \%xids);
			return \%r;
		} elsif ($l == 2) { # If 2 strings exists...
			# If strings match then return string...
			if ($strs[0] eq $strs[1]) {
				$xids{0} = 0; # Add string indices to table.
				$xids{1} = 1; # Add string indices to table.
				push(@prxs, __stringloop(
						$strs[0], $prepend,
						$append, \%char_bps,
						$charloop_startindex
					)
				);
				my %r = (prefixes => \@prxs, indices => \%xids);
				return \%r;
			}

			# Else use start/end-point method: [https://stackoverflow.com/a/35838357]
			# to get the prefix between the two strings.
			# Sort: [https://stackoverflow.com/a/10630852]
			# Sorting explained: [https://stackoverflow.com/a/6568100]
			# Sort strings by length. [https://perlmaven.com/sorting-arrays-in-perl]
			@strs = sort { length($b) cmp length($a) } @strs;
			my $first = $strs[0];
			my $last = $strs[1];
			my $lastlen = length($last);
			my $ep = $charloop_startindex; # Index endpoint.
			# Get common prefix between first and last completion items.
			while (
				substr($first, $ep, 1) eq substr($last, $ep, 1)) { $ep++; }

			# Add common prefix to prefixes array.
			my $prefix = substr($first, 0, $ep);

			# Add string indices to table.
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

	# Loop over each completion string...
	for (my $i = 0; $i < $l; $i++) {
		my $str = $strs[$i]; # Cache current loop item.
		my $prefix = ""; # Gradually build prefix.

		# Loop over each character in string...
		my $ll = length($str);
		for (my $j = $charloop_startindex; $j < $ll; $j++) {
			my $char = substr($str, $j, 1); # Cache current loop item.
			$prefix .= $char; # Gradually build prefix each char iteration.

			if (exists($char_bps{$char})) { last; } # Stop loop id breakpoint char is hit.

			# Prefix must be specific length to account for frequency.
			if (length($prefix) >= $min_frqz_prefix_len) {
				# If prefix not found in table add to table.
				if (!exists($frqz{$prefix})) { $frqz{$prefix} = 0; }
				$frqz{$prefix}++; # Increment frequency.

				# Track prefix's string index to later filter out items from array.
				if (!exists($indices{$prefix})) { $indices{$prefix} = {}; }
				$indices{$prefix}{$i} = 1; # Add index to table

				# Track prefix's string index to later filter out items from array.
				if (!exists($aindices{$prefix})) { $aindices{$prefix} = []; }
				push(@{ $aindices{$prefix} }, $i);
			}
		}
	}

	my @aprefixes = (); # Contain prefixes in array to later check prefix-of-prefixes.
	my %tprefixes; # Contain prefixes in table for later quick lookups.

	# Note: For languages that don't keep hashes sorted the route would be
	# to use an array to sort keys.
	my @ofrqz = ();
	foreach my $key (keys %frqz) { push(@ofrqz, $key) }
	# Sort strings alphabetically.
	@ofrqz = sort { lc($a) cmp lc($b) } @ofrqz;

	# Loop over each prefix in the frequency table...
	loop1: foreach my $str (@ofrqz) {
		my $count = $frqz{$str}; # Get string frequency.
		# If prefix doesn't exist in table and its frequency is >= 2 continue...
		if (!exists($tprefixes{$str}) && $count >= 2) {
			# Get char at index: [https://stackoverflow.com/a/736621]
			my $prevkey = substr($str, 0, -1); # Remove (str - last char) if it exists.
			# The previous prefix frequency, else 0 if not existent.
			my $prevcount = exists($tprefixes{$prevkey}) ? $tprefixes{$prevkey} : 0;

			# If last entry has a greater count skip this iteration.
			if ($prevcount > $count) { next; }

			# If any string in array is prefix of the current string, skip string.
			my $l = scalar(@aprefixes);
			if ($l) {
				# var has_existing_prefix = false;
				for (my $i = 0; $i < $l; $i++) {
					my $prefix = $aprefixes[$i]; # Cache current loop item.

					# If array string prefixes the string, continue to main loop.
					if (rindex($str, $prefix, 0) == 0 && $tprefixes{$prefix} > $count) {
						# has_existing_prefix = true;
						next loop1; # [https://stackoverflow.com/a/3087446]
					}
				}
				# if (has_existing_prefix) next;
			}

			# When previous count exists remove the preceding prefix from array/table.
			if ($prevcount) {
				pop(@aprefixes);
				delete $tprefixes{$prevkey}; # [https://stackoverflow.com/a/18480144]
			}

			# Finally, add current string to array/table.
			push(@aprefixes, $str);
			$tprefixes{$str} = $count;
		}
	}

	# Filter prefixes based on prefix length and prefix frequency count.
	for my $prefix (@aprefixes) {
		if (length($prefix) > $min_prefix_len && $tprefixes{$prefix} >= $min_frqz_count) {
			# Reset internal iterator so prior iteration doesn't affect loop.
			keys %{ $indices{$prefix} }; # [https://stackoverflow.com/a/3360]
			while(my($k, $v) = each %{ $indices{$prefix} }) {
				# Add indices to final table.
				$xids{$k} = ($aindices{$prefix}[0] == $k ? 0 : $v);
			}
			push(@prxs, __decorate($prefix, $prepend, $append)); # Add prefix to final array.
		}
	}

	my %r = (prefixes => \@prxs, indices => \%xids);
	return \%r;
}

my $res;
my @strs = ();

@strs = (
	"Call Mike and schedule meeting.",
	"Call Lisa",
	# "Cat",
	"Call Adam and ask for quote.",
	"Implement new class for iPhone project",
	"Implement new class for Rails controller",
	"Buy groceries"
	# "Buy groceries"
);
$res = __lcp(\@strs); # Run function.
print "13\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("--hintUser=", "--hintUser=", "--hintUser=");
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "-1\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--app=",
	"--assertions=",
	"--boundChecks=",
	"--checks=",
	"--cincludes=",
	"--clib=",
	"--clibdir=",
	"--colors=",
	"--compileOnly=",
	"--cppCompileToNamespace=",
	"--cpu=",
	"--debugger=",
	"--debuginfo=",
	"--define=",
	"--docInternal ",
	"--docSeeSrcUrl=",
	"--dynlibOverride=",
	"--dynlibOverrideAll ",
	"--embedsrc=",
	"--errorMax=",
	"--excessiveStackTrace=",
	"--excludePath=",
	"--expandMacro=",
	"--experimental=",
	"--fieldChecks=",
	"--floatChecks=",
	"--forceBuild=",
	"--fullhelp ",
	"--gc=",
	"--genDeps=",
	"--genScript=",
	"--help ",
	"--hintCC=",
	"--hintCodeBegin=",
	"--hintCodeEnd=",
	"--hintCondTrue=",
	"--hintConf=",
	"--hintConvFromXtoItselfNotNeeded=",
	"--hintConvToBaseNotNeeded=",
	"--hintDependency=",
	"--hintExec=",
	"--hintExprAlwaysX=",
	"--hintExtendedContext=",
	"--hintGCStats=",
	"--hintGlobalVar=",
	"--hintLineTooLong=",
	"--hintLink=",
	"--hintName=",
	"--hintPath=",
	"--hintPattern=",
	"--hintPerformance=",
	"--hintProcessing=",
	"--hintQuitCalled=",
	"--hints=",
	"--hintSource=",
	"--hintStackTrace=",
	"--hintSuccess=",
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw=",
	"--hintXDeclaredButNotUsed=",
	"--hotCodeReloading=",
	"--implicitStatic=",
	"--import=",
	"--include=",
	"--incremental=",
	"--index=",
	"--infChecks=",
	"--laxStrings=",
	"--legacy=",
	"--lib=",
	"--lineDir=",
	"--lineTrace=",
	"--listCmd ",
	"--listFullPaths=",
	"--memTracker=",
	"--multimethods=",
	"--nanChecks=",
	"--newruntime ",
	"--nilChecks=",
	"--nilseqs=",
	"--NimblePath=",
	"--nimcache=",
	"--noCppExceptions ",
	"--noLinking=",
	"--noMain=",
	"--noNimblePath ",
	"--objChecks=",
	"--oldast=",
	"--oldNewlines=",
	"--opt=",
	"--os=",
	"--out=",
	"--outdir=",
	"--overflowChecks=",
	"--parallelBuild=",
	"--passC=",
	"--passL=",
	"--path=",
	"--profiler=",
	"--project ",
	"--putenv=",
	"--rangeChecks=",
	"--refChecks=",
	"--run ",
	"--showAllMismatches=",
	"--skipCfg=",
	"--skipParentCfg=",
	"--skipProjCfg=",
	"--skipUserCfg=",
	"--stackTrace=",
	"--stdout=",
	"--styleCheck=",
	"--taintMode=",
	"--threadanalysis=",
	"--threads=",
	"--tlsEmulation=",
	"--trmacros=",
	"--undef=",
	"--useVersion=",
	"--verbosity=",
	"--version ",
	"--warningCannotOpenFile=",
	"--warningConfigDeprecated=",
	"--warningDeprecated=",
	"--warningEachIdentIsTuple=",
	"--warningOctalEscape=",
	"--warnings=",
	"--warningSmallLshouldNotBeUsed=",
	"--warningUser="
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "1\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--app=",
	"--assertions=",
	"--boundChecks=",
	"--checks=",
	"--cincludes=",
	"--clib=",
	"--clibdir=",
	"--colors="
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "2\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--warningCannotOpenFile",
	"--warningConfigDeprecated",
	"--warningDeprecated",
	"--warningEachIdentIsTuple",
	"--warningOctalEscape",
	"--warnings",
	"--warningSmallLshouldNotBeUsed",
	"--warningUser"
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "3\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--skipCfg=",
	"--skipParentCfg=",
	"--skipProjCfg=",
	"--skipUserCfg="
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "4\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--hintCC=",
	"--hintCodeBegin=",
	"--hintCodeEnd=",
	"--hintCondTrue=",
	"--hintConf=",
	"--hintConvFromXtoItselfNotNeeded=",
	"--hintConvToBaseNotNeeded=",
	"--hintDependency=",
	"--hintExec=",
	"--hintExprAlwaysX=",
	"--hintExtendedContext=",
	"--hintGCStats=",
	"--hintGlobalVar=",
	"--hintLineTooLong=",
	"--hintLink=",
	"--hintName=",
	"--hintPath=",
	"--hintPattern=",
	"--hintPerformance=",
	"--hintProcessing=",
	"--hintQuitCalled=",
	"--hints=",
	"--hintSource=",
	"--hintStackTrace=",
	"--hintSuccess=",
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw="
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "5\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--warnings=",
	"--warningCannotOpenFile=",
	"--warningXonfigDeprecated=",
	"--warningPofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofgTest="
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "6\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("--warnings=", "--warningCannotOpenFile=");
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "7\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("--warnings=");
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "8\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--hintCC=",
	"--hintCodeBegin=",
	"--hintCodeEnd=",
	"--hintCondTrue=",
	"--hintConf=",
	"--hintConvFromXtoItselfNotNeeded=",
	"--hintConvToBaseNotNeeded=",
	"--hintDependency=",
	"--hintExec=",
	"--hintExprAlwaysX=",
	"--hintExtendedContext=",
	"--hintGCStats=",
	"--hintGlobalVar=",
	"--hintLineTooLong=",
	"--hintLink=",
	"--hintName=",
	"--hintPath=",
	"--hintPattern=",
	"--hintPerformance=",
	"--hintProcessing=",
	"--hintQuitCalled=",
	"--hints=",
	"--hintSource=",
	"--hintStackTrace=",
	"--hintSuccess=",
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw=",
	"--hintXDeclaredButNotUsed="
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "9\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("--hintCC=");
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "10\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("--hintUser=", "--hintUserRaw=", "--hintXDeclaredButNotUsed=");
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "11\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw=",
	"--hintXDeclaredButNotUsed="
);
$res = __lcp(\@strs, 2, 2, 3, 3, 0, "--", "...", ('=')); # Run function.
print "12\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = (
	"Call Mike and schedule meeting.",
	"Call Lisa",
	"Call Adam and ask for quote.",
	"Implement new class for iPhone project",
	"Implement new class for Rails controller",
	"Buy groceries"
);
$res = __lcp(\@strs); # Run function.
print "13\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("interspecies", "interstelar", "interstate");
$res = __lcp(\@strs); # Run function. # "inters"
print "14\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("throne", "throne");
$res = __lcp(\@strs); # Run function. # "throne"
print "15\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("throne", "dungeon");
$res = __lcp(\@strs); # Run function. # ""
print "16\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("cheese");
$res = __lcp(\@strs); # Run function. # "cheese"
print "17\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ();
$res = __lcp(\@strs); # Run function. # ""
print "18\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";

@strs = ("prefix", "suffix");
$res = __lcp(\@strs); # Run function. # ""
print "19\n";
# my @prefixes = @{ $res->{prefixes} }; # Get array ref and deference it.
# my %indices = %{ $res->{indices} }; # Get indices ref and deference it.
print Dumper($res) . "\n";
