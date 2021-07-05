#!/usr/bin/env ruby

# [https://stackoverflow.com/a/171011]
# [https://stackoverflow.com/a/55169109]
def platform()
	if RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/
		return "windows"
	end

	if RUBY_PLATFORM =~ /darwin/
		return "darwin"
	end

	return "linux"
end

# Builtin variables.
def builtins(cmdname)
	return {
		"HOME": Dir.home,
		"OS": platform(),
		"COMMAND": cmdname,
		"PATH": "~/.nodecliac/registry/" + cmdname
	}
end
