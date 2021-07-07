#!/usr/bin/env ruby

def formatter(*args)
	tokens, text, branches, cchains, flags, settings, $s = args

	fmt = $s[:args][:fmt]
	igc = $s[:args][:igc]

	output = []
	r = "/^[ \t]+/g"

	ttypes = $s[:ttypes]
	ttids = $s[:ttids]
	dtids = $s[:dtids]

	# Indentation level multipliers.
	$MXP = {
		"tkCMT": 0,
		"tkCMD": 0,
		"tkFLG": 1,
		"tkFOPT": 2,
		"tkBRC": 0,
		"tkNL": 0,
		"tkSTN": 0,
		"tkVAR": 0,
		"tkBRC_RP": 1,
		"tkBRC_LP": 2
	}

	no_nl_cmt = Set["tkNL", "tkCMT"]

	$ichar, $iamount = fmt
	def indent(type_, count)
		return $ichar * ((count || $MXP[type_]) * $iamount)
	end

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

	def prevtoken(tid, skip=Set["tkNL"])
		for ttid in (tid - 1).downto(0)
			if !skip.include?($s[:lexerdata][:tokens][ttid][:kind])
				return ttid
			end
		end
		return -1
	end

	cleaned = []
	$branches.each { |branch|

		parentkind = branch[0][:kind]

		first_assignment = false
		level = 0

		brc_lp_count = 0
		group_open = false

		branch.each_with_index { |leaf,j|
			tid = leaf[:tid]
			kind = leaf[:kind]
			line = leaf[:line]

			## Settings / Variables

			if Set["tkSTN", "tkVAR"].include?(parentkind)
				if kind == "tkTRM"
					next
				end

				if tid != 0
					ptk = tokens[prevtoken(tid)]
					dline = line - ptk[:line]
					if Set["tkASG", "tkSTR", "tkAVAL"].include?(kind)
						if ptk[:kind] == "tkCMT"
							cleaned.append("\n")
							if dline > 1
								cleaned.append("\n")
							end
						end
						cleaned.append(" ")
					else
						if dline == 0
							cleaned.append(" ")
						elsif dline == 1
							cleaned.append("\n")
						else
							cleaned.append("\n\n")
						end
					end
				end

				cleaned.append(tkstr($s, leaf[:tid]))

			## Command chains

			elsif parentkind == "tkCMD"

				if tid != 0
					ptk = tokens[prevtoken(tid)]
					dline = line - ptk[:line]

					if dline == 1
						cleaned.append("\n")
					elsif dline > 1
						if !group_open
							cleaned.append("\n")
							cleaned.append("\n")
						end

						# [TODO] Add format settings to customize formatting.
						# For example, collapse newlines in flag scopes?
						# if level > 0
						# 	cleaned.pop()
						# end
					end
				end

				# When inside an indentation level or inside parenthesis,
				# append a space before every token to space things out.
				# However, because this is being done lazily, some token
				# conditions must be skipped. The skippable cases are when
				# a '$' precedes a string (""), i.e. a '$"command"'. Or
				# when an eq-sign precedes a '$', i.e. '=$("cmd")',
				if ((level || brc_lp_count == 1) &&
					Set["tkFVAL", "tkSTR", "tkDLS", "tkTBD"].include?(kind))
					ptk = tokens[prevtoken(tid, no_nl_cmt)]
					pkind = ptk[:kind]

					if (pkind != "tkBRC_LP" && cleaned[-1] != " " &&
						!((kind == "tkSTR" && pkind == "tkDLS") ||
						(kind == "tkDLS" && pkind == "tkASG")))
						cleaned.append(" ")
					end
				end

				if kind == "tkBRC_LC"
					group_open = true
					cleaned.append(tkstr($s, leaf[:tid]))

				elsif kind == "tkBRC_RC"
					group_open = false
					cleaned.append(tkstr($s, leaf[:tid]))

				elsif kind == "tkDCMA" and not first_assignment
					cleaned.append(tkstr($s, leaf[:tid]))
					# Append newline after group is cloased.
					# if not group_open: cleaned.append("\n")

				elsif kind == "tkASG" and not first_assignment
					first_assignment = true
					cleaned.append(" ")
					cleaned.append(tkstr($s, leaf[:tid]))
					cleaned.append(" ")

				elsif kind == "tkBRC_LB"
					cleaned.append(tkstr($s, leaf[:tid]))
					level = 1

				elsif kind == "tkBRC_RB"
					level = 0
					first_assignment = false
					cleaned.append(tkstr($s, leaf[:tid]))

				elsif kind == "tkFLG"
					if level
						cleaned.append(indent(kind, level))
					end
					cleaned.append(tkstr($s, leaf[:tid]))

				elsif kind == "tkKYW"
					if level
						cleaned.append(indent(kind, level))
					end
					cleaned.append(tkstr($s, leaf[:tid]))
					cleaned.append(" ")

				elsif kind == "tkFOPT"
					level = 2
					cleaned.append(indent(kind, level))
					cleaned.append(tkstr($s, leaf[:tid]))

				elsif kind == "tkBRC_LP"
					brc_lp_count += 1
					ptk = tokens[prevtoken(tid)]
					pkind = ptk[:kind]
					if !Set["tkDLS", "tkASG"].include?(pkind)
						scope_offset = pkind == "tkCMT" && 1 || 0
						cleaned.append(indent(kind, level + scope_offset))
					end
					cleaned.append(tkstr($s, leaf[:tid]))

				elsif kind == "tkBRC_RP"
					brc_lp_count -= 1
					if (level == 2 && brc_lp_count == 0 &&
						   branch[j - 1][:kind] != "tkBRC_LP")
						cleaned.append(indent(kind, level - 1))
						level = 1
					end
					cleaned.append(tkstr($s, leaf[:tid]))

				elsif kind == "tkCMT"
					ptk = tokens[prevtoken(leaf[:tid], Set[])][:kind]
					atk = tokens[prevtoken(tid)][:kind]
					if ptk == "tkNL"
						scope_offset = 0
						if atk == "tkASG"
							scope_offset = 1
						end
						cleaned.append(indent(kind, level + scope_offset))
					else
						cleaned.append(" ")
					end
					cleaned.append(tkstr($s, leaf[:tid]))

				else
					cleaned.append(tkstr($s, leaf[:tid]))
				end

			## Comments

			elsif parentkind == "tkCMT"

				if tid != 0
					ptk = tokens[prevtoken(tid)]
					dline = line - ptk[:line]

					if dline == 1
						cleaned.append("\n")
					else
						cleaned.append("\n")
						cleaned.append("\n")
					end
				end
				cleaned.append(tkstr($s, leaf[:tid]))

			else
				if kind != "tkTRM"
					cleaned.append(tkstr($s, leaf[:tid]))
				end
			end
		}
	}

	# Return empty values to maintain parity with acdef.py.

	acdef = ""
	config = ""
	defaults = ""
	filedirs = ""
	contexts = ""
	formatted = cleaned.join("") + "\n"
	oPlaceholders = {}
	tests = ""

	return acdef, config, defaults, filedirs, contexts, formatted, oPlaceholders, tests
end
