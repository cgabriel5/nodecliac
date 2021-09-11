#!/usr/bin/env node

"use strict";

// require "pathname"
// require "paint" // [https://github.com/janlelis/paint]
// require "./parser"
// require "fileutils"
// require "./fs"

// const path = require("path");
// const chalk = require("chalk");
// const flatry = require("flatry");
// const fe = require("file-exists");
// const mkdirp = require("make-dir");
// const de = require("directory-exists");
const toolbox = require("../../utils/toolbox.js");
const { read } = toolbox;

async function main() {
	// module.exports = async (args) => {
	let igc = false;
	let test = false;
	let print_ = true;
	let trace = false;
	let action = "make";
	let indent = "s:4";
	let source = "../python/debug.acmap";
	let formatting = action == "format";

	let fmtinfo = ["\t", 1]; // (char, amount)
	// // Parse/validate indentation.
	// if formatting && indent != ""
	// 	// [https://www.rubyguides.com/2015/06/ruby-regex/]
	// 	if not indent.match(/^(s|t):\d+$/)
	// 		puts "Invalid indentation string."
	// 		exit
	// 	end
	// 	components = indent.split(":", 2)
	// 	components = indent.split(/:/, 2)
	// 	fmtinfo[0] = if components[0] == 's' then ' ' else '\t' end
	// 	fmtinfo[1] = components[1].to_i(10)
	// end

	// // Source must be provided.
	// // [https://www.rubyguides.com/2019/02/ruby-booleans/]
	// if source.empty?
	// 	puts "Please provide a " + Paint["--source", :bold] + " path."
	// 	exit
	// end

	// // Breakdown path.
	// fi = info(source)
	// extension = fi[:ext]
	// cmdname = fi[:name].sub(/\.#{extension}$/, "") // [TODO] `replace`
	// dirname = fi[:dirname]
	// if not (Pathname.new dirname).absolute?
	// 	dirname = Pathname.new(dirname).realpath.to_s
	// end

	// // Make path absolute.
	// if not (Pathname.new source).absolute?
	// 	// [https://stackoverflow.com/a/1906886]
	// 	begin // [https://blog.bearer.sh/handle-ruby-exceptions/]
	// 		source = Pathname.new(source).realpath.to_s
	// 		// [https://airbrake.io/blog/ruby-exception-handling/systemcallerror]
	// 		rescue Errno::ENOENT => e // [TODO] Handle this better.
	// 	end
	// end

	// // [https://stackoverflow.com/a/10115630]
	// if File.directory?(source)
	// 	puts "Directory provided but .acmap file path needed."
	// 	exit
	// end
	// if not File.file?(source)
	// 	puts "Path " + Paint[source, :bold] + " doesn't exist."
	// 	exit
	// end

	// // [https://www.rubyguides.com/2015/05/working-with-files-ruby/]
	// f = File.open(source)
	// res = f.read
	// f.close

	let res = await read(source);
	let cmdname = "debug";
	let parser = require("./parser.js")(action, res, cmdname, source, fmtinfo, trace, igc, test);

	// cmdname = "debug" // Placeholder.
	// acdef, config, keywords, filedirs, contexts, formatted, placeholders, tests =
	// parser(action, res, cmdname, source, fmtinfo, trace, igc, test)

	// testname = cmdname + ".tests.sh"
	// savename = cmdname + ".acdef"
	// saveconfigname = "." + cmdname + ".config.acdef"

	// // Only save files to disk when not testing.
	// if !test
	// 	if formatting
	// 		// [https://stackoverflow.com/a/19337403]
	// 		File.write(source, formatted)
	// 	else
	// 		testpath = File.join(dirname, testname)
	// 		commandpath = File.join(dirname, savename)
	// 		commandconfigpath = File.join(dirname, saveconfigname)
	// 		placeholderspaths = File.join(dirname, "placeholders")

	// 		// [https://stackoverflow.com/a/11464127]
	// 		FileUtils.mkdir_p(dirname)
	// 		File.write(commandpath, acdef + keywords + filedirs + contexts)
	// 		File.write(commandconfigpath, config)

	// 		// Save test file if tests were provided.
	// 		if !tests.empty?
	// 			File.write(testpath, tests)
	// 			// [https://makandracards.com/makandra/1388-change-file-permissions-with-ruby]
	// 			File.chmod(0o775, testpath)  // 775 permissions
	// 		end

	// 		// Create placeholder files if object is populated.
	// 		if placeholders
	// 			FileUtils.mkdir_p(placeholderspaths)

	// 			placeholders.each { |key,value|
	// 				p = placeholderspaths + File::SEPARATOR + key
	// 				File.write(p, value)
	// 			}
	// 		end
	// 	end
	// end

	// if print_
	// 	if !formatting
	// 		if !acdef.empty?
	// 			puts("[" + Paint[cmdname + ".acdef", :bold] + "]\n\n")
	// 			puts(acdef + keywords + filedirs + contexts)
	// 			if config.empty?
	// 				puts("")
	// 			end
	// 		end
	// 		if !config.empty?
	// 			msg = "\n[" + Paint["." + cmdname + ".config.acdef", :bold] + "]\n\n"
	// 			puts(msg)
	// 			puts(config)
	// 		end
	// 	else
	// 		puts(formatted)
	// 	end
	// end

	// // Test (--test) purposes.
	// if test
	// 	if !formatting
	// 		if !acdef.empty?
	// 			puts(acdef + keywords + filedirs + contexts)
	// 			if config.empty?
	// 				puts("")
	// 			end
	// 		end
	// 		if !config.empty?
	// 			if !acdef.empty?
	// 				puts("")
	// 			end
	// 			puts(config)
	// 		end
	// 	else
	// 		puts(formatted)
	// 	end
	// end
}

main();
