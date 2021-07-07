#!/usr/bin/env ruby

require "digest/md5"
require "date"

def acdef(*args)
	branches, cchains, flags, settings, $s, cmdname = args

	$ubids = $s[:ubids]
	$text = $s[:text]
	$tokens = $s[:tokens]
	$excludes = $s[:excludes]

	$oSets = {}
	$oDefaults = {}
	$oFiledirs = {}
	$oContexts = {}

	$oSettings = {} # OrderedDict()
	$settings_count = 0
	$oTests = []
	$oPlaceholders = {}
	$omd5Hashes = {}
	$acdef = ""
	$acdef_lines = []
	$config = ""
	$defaults = ""
	$filedirs = ""
	$contexts = ""
	$has_root = false

	# Collect all universal block flags.
	$ubflags = []
	$ubids.each { |ubid|
		flags[ubid].each { |flg|
			$ubflags.append(flg)
		}
	}
	$oKeywords = [$oDefaults, $oFiledirs, $oContexts]

	# Escape '+' chars in commands. [https://stackoverflow.com/a/678242]
	rcmdname = cmdname.sub(/\+/, "\\+")
	# [https://stackoverflow.com/a/9918263]
	$r = /^(#{rcmdname}|[-_a-zA-Z0-9]+)/

	$re_space = /\s/
	$re_space_cl = /;\s+/

	# [https://prathamesh.tech/2020/03/02/converting-timestamps-to-ruby-objects/]
	# [https://stackoverflow.com/a/2944577]
	# [https://stackoverflow.com/a/21468633]
	date = Time.now
	timestamp = date.to_i
	datestring = date.strftime("%a %b %-d %Y %H:%M:%S")
	ctime = datestring + " (" + timestamp.to_s + ")"
	header = "# DON'T EDIT FILE —— GENERATED: " + ctime + "\n\n"
	if $s[:args][:test]
		header = ""
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

	def aobj(s)
		return { "val": s.downcase() }
	end

	def asort(a, b)
		if a[:val] != b[:val]
			if a[:val] < b[:val]
				result = -1
			else
				result = 1
			end
		else
			result = 0
		end

		if result == 0 and a.fetch(:single, false) and b.fetch(:single, false)
			if a[:orig] < b[:orig]
				result = 1
			else
				result = 0
			end
		end
		return result
	end

	# compare function: Gives precedence to flags ending with '=*' else
	#     falls back to sorting alphabetically.
	#
	# @param  {string} a - Item a.
	# @param  {string} b - Item b.
	# @return {number} - Sort result.
	#
	# Give multi-flags higher sorting precedence:
	# @resource [https://stackoverflow.com/a/9604891]
	# @resource [https://stackoverflow.com/a/24292023]
	# @resource [http://www.javascripttutorial.net/javascript-array-sort/]
	# let sort = (a, b) => ~~b.endsWith("=*") - ~~a.endsWith("=*") || asort(a, b)
	def fsort(a, b)
		result = b[:m] - a[:m]
		if result == 0
			result = asort(a, b)
		end
		return result
	end

	def fobj(s)
		o = { "val": s.downcase(), "m": s.end_with?("=*") && 1 || 0 }
		if s[1] != '-'
			o[:orig] = s
			o[:single] = true
		end
		return o
	end

	# Uses map sorting to reduce redundant preprocessing on array items.
	#
	# @param  {array} A - The source array.
	# @param  {function} comp - The comparator function to use.
	# @return {array} - The resulted sorted array.
	#
	# @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
	def mapsort(a, comp, comp_obj)
		t = [] # Temp array.
		# [https://stackoverflow.com/a/10712044]
		r = [] # Result array.
		a.each_with_index { |a_, i|
			# [https://dev.to/halented/passing-functions-as-arguments-in-ruby-5b5i]
			obj = method(comp_obj).call(a_)
			obj[:i] = i
			t.append(obj)
		}
		# [https://stackoverflow.com/a/44505668]
		t.sort! do |a,b|
			method(comp).call(a, b)
		end
		t.each_with_index { |val, i|
			r[i] = a[val[:i]]
		}
		return r
	end

	# Removes first command in command chain. However, when command name
	# is not the main command in (i.e. in a test file) just remove the
	# first command name in the chain.
	#
	# @param  {string} command - The command chain.
	# @return {string} - Modified chain.
	def rm_fcmd(chain)
		return chain.to_s.sub($r, "")
	end

	def get_cmdstr(start, stop)
		output = []
		allowed_tk_types = Set["tkSTR", "tkDLS"]
		for tid in start..stop
			if allowed_tk_types.include?($s[:lexerdata][:tokens][tid][:kind].to_s)
				if output && output[-1] == "$"
					output[-1] = "$" + tkstr($s, tid)
				else
					output.append(tkstr($s, tid))
				end
			end
		end

		return "$(" + output.join(",") + ")"
	end

	def processflags(gid, chain, flags, queue_flags, recunion=false, recalias=false)
		unions = []
		flags.each { |flg|
			tid = flg[:tid]
			assignment = tkstr($s, flg[:assignment])
			boolean = tkstr($s, flg[:boolean])
			alias_ = tkstr($s, flg[:alias])
			flag = tkstr($s, tid)
			ismulti = tkstr($s, flg[:multi])
			union = flg[:union] != -1
			values = flg[:values]
			kind = $s[:lexerdata][:tokens][tid][:kind]

			if !alias_.empty? && !recalias
				processflags(gid, chain, [flg], queue_flags, false, true)
			end

			# Skip union logic on recursion.
			if !recalias && kind != "tkKYW" && !recunion
				if union
					unions.append(flg)
					next
				elsif unions
					unions.each { |uflg|
						uflg[:values] = values
						processflags(gid, chain, [uflg], queue_flags, true, false)
					}
					unions.clear()
				end
			end

			if recalias
				$oContexts[chain]["{" + flag.sub(/^-*/, "") + "|" + alias_ + "}"] = 1
				flag = "-" + alias_
			end

			if kind == "tkKYW"
				if !values.empty? && flag != "exclude"
					if values[0].length() == 1
						value = tkstr($s, values[0][0]).sub($re_space, "")
						if flag == "context"
							value = value[1..-1]
						end
					else
						value = get_cmdstr(values[0][1] + 1, values[0][2])
					end

					# [https://stackoverflow.com/a/30840502]
					# vname = "o#{flag.capitalize()}s"
					# binding.local_variable_get(vname)[chain][value] = 1

					if flag == "default"
						$oDefaults[chain][value] = 1
					elsif flag == "context"
						$oContexts[chain][value] = 1
					elsif flag == "filedir"
						$oFiledirs[chain][value] = 1
					end
				end
				next
			end

			# Flag with values: build each flag + value.
			if !values.empty?
				# Baseflag: add multi-flag indicator?
				# Add base flag to Set (adds '--flag=' or '--flag=*').
				queue_flags["#{flag}=#{!ismulti.empty? ? '*' : ''}"] = 1
				mflag = "#{flag}=#{!ismulti.empty? ? '' : '*'}"
				if queue_flags.key?(mflag.to_sym)
					queue_flags.delete(mflag.to_sym)
				end

				values.each { |value|
					if value.length() == 1 # Single
						queue_flags[flag + assignment + tkstr($s, value[0])] = 1

					else # Command-string
						cmdstr = get_cmdstr(value[1] + 1, value[2])
						queue_flags[flag + assignment + cmdstr] = 1
					end
				}
			else

				if ismulti.empty?
					if !boolean.empty?
						queue_flags[flag + "?"] = 1
					elsif !assignment.empty?
						queue_flags[flag + "="] = 1
					else
						queue_flags[flag] = 1
					end
				else
					queue_flags[flag + "=*"] = 1
					queue_flags[flag + "="] = 1
				end

			end
		}
	end

	def populate_keywords(chain)
		$oKeywords.each { |kdict|
			if !kdict.key?(chain.to_sym)
				kdict[chain] = {}
			end
		}
	end

	def populate_chain_flags(gid, chain, container)
		if !$excludes.include?(chain)
			processflags(gid, chain, $ubflags, container, false, false)
		end

		if !$oSets.key?(chain.to_sym)
			$oSets[chain.to_sym] = container
		else
			$oSets[chain.to_sym].merge!(container)
		end
	end

	def build_kwstr(kwtype, container)
		output = []

		chains = []
		container.each { |key, value|
			if !value.empty?
				chains.append(key)
			end
		}
		chains = mapsort(chains, :asort, :aobj)

		cl = chains.length() - 1
		chains.each_with_index { |chain, i|
			values = container[chain].keys
			value = kwtype != "context" ? values[-1] : "\"" + values.join(";") + "\""
			output.append(rm_fcmd(chain) + " " + kwtype + " " + value)
			if i < cl
				output.append("\n")
			end
		}

		return !output.empty? ? "\n\n" + output.join("") : ""
	end

	def make_chains(ccids)
		slots = []
		chains = []
		groups = []
		grouping = false

		ccids.each { |cid|
			if cid == -1
				grouping = !grouping
			end

			if !grouping && cid != -1
				slots.append(tkstr($s, cid))
			elsif grouping
				if cid == -1
					slots.append('?')
					groups.append([])
				else
					groups[-1].append(tkstr($s, cid))
				end
			end
		}

		tstr = slots.join(".")

		groups.each { |group|
			if chains.empty?
				group.each { |command|
					chains.append(tstr.sub('?', command))
				}
			else
				tmp_cmds = []
				chains.each { |chain|
					group.each { |command|
						tmp_cmds.append(chain.sub('?', command))
					}
				}
				chains = tmp_cmds
			end
		}

		if groups.empty?
			chains.append(tstr)
		end

		return chains
	end

	# Start building acmap contents. -------------------------------------------

	cchains.each_with_index { |group, i|
		group.each { |ccids|
			make_chains(ccids).each { |chain|
				if chain == "*"
					next
				end

				container = {}
				populate_keywords(chain)
				processflags(i, chain, flags.fetch(i, []), container, false, false)
				populate_chain_flags(i, chain, container)

				# Create missing parent chains.
				commands = chain.split(/(?<!\\)\./)
				commands.pop() # Remove last command (already made).
				for j in (commands.length() - 1).downto(0)
					rchain = commands.join(".") # Remainder chain.

					populate_keywords(rchain)
					if !$oSets.key?(rchain.to_sym)
						populate_chain_flags(i, rchain, {})
					end

					commands.pop() # Remove last command.
				end
			}
		}
	}

	$defaults = build_kwstr("default", $oDefaults)
	$filedirs = build_kwstr("filedir", $oFiledirs)
	$contexts = build_kwstr("context", $oContexts)

	# Populate settings object.
	settings.each { |setting|
		name = tkstr($s, setting[0])[1..]
		if name == "test"
			$oTests.append(tkstr($s, setting[2]).sub(re_space_cl, ";"))
		else
			$oSettings[name] = setting.length() > 1 ? tkstr($s, setting[2]) : ""
		end
	}

	# Build settings contents.
	settings_count = $oSettings.length()
	settings_count -= 1
	$oSettings.each { |setting|
		$config += "@#{setting} = #{$oSettings[setting]}"
		if settings_count
			$config += "\n"
		end
		settings_count -= 1
	}

	placehold = $oSettings.key?(:placehold) && $oSettings[:placehold] == "true"
	placehold = true
	$oSets.each { |key, value|
		flags = mapsort($oSets[key].keys, :fsort, :fobj).join("|")
		if flags.empty?
			flags = "--"
		end

		# Note: Placehold long flag sets to reduce the file's chars.
		# When flag set is needed its placeholder file can be read.
		if placehold && flags.length() >= 100
			if !$omd5Hashes.key?(flags)
				# [https://www.ruby-forum.com/t/md5-checksum-of-a-string/190612]
				# [https://www.informit.com/articles/article.aspx?p=683059&seqNum=35]
				md5hash = Digest::MD5.hexdigest(flags)[26..]
				$oPlaceholders[md5hash] = flags
				$omd5Hashes[flags] = md5hash
				flags = "--p#" + md5hash
			else
				flags = "--p#" + $omd5Hashes[flags]
			end
		end

		row = "#{rm_fcmd(key)} #{flags}"

		# Remove multiple ' --' command chains. Shouldn't be the
		# case but happens when multiple main commands are used.
		if row == " --" && !$has_root
			$has_root = true
		elsif row == " --" && $has_root
			continue
		end

		$acdef_lines.append(row)
	}

	# If contents exist, add newline after header.
	sheader = header.sub("\n$", "")
	acdef_contents = mapsort($acdef_lines, :asort, :aobj).join("\n")
	$acdef = !acdef_contents.empty? ? header + acdef_contents : sheader
	$config = !$config.empty? ? header + $config : sheader

	tests = ""
	if !$oTests.empty?
		tests = "#!/bin/bash\n\n" + header + "tests=(\n" + $oTests.join("\n") + "\n)"
	end

	formatted = ""
	return $acdef, $config, $defaults, $filedirs, $contexts, formatted, $oPlaceholders, tests

end
