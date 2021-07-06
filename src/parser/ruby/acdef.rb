#!/usr/bin/env ruby

require "date"

def acdef(branches, cchains, flags, settings, s, cmdname)

	ubids = s[:ubids]
	text = s[:text]
	tokens = s[:tokens]
	excludes = s[:excludes]

	oSets = {}
	oDefaults = {}
	oFiledirs = {}
	oContexts = {}

	oSettings = {} # OrderedDict()
	settings_count = 0
	oTests = []
	oPlaceholders = {}
	omd5Hashes = {}
	acdef = ""
	acdef_lines = []
	config = ""
	defaults = ""
	filedirs = ""
	contexts = ""
	has_root = false

	# Collect all universal block flags.
	ubflags = []
	ubids.each { |ubid|
		flags[ubid].each { |flg|
			ubflags.append(flg)
		}
	}
	oKeywords = [oDefaults, oFiledirs, oContexts]

	p ubflags.length()

	# Escape '+' chars in commands. [https://stackoverflow.com/a/678242]
	rcmdname = cmdname.sub(/\+/, "\\+")
	# [https://stackoverflow.com/a/9918263]
	r = /^(#{rcmdname}|[-_a-zA-Z0-9]+)/

	re_space = /\s/
	re_space_cl = /;\s+/

	# [https://prathamesh.tech/2020/03/02/converting-timestamps-to-ruby-objects/]
	# [https://stackoverflow.com/a/2944577]
	# [https://stackoverflow.com/a/21468633]
	date = Time.now
	timestamp = date.to_i
	datestring = date.strftime("%a %b %-d %Y %H:%M:%S")
	ctime = datestring + " (" + timestamp.to_s + ")"
	header = "# DON'T EDIT FILE —— GENERATED: " + ctime + "\n\n"
	if s[:args][:test]
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
		o = { "val": s.downcase(), "m": s.ends_with("=*") && 1 || 0 }
		if s[1] != '-'
			o[:orig] = s
			o[:single] = true
		end
		return o
	end

	# # Uses map sorting to reduce redundant preprocessing on array items.
	# #
	# # @param  {array} A - The source array.
	# # @param  {function} comp - The comparator function to use.
	# # @return {array} - The resulted sorted array.
	# #
	# # @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
	def mapsort(a, comp, comp_obj)
		t = [] # Temp array.
		# [https://stackoverflow.com/a/10712044]
		r = [] # Result array.
		a.each_with_index { |a_, i|
			obj = comp_obj(a_)
			obj[:i] = i
			t.append(obj)
		}
		# [https://stackoverflow.com/a/46320068]
		# t.sort(key=functools.cmp_to_key(comp))
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
		return chain.sub(r, "")
	end

	def get_cmdstr(start, stop)
		output = []
		allowed_tk_types = Set["tkSTR", "tkDLS"]
		for tid in start..stop
			if allowed_tk_types?include(s[:tokens][tid][:kind])
				if output && output[-1] == "$"
					output[-1] = "$" + tkstr(s, tid)
				else
					output.append(tkstr(s, tid))
				end
			end
		end

		return "$(" + output.join(",") + ")"
	end

	# def processflags(gid, chain, flags, queue_flags, recunion=False, recalias=False):
	# 	unions = []
	# 	for flg in flags:
	# 		tid = flg["tid"]
	# 		assignment = tkstr(flg["assignment"])
	# 		boolean = tkstr(flg["boolean"])
	# 		alias = tkstr(flg["alias"])
	# 		flag = tkstr(tid)
	# 		ismulti = tkstr(flg["multi"])
	# 		union = flg["union"] != -1
	# 		values = flg["values"]
	# 		kind = tokens[tid]["kind"]

	# 		if alias and not recalias:
	# 			processflags(gid, chain, [flg], queue_flags, recalias=True)

	# 		# Skip union logic on recursion.
	# 		if not recalias and kind != "tkKYW" and not recunion:
	# 			if union:
	# 				unions.append(flg)
	# 				continue
	# 			elif unions:
	# 				for uflg in unions:
	# 					uflg["values"] = values
	# 					processflags(gid, chain, [uflg], queue_flags, recunion=True)
	# 				unions.clear()

	# 		if recalias:
	# 			oContexts[chain][f"{{{flag.strip('-')}|{alias}}}"] = 1
	# 			flag = "-" + alias

	# 		if kind == "tkKYW":
	# 			if values and flag != "exclude":
	# 				if len(values[0]) == 1:
	# 					value = re.sub(re_space, "", tkstr(values[0][0]))
	# 					if flag == "context": value = value[1:-1]
	# 				else:
	# 					value = get_cmdstr(values[0][1] + 1, values[0][2])

	# 				__locals__[f"o{flag.capitalize()}s"][chain][value] = 1

	# 			continue

	# 		# Flag with values: build each flag + value.
	# 		if values:
	# 			# Baseflag: add multi-flag indicator?
	# 			# Add base flag to Set (adds '--flag=' or '--flag=*').
	# 			queue_flags[f"{flag}={'*' if ismulti else ''}"] = 1
	# 			mflag = f"{flag}={'' if ismulti else '*'}"
	# 			if mflag in queue_flags: del queue_flags[mflag]

	# 			for value in values:
	# 				if len(value) == 1: # Single
	# 					queue_flags[flag + assignment + tkstr(value[0])] = 1

	# 				else: # Command-string
	# 					cmdstr = get_cmdstr(value[1] + 1, value[2])
	# 					queue_flags[flag + assignment + cmdstr] = 1

	# 		else:
	# 			if not ismulti:
	# 				if boolean: queue_flags[flag + "?"] = 1
	# 				elif assignment: queue_flags[flag + "="] = 1
	# 				else: queue_flags[flag] = 1
	# 			else:
	# 				queue_flags[flag + "=*"] = 1
	# 				queue_flags[flag + "="] = 1

	# def populate_keywords(chain):
	# 	for kdict in oKeywords:
	# 		if chain not in kdict: kdict[chain] = OrderedDict()

	# def populate_chain_flags(gid, chain, container):
	# 	if chain not in excludes:
	# 		processflags(gid, chain, ubflags, container)

	# 	if chain not in oSets:
	# 		oSets[chain] = container
	# 	else:
	# 		oSets[chain].update(container)

	# def build_kwstr(kwtype, container):
	# 	output = []
	# 	chains = mapsort([c for c in container if container[c]], asort, aobj)
	# 	cl = len(chains) - 1
	# 	tstr = "{} {} {}"
	# 	for i, chain in enumerate(chains):
	# 		values = list(container[chain])
	# 		value = (values[-1] if kwtype != "context"
	# 			else "\"" + ";".join(values) + "\"")
	# 		output.append(tstr.format(rm_fcmd(chain), kwtype, value))
	# 		if i < cl: output.append("\n")

	# 	return "\n\n" + "".join(output) if output else ""

	# def make_chains(ccids):
	# 	slots = []
	# 	chains = []
	# 	groups = []
	# 	grouping = False

	# 	for cid in ccids:
	# 		if cid == -1: grouping = not grouping

	# 		if not grouping and cid != -1:
	# 			slots.append(tkstr(cid))
	# 		elif grouping:
	# 			if cid == -1:
	# 				slots.append('?')
	# 				groups.append([])
	# 			else: groups[-1].append(tkstr(cid))

	# 	tstr = ".".join(slots)

	# 	for group in groups:
	# 		if not chains:
	# 			for command in group:
	# 				chains.append(tstr.replace('?', command, 1))
	# 		else:
	# 			tmp_cmds = []
	# 			for chain in chains:
	# 				for command in group:
	# 					tmp_cmds.append(chain.replace('?', command))
	# 			chains = tmp_cmds

	# 	if not groups: chains.append(tstr)

	# 	return chains

	# # Start building acmap contents. -------------------------------------------

	# for i, group in enumerate(cchains):
	# 	for ccids in group:
	# 		for chain in make_chains(ccids):
	# 			if chain == "*": continue

	# 			container = {}
	# 			populate_keywords(chain)
	# 			processflags(i, chain, flags.get(i, []), container)
	# 			populate_chain_flags(i, chain, container)

	# 			# Create missing parent chains.
	# 			commands = re.split(r'(?<!\\)\.', chain)
	# 			commands.pop() # Remove last command (already made).
	# 			for _ in range(len(commands) - 1, -1, -1):
	# 				rchain = ".".join(commands) # Remainder chain.

	# 				populate_keywords(rchain)
	# 				if rchain not in oSets:
	# 					populate_chain_flags(i, rchain, {})

	# 				commands.pop() # Remove last command.

	# defaults = build_kwstr("default", oDefaults)
	# filedirs = build_kwstr("filedir", oFiledirs)
	# contexts = build_kwstr("context", oContexts)

	# # Populate settings object.
	# for setting in settings:
	# 	name = tkstr(setting[0])[1:]
	# 	if name == "test": oTests.append(re.sub(re_space_cl, ";", tkstr(setting[2])))
	# 	else: oSettings[name] = tkstr(setting[2]) if len(setting) > 1 else ""

	# # Build settings contents.
	# settings_count = len(oSettings)
	# settings_count -= 1
	# for setting in oSettings:
	# 	config += f"@{setting} = {oSettings[setting]}"
	# 	if settings_count: config += "\n"
	# 	settings_count -= 1

	# placehold = "placehold" in oSettings and oSettings["placehold"] == "true"
	# for key in oSets:
	# 	flags = "|".join(mapsort(list(oSets[key].keys()), fsort, fobj))
	# 	if not flags: flags = "--"

	# 	# Note: Placehold long flag sets to reduce the file's chars.
	# 	# When flag set is needed its placeholder file can be read.
	# 	if placehold and len(flags) >= 1:
	# 		if flags not in omd5Hashes:
	# 			# [https://stackoverflow.com/a/65613163]
	# 			md5hash = hashlib.md5(flags.encode()).hexdigest()[26:]
	# 			oPlaceholders[md5hash] = flags
	# 			omd5Hashes[flags] = md5hash
	# 			flags = "--p#" + md5hash
	# 		else: flags = "--p#" + omd5Hashes[flags]

	# 	row = f"{rm_fcmd(key)} {flags}"

	# 	# Remove multiple ' --' command chains. Shouldn't be the
	# 	# case but happens when multiple main commands are used.
	# 	if row == " --" and not has_root: has_root = True
	# 	elif row == " --" and has_root: continue

	# 	acdef_lines.append(row)

	# # If contents exist, add newline after header.
	# sheader = re.sub(r"\n$", "", header)
	# acdef_contents = "\n".join(mapsort(acdef_lines, asort, aobj))
	# acdef = header + acdef_contents if acdef_contents else sheader
	# config = header + config if config else sheader

	# tests_tstr = "#!/bin/bash\n\n{}tests=(\n{}\n)"
	# tests = tests_tstr.format(header, "\n".join(oTests)) if oTests else ""

	# return (
	# 	acdef,
	# 	config,
	# 	defaults,
	# 	filedirs,
	# 	contexts,
	# 	"", # formatted
	# 	oPlaceholders,
	# 	tests
	# )

end
