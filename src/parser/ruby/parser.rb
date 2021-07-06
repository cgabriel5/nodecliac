#!/usr/bin/env ruby

require "set"

require "./lexer"
require "./defvars"
require "./validation"

R = /(?<!\\)\$\{\s*[^}]*\s*\}/

$s = {}
$ttid = 0
$next_ = []
$scope = []
$branch = []
$branches = []
$oneliner = -1

$chain = []
$cchains = []
$ubids = []
$flags = {}
$flag = {
	"tid": -1,
	"alias": -1,
	"boolean": -1,
	"assignment": -1,
	"multi": -1,
	"union_": -1,
	"values": []
}

$setting = []
$settings = []

$variable = []
$variables = []

$used_vars = {}
$user_vars = {}
$varstable = {}
$vindices = {}

def tkstr(s, tid)
	if tid == -1
		return ""
	end
	if s[:lexerdata][:tokens][tid][:kind] == "tkSTR"
		if s[:lexerdata][:tokens][tid].key?(:"$")
			return s[:lexerdata][:tokens][tid][:"$"]
		end
	end
	return s[:text][s[:lexerdata][:tokens][tid][:start] .. s[:lexerdata][:tokens][tid][:end]]
end

def err(tid, message, pos = "start", scope = "")
		# When token ID points to end-of-parsing token,
		# reset the id to the last true token before it.
		if $s[:lexerdata][:tokens][tid][:kind] == "tkEOP"
			tid = $s[:lexerdata][:ttids][-1]
		end

		token = $s[:lexerdata][:tokens][tid]
		line = token[:line]
		index = token[pos]
		# msg = message
		col = index - $s[:lexerdata][:linestarts][line]

		if message.end_with?(":")
			message += " '" + tkstr($s, tid) + "'"
		end

		# # Add token debug information.
		# dbeugmsg = "\n\n\033[1mToken\033[0m: "
		# dbeugmsg += "\n - tid: " + str(token["tid"])
		# dbeugmsg += "\n - kind: " + token["kind"]
		# dbeugmsg += "\n - line: " + str(token["line"])
		# dbeugmsg += "\n - start: " + str(token["start"])
		# dbeugmsg += "\n - end: " + str(token["end"])
		# dbeugmsg += "\n __val__: [" + tkstr(tid) + "]"

		# dbeugmsg += "\n\n\033[1mExpected\033[0m: "
		# for n in NEXT:
		#     if not n: n = "\"\""
		#     dbeugmsg += "\n - " + n
		# dbeugmsg += "\n\n\033[1mScopes\033[0m: "
		# for s in SCOPE:
		#     dbeugmsg += "\n - " + s
		# decor = "-" * 15
		# msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor
		# msg += dbeugmsg
		# msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor

		issue_error($s[:filename], line, col, message)
end

def warn(tid, message)
		token = $s[:lexerdata][:tokens][tid]
		line = token[:line]
		index = token[:start]
		col = index - $s[:lexerdata][:linestarts][line]

		if message.end_with?(":")
			message += " '" + tkstr($s, tid) + "'"
		end

		if !$s[:warnings].key?(line)
			$s[:warnings][line] = []
		end

		$s[:warnings][line].append([$s[:filename], line, col, message])
		$s[:warn_lines].add(line)
end

def hint(tid, message)
		token = $s[:lexerdata][:tokens][tid]
		line = token[:line]
		index = token[:start]
		col = index - $s[:lexerdata][:linestarts][line]

		if message.endswith(":")
			message += " '" + tkstr($s, tid) + "'"
		end

		issue_hint($s[:filename], line, col, message)
end

def addtoken(s, i)
	# Interpolate/track interpolation indices for string.
	if s[:lexerdata][:tokens][i][:kind] == "tkSTR"
		value = tkstr(s, i)
		s[:lexerdata][:tokens][i][:"$"] = value

		if s[:args][:action] != "format" && !vindices.include?(i)
			end_ = 0
			pointer = 0
			tmpstr = ""
			$vindices[i] = []

			# [https://stackoverflow.com/a/4274503]
			# [https://stackoverflow.com/a/5241843]
			# [https://stackoverflow.com/a/7846484]
			value.to_enum(:scan, R).map do |m,|
				start = $`.size
				end_ = $`.size + m.length - 1
				varname = value[start + 2 .. end_ - 1].strip

				if !$varstable.key?(varname)
					# Note: Modify token index to point to
					# start of the variable position.
					# $s.LexerData.Tokens[S.Tid].Start += start
					$s[:lexerdata][:tokens][$s[:tid]][:start] += start
					err($ttid, "Undefined variable", "start", "child")
				end

				$used_vars[varname.to_sym] = 1
				$vindices[i].append([start, end_])

				tmpstr += value[pointer .. start]
				sub = $varstable.fetch(varname.to_sym, "")
				if sub != ""
					if !(sub[0] == '"' || sub[1] == '\'')
						tmpstr += sub
					else
						# Unquote string if quoted.
						tmpstr += sub[1 .. sub.length() - 1]
					end
				end
				pointer = end_
			end

			# Get tail-end of string.
			tmpstr += value[end_ ..]
			$s[:lexerdata][:tokens][i][:"$"] = tmpstr

			if $vindices[i].length() == 0
				$vindices.delete(i)
			end
		end
	end

	$branches[-1].append($tokens[i])
end

def expect(*args)
	$next_.clear()
	args.each { |a| $next_.append(a) }
end

def clearscope()
	$scope.clear()
end

def addscope(s)
	$scope.append(s)
end

def popscope(pops = 1)
	while pops > 0
		$scope.pop()
		pops -= 1
	end
end

def hasscope(s)
	return $scope.include?(s)
end

def prevscope()
	return $scope[-1]
end

def hasnext(s)
	$next_.include?(s)
end

def nextany()
	return $next_[0] == ""
end

def addbranch()
	$branches.append($branch)
end

def newbranch()
	$branch = []
end

def prevtoken(s)
	return s[:lexerdata][:tokens][s[:lexerdata][:dtids][s[:tid]]]
end

# Command chain/flag grouping helpers.
# ================================

def newgroup()
  $chain = []
end

def addtoken_group(i)
	$chain.append(i)
end

def addgroup(g)
	$cchains.append([g])
end

def addtoprevgroup()
	$cchains[-1].append($chain)
end

# ============================

def newvaluegroup(prop)
	$flag[prop.to_sym].append([-1])
end

def setflagprop(prop, prev_val_group = false)
	index = $cchains.length() - 1
	if prop != "values"
		$flags[index][-1][prop.to_sym] = $s[:tid]
	else
		if !prev_val_group
			$flags[index][-1][prop.to_sym].append([$s[:tid]])
		else
			$flags[index][-1][prop.to_sym][-1].append($s[:tid])
		end
	end
end

def newflag()
	$flag = {
	"tid": -1,
	"alias": -1,
	"boolean": -1,
	"assignment": -1,
	"multi": -1,
	"union_": -1,
	"values": []
	}
	index = $cchains.length() - 1
	if !$flags.include?(index)
		$flags[index] = []
	end
	$flags[index].append($flag)
	setflagprop("tid")
end

# Setting/variable grouping helpers.
# ================================

def newgroup_stn()
	$setting = []
end

def addtoken_stn_group(i)
	$setting.append(i)
end

def addgroup_stn(g)
	$settings.append(g)
end

# def addtoprevgroup_stn()
#   newgroup_stn()
#   $settings[-1].append($setting)
# end

# # ============================

def newgroup_var()
	$variable = []
end

def addtoken_var_group(i)
	$variable.append(i)
end

def addgroup_var(g)
	$variables.append(g)
end

# # void addtoprevgroup_var() {
# #     newgroup_var()
# #     VARIABLES.back().push_back(variable)
# # }

def parser(action, text, cmdname, source, fmtinfo, trace, igc, test)

	tokens, ttypes, ttids, dtids, linestarts = tokenizer(text)

	i = 0
	l = tokens.length()

	$s = {
		"tid": -1,
		"filename": source,
		"text": text,
		"args": {
			"action": action,
			"source": source,
			"fmt": fmtinfo,
			"trace": trace,
			"igc": igc,
			"test": test
		},
		"ubids": $ubids,
		"excludes": [],
		"warnings": {},
		"warn_lines": Set.new,
		"warn_lsort": Set.new,
		"lexerdata": {
			"linestarts": linestarts,
			"tokens": tokens,
			"ttypes": ttypes,
			"ttids": ttids,
			"dtids": dtids
		}
	}

	$varstable = builtins(cmdname)

	while i < l
		token = tokens[i]
		kind = token[:kind]
		line = token[:line]
		# start = token[:start]
		# end = token[:end]
		$s[:tid] = token[:tid]

		if kind == "tkNL"
			i += 1
			next
		end

		if kind != "tkEOP"
			$ttid = i
		end

		if kind == "tkTRM"
			if $scope.empty?
				addbranch()
				addtoken($s, $ttid)
				newbranch()
				expect("")
			else
				addtoken($s, $ttid)

				if !$next_.empty? && !nextany()
					err($ttid, "Improper termination", "start", "child")
				end
			end

			i += 1
			next
		end

		if $scope.empty?

			oneliner = -1

			if !$branches.empty?
				ltoken = $branches[-1][-1] # Last branch token.
				if line == ltoken[:line] && ltoken[:kind] != "tkTRM"
					err($ttid, "Improper termination", scope="parent")
				end
			end

			if kind != "tkEOP"
				addbranch()
				addtoken($s, $ttid)

				if Set["tkSTN", "tkVAR", "tkCMD"].include?(kind)
					addscope(kind)
					if kind == "tkSTN"
						newgroup_stn()
						addgroup_stn($setting)
						addtoken_stn_group($s[:tid])

						vsetting($s)
						expect("", "tkASG")
					elsif kind == "tkVAR"
						newgroup_var()
						addgroup_var($variable)
						addtoken_var_group($s[:tid])

						varname = tkstr($s, $s[:tid])[1..-1]
						$varstable[varname] = ""

						if !$user_vars.key?(varname)
							$user_vars[varname] = []
						end
						$user_vars[varname].append($s[:tid])

						vvariable($s)
						expect("", "tkASG")
					elsif kind == "tkCMD"
						addtoken_group($s[:tid])
						addgroup($chain)

						expect("", "tkDDOT", "tkASG", "tkDCMA")

						command = tkstr($s, $s[:tid])
						if command != "*" && command != cmdname
							warn($s[:tid], "Unexpected command:")
						end
					end
				else
					if kind == "tkCMT"
						newbranch()
						expect("")
					else # Handle unexpected parent tokens.
						err($s[:tid], "Unexpected token:", scope="parent")
					end
				end
			end

		else

			if kind == "tkCMT"
				addtoken($s, $ttid)
				i += 1
				next
			end

			# Remove/add necessary tokens when parsing long flag form.
			if hasscope("tkBRC_LB")
				if hasnext("tkDPPE")
					$next_.delete("tkDPPE")
					$next_.append("tkFLG")
					$next_.append("tkKYW")
					$next_.append("tkBRC_RB")
				end
			end

			if !$next_.empty? && !hasnext(kind)
				if nextany()
					clearscope()
					newbranch()

					newgroup()
					next

				else
					err($s[:tid], "Unexpected token:", scope="child")
				end
			end

			addtoken($s, $ttid)

			# Oneliners must be declared on oneline, else error.
			if $branches[-1][0][:kind] == "tkCMD" && (
				((hasscope("tkFLG") || hasscope("tkKYW")) ||
				Set["tkFLG", "tkKYW"].include?(kind)) &&
				!hasscope("tkBRC_LB"))
				if oneliner == -1
					oneliner = token[:line]
				elsif token[:line] != oneliner
					err($s[:tid], "Improper oneliner", scope="child")
				end
			end

			case prevscope()
			when "tkSTN"
				case kind
				when "tkASG"
					addtoken_stn_group($s[:tid])

					expect("tkSTR", "tkAVAL")
				when "tkSTR"
					addtoken_stn_group($s[:tid])

					expect("")

					vstring($s)
				when "tkAVAL"
					addtoken_stn_group($s[:tid])

					expect("")

					vsetting_aval($s)
				end
			when "tkVAR"
				case kind
				when "tkASG"
					addtoken_var_group($s[:tid])

					expect("tkSTR")
				when "tkSTR"
					addtoken_var_group($s[:tid])
					$varstable[tkstr($s, $branches[-1][-3][:tid])[1..-1]] = tkstr($s, $s[:tid])

					expect("")

					vstring($s)
				end
			when "tkCMD"
				case kind
				when "tkASG"
					# If a universal block, store group id.
					if $s[:lexerdata][:dtids].key?($s[:tid])
						prevtk = prevtoken($s)
						if prevtk[:kind] == "tkCMD" and $s[:text][prevtk[:start]] == "*"
							$s[:ubids].append($cchains.length - 1)
						end
					end
					expect("tkBRC_LB", "tkFLG", "tkKYW")
				when "tkBRC_LB"
					addscope(kind)
					expect("tkFLG", "tkKYW", "tkBRC_RB")
				# # [TODO] Pathway needed?
				# when "tkBRC_RB":
				# 	expect("", "tkCMD")
				when "tkFLG"
					newflag()

					addscope(kind)
					expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB")
				when "tkKYW"
					newflag()

					addscope(kind)
					expect("tkSTR", "tkDLS")
				when "tkDDOT"
					expect("tkCMD", "tkBRC_LC")
				when "tkCMD"
					addtoken_group($s[:tid])

					expect("", "tkDDOT", "tkASG", "tkDCMA")
				when "tkBRC_LC"
					addtoken_group(-1)

					addscope(kind)
					expect("tkCMD")
				when "tkDCMA"
					# If a universal block, store group id.
					if $s[:lexerdata][:dtids].key?($s[:tid])
						prevtk = prevtoken($s)
						if prevtk[:kind] == "tkCMD" and $s[:text][prevtk[:start]] == "*"
							$s[:ubids].append($cchains.length - 1)
						end
					end

					addtoprevgroup()

					addscope(kind)
					expect("tkCMD")
				end

			when "tkBRC_LC"
				case kind
				when "tkCMD"
					addtoken_group($s[:tid])

					expect("tkDCMA", "tkBRC_RC")
				when "tkDCMA"
					expect("tkCMD")
				when "tkBRC_RC"
					addtoken_group(-1)

					popscope(1)
					expect("", "tkDDOT", "tkASG", "tkDCMA")
				end

			when "tkFLG"
				case kind
				when "tkDCLN"
					if prevtoken($s)[:kind] != "tkDCLN"
						expect("tkDCLN")
					else
						expect("tkFLGA")
					end
				when "tkFLGA"
					setflagprop("alias", false)

					expect("", "tkASG", "tkQMK", "tkDPPE")
				when "tkQMK"
					setflagprop("boolean", false)

					expect("", "tkDPPE")
				when "tkASG"
					setflagprop("assignment", false)

					expect("", "tkDCMA", "tkMTL", "tkDPPE", "tkBRC_LP",
						"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB")
				when "tkDCMA"
					setflagprop("union", false)

					expect("tkFLG", "tkKYW")
				when "tkMTL"
					setflagprop("multi", false)

					expect("", "tkBRC_LP", "tkDPPE")
				when "tkDLS"
					addscope(kind) # Build cmd-string.
					expect("tkBRC_LP")
				when "tkBRC_LP"
					addscope(kind)
					expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP")
				when "tkFLG"
					newflag()

					if hasscope("tkBRC_LB") && token[:line] == prevtoken($s)[:line]
						err($s[:tid], "Flag same line (nth)", "start", "child")
					end
					expect("", "tkASG", "tkQMK",
						"tkDCLN", "tkFVAL", "tkDPPE")
				when "tkKYW"
					newflag()

					# [TODO] Investigate why leaving flag scope doesn't affect
					# parsing. For now remove it to keep scopes array clean.
					popscope(1)

					if hasscope("tkBRC_LB") && token[:line] == prevtoken($s)[:line]
						err($s[:tid], "Keyword same line (nth)", "start", "child")
					end
					addscope(kind)
					expect("tkSTR", "tkDLS")
				when "tkSTR"
					setflagprop("values", false)

					expect("", "tkDPPE")
				when "tkFVAL"
					setflagprop("values", false)

					expect("", "tkDPPE")
				when "tkDPPE"
					expect("tkFLG", "tkKYW")
				when "tkBRC_RB"
					popscope(1)
					expect("")

				end

			when "tkBRC_LP"
				case kind
				when "tkFOPT"
					prevtk = prevtoken($s)
					if prevtk[:kind] == "tkBRC_LP"
						if prevtk[:line] == line
							err($s[:tid], "Option same line (first)", "start", "child")
						end
						addscope("tkOPTS")
						expect("tkFVAL", "tkSTR", "tkDLS")
					end
				when "tkFVAL"
					setflagprop("values", false)

					expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")
				# # Disable pathway for now.
				# when "tkTBD":
				# 	setflagprop("values", false)

				# 	expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")
				when "tkSTR"
					setflagprop("values", false)

					expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")
				when "tkDLS"
					addscope(kind)
					expect("tkBRC_LP")
				# # [TODO] Pathway needed?
				# when "tkDCMA":
				# 	expect("tkFVAL", "tkSTR")
				when "tkBRC_RP"
					popscope(1)
					expect("", "tkDPPE")

					prevtk = prevtoken($s)
					if prevtk[:kind] == "tkBRC_LP"
						warn(prevtk[:tid], "Empty scope (flag)")
					end
					# # [TODO] Pathway needed?
					# when "tkBRC_RB":
					# 	popscope(1)
					# 	expect("")
				end

			when "tkDLS"
				case kind
				when "tkBRC_LP"
					newvaluegroup("values")
					setflagprop("values", true)

					expect("tkSTR")
				when "tkDLS"
					expect("tkSTR")
				when "tkSTR"
					expect("tkDCMA", "tkBRC_RP")
				when "tkDCMA"
					expect("tkSTR", "tkDLS")
				when "tkBRC_RP"
					popscope(1)

					setflagprop("values", true)

					# Handle: 'program = --flag=$("cmd")'
					# Handle: 'program = default $("cmd")'
					if Set["tkFLG", "tkKYW"].include?(prevscope())
						if hasscope("tkBRC_LB")
							popscope(1)
							expect("tkFLG", "tkKYW", "tkBRC_RB")
						else
							# Handle: oneliner command-string
							# 'program = --flag|default $("cmd", $"c", "c")'
							# 'program = --flag::f=(1 3)|default $("cmd")|--flag'
							# 'program = --flag::f=(1 3)|default $("cmd")|--flag'
							# 'program = default $("cmd")|--flag::f=(1 3)'
							# 'program = default $("cmd")|--flag::f=(1 3)|default $("cmd")'
							expect("", "tkDPPE", "tkFLG", "tkKYW")
						end

						# Handle: 'program = --flag=(1 2 3 $("c") 4)'
					elsif prevscope() == "tkBRC_LP"
						expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP")

						# Handle: long-form
						# 'program = [
						# 	--flag=(
						# 		- 1
						# 		- $("cmd")
						# 		- true
						# 	)
						# ]'
					elsif prevscope() == "tkOPTS"
						expect("tkFOPT", "tkBRC_RP")
					end
				end

			when "tkOPTS"
				case kind
				when "tkFOPT"
					if prevtoken($s)[:line] == line
						err($s[:tid], "Option same line (nth)", "start", "child")
					end
					expect("tkFVAL", "tkSTR", "tkDLS")
				when "tkDLS"
					addscope("tkDLS") # Build cmd-string.
					expect("tkBRC_LP")
				when "tkFVAL"
					setflagprop("values", false)

					expect("tkFOPT", "tkBRC_RP")
				when "tkSTR"
					setflagprop("values", false)

					expect("tkFOPT", "tkBRC_RP")
				when "tkBRC_RP"
					popscope(2)
					expect("tkFLG", "tkKYW", "tkBRC_RB")
				end

			when "tkBRC_LB"
				case kind
				when "tkFLG"
					newflag()

					if hasscope("tkBRC_LB") && token[:line] == prevtoken($s)[:line]
						err($s[:tid], "Flag same line (first)", "start", "child")
					end
					addscope(kind)
					expect("tkASG", "tkQMK", "tkDCLN",
						"tkFVAL", "tkDPPE", "tkBRC_RB")
				when "tkKYW"
					newflag()


					if hasscope("tkBRC_LB") && token[:line] == prevtoken($s)[:line]
						err($s[:tid], "Keyword same line (first)", "start", "child")
					end
					addscope(kind)
					expect("tkSTR", "tkDLS", "tkBRC_RB")
				when "tkBRC_RB"
					popscope(1)
					expect("")

					prevtk = prevtoken($s)
					if prevtk[:kind] == "tkBRC_LB"
						warn(prevtk[:tid], "Empty scope (command)")
					end
				end

			when "tkKYW"
				case kind
				when "tkSTR"
					setflagprop("values", false)

					# Collect exclude values for use upstream.
					if $s[:lexerdata][:dtids].key?($s[:tid])
						prevtk = prevtoken($s)
						if (prevtk[:kind] == "tkKYW" and
							tkstr($s, prevtk[:tid]) == "exclude")
							excl_values = tkstr($s, $s[:tid])[1..-1].strip().split(";")
							# for exclude in excl_values: $s[:excludes].append(exclude)
							excl_values.each { |exclude|
								$s[:excludes].append(exclude)
							}
						end
					end

					# [TODO] This pathway re-uses the flag (tkFLG) token
					# pathways. If the keyword syntax were to change
					# this will need to change as it might no loner work.
					popscope(1)
					addscope("tkFLG") # Re-use flag pathways for now.
					expect("", "tkDPPE")
				when "tkDLS"
					addscope(kind) # Build cmd-string.
					expect("tkBRC_LP")
				# # [TODO] Pathway needed?
				# when "tkBRC_RB":
				# 	popscope(1)
				# 	expect("")
				# # [TODO] Pathway needed?
				# when "tkFLG":
				# 	expect("tkASG", "tkQMK"
				# 		"tkDCLN", "tkFVAL", "tkDPPE")
				# # [TODO] Pathway needed?
				# when "tkKYW":
				# 	addscope(kind)
				# 	expect("tkSTR", "tkDLS")
				when "tkDPPE"
					# [TODO] Because the flag (tkFLG) token pathways are
					# reused for the keyword (tkKYW) pathways, the scope
					# needs to be removed. This is fine for now but when
					# the keyword token pathway change, the keyword
					# pathways will need to be fleshed out in the future.
					if prevscope() == "tkKYW"
						popscope(1)
						addscope("tkFLG") # Re-use flag pathways for now.
					end
					expect("tkFLG", "tkKYW")
				end

			when "tkDCMA"
				case kind
				when "tkCMD"
					addtoken_group($s[:tid])

					popscope(1)
					expect("", "tkDDOT", "tkASG", "tkDCMA")

					command = tkstr($s, $s[:tid])
					if command != "*" && command != cmdname
						warn($s[:tid], "Unexpected command:")
					end
				end

			else
				err($s[:lexerdata][:tokens][$s[:tid]].tid, "Unexpected token:", "end", "")
			end

		end

		i += 1
	end

	# Check for any unused variables and give warning.
	$user_vars.each { |uservar, value|
		if !$used_vars.key?(uservar)
			$user_vars[uservar].each { |tid|
				warn(tid, "Unused variable: '" + uservar + "'")
				$s[:warn_lsort].add($s[:lexerdata][:tokens][tid][:line])
			}
		end
	}

	# Sort warning lines and print issues.
	warnlines = $s[:warn_lines].to_a
	warnlines.sort!
	warnlines.each { |warnline|
		# Only sort lines where unused variable warning(s) were added.
		if $s[:warn_lsort].include?(warnline) && $s[:warnings][warnline].length() > 1
			$s[:warnings][warnline].sort_by! { |w| w[2] }
		end
		$s[:warnings][warnline].each { |warning|
			issue_warn(*warning)
		}
	}
end
