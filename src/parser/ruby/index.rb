#!/usr/bin/env ruby

# [https://www.rubyguides.com/2018/12/ruby-argv/]

require "pathname"
require "paint" # [https://github.com/janlelis/paint]
require "./parser"
require "./fs"

def main
	igc = false
	test = false
	print = false
	trace = false
	action = "format"
	indent = "s:4"
	source = "../python/debug.acmap"
	formatting = action == "format"

	fmtinfo = ['\t', 1] # (char, amount)
	# Parse/validate indentation.
	if formatting && indent != ""
		# [https://www.rubyguides.com/2015/06/ruby-regex/]
		if not indent.match(/^(s|t):\d+$/)
			puts "Invalid indentation string."
			exit
		end
		components = indent.split(":", 2)
		components = indent.split(/:/, 2)
		fmtinfo[0] = if components[0] == 's' then ' ' else '\t' end
		fmtinfo[1] = components[1].to_i(10)
	end

	# Source must be provided.
	# [https://www.rubyguides.com/2019/02/ruby-booleans/]
	if source.empty?
		puts "Please provide a " + Paint["--source", :bold] + " path."
		exit
	end

	# Breakdown path.
	fi = info(source)
	extension = fi[:ext]
	cmdname = fi[:name].sub(/\.#{extension}$/, "") # [TODO] `replace`
	dirname = fi[:dirname]
	if not (Pathname.new dirname).absolute?
		dirname = Pathname.new(dirname).realpath.to_s
	end

	# Make path absolute.
	if not (Pathname.new source).absolute?
		# [https://stackoverflow.com/a/1906886]
		source = Pathname.new(source).realpath.to_s
	end

	# [https://stackoverflow.com/a/10115630]
	if File.directory?(source)
		puts "Directory provided but .acmap file path needed."
		exit
	end
	if not File.file?(source)
		puts "Path " + Paint[source, :bold] + " doesn't exist."
		exit
	end

	# [https://www.rubyguides.com/2015/05/working-with-files-ruby/]
	f = File.open(source)
	res = f.read
	f.close

	cmdname = "debug" # Placeholder.
	parser(action, res, cmdname, source, fmtinfo, trace, igc, test)
end

main
