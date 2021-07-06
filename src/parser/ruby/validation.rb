#!/usr/bin/env ruby

require "./issue"

def vsetting(s)
	token = s[:lexerdata][:tokens][s[:tid]]
	start = token[:start]
	end_ = token[:end]
	line = token[:line]
	index = token[:start]

	settings = ["compopt", "filedir", "disable", "placehold", "test"]

	setting = s[:text][start + 1 .. end_]

	# Warn if setting is not a supported setting.
	if !settings.include?(setting)
		message = "Unknown setting: '" + setting + "'"

		if !s[:warnings].key?(line)
			s[:warnings][line] = []
		end
		s[:warnings][line].append([s[:filename], line, index - s[:lexerdata][:linestarts][line], message])
		s[:warn_lines].add(line)
	end
end

def isdigit(s)
	return false if s.empty?
	if s =~ /\A\p{Digit}+\z/
		return true
	end
	return false
end

def vvariable(s)
	token = s[:lexerdata][:tokens][s[:tid]]
	start = token[:start]
	end_ = token[:end]
	line = token[:line]
	index = token[:start]

	# Error when variable starts with a number.
	if isdigit(s[:text][start + 1])
		message = "Unexpected: '" + s[:text][start + 1] + "'"
		message += "\n\033[1;36mInfo\033[0m: Variable cannot begin with a number."
		issue_error(s[:filename], line, index - s[:lexerdata][:linestarts][line], message)
	end
end

def vstring(s)
	token = s[:lexerdata][:tokens][s[:tid]]
	start = token[:start]
	end_ = token[:end]
	line = token[:lines][0]
	index = token[:start]

	# Warn when string is empty.
	# [TODO] Warn if string content is just whitespace?
	if end_ - start == 1
		message = "Empty string"

		if !s[:warnings].key?(line)
			s[:warnings][line] = []
		end
		s[:warnings][line].append([s[:filename], line, index - s[:lexerdata][:linestarts][line], message])
		s[:warn_lines].add(line)
	end

	# Error if string is unclosed.
	if token[:lines][1] == -1
		message = "Unclosed string"
		issue_error(s[:filename], line, index - s[:lexerdata][:linestarts][line], message)
	end
end

def vsetting_aval(s)
	token = s[:lexerdata][:tokens][s[:tid]]
	start = token[:start]
	end_ = token[:end]
	line = token[:line]
	index = token[:start]

	values = ["true", "false"]

	value = s[:text][start .. end_]

	# Warn if values is not a supported values.
	if !values.include?(value)
		message = "Invalid setting value: '" + value + "'"
		issue_error(s[:filename], line, index - s[:lexerdata][:linestarts][line], message)
	end
end
