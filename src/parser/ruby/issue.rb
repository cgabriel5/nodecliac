#!/usr/bin/env ruby

def issue_hint(filename, line, col, message)
	itype = "\033[32;1mHint:\033[0m"
	fileinfo = "\033[1m" + filename + "(" + line.to_s + ", " + col.to_s + ")\033[0m"

	puts fileinfo + " " + itype + " " + message
end

def issue_warn(filename, line, col, message)
	itype = "\033[33;1mWarning:\033[0m"
	fileinfo = "\033[1m" + filename + "(" + line.to_s + ", " + col.to_s + ")\033[0m"

	puts fileinfo + " " + itype + " " + message
end

def issue_error(filename, line, col, message)
	itype = "\033[31;1mError:\033[0m"
	fileinfo = "\033[1m" + filename + "(" + line.to_s + ", " + col.to_s + ")\033[0m"

	puts fileinfo + " " + itype + " " + message
	exit
end
