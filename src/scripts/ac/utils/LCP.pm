package LCP;

# use strict;
# use warnings;

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

package main;

1;
