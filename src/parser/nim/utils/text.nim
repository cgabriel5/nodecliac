import std/[strutils, re]

# Remove all comments from Bash/Perl files.
#
# @param  {string} contents - The file contents.
# @return {string} - The file contents with comments removed.
proc strip_comments*(contents: string): string =
    result = contents.multiReplace([
            # Inject acmap.
            # .replace(/# \[\[__acmap__\]\]/, acmap)
            # Remove comments/empty lines but leave sha-bang comment.
            (re("^\\s*#(?!!).*?$", {reMultiLine}), ""),
            (re("\\s{1,}#\\s{1,}.+$", {reMultiLine}), ""),
            # .replace(/(^\s*#.*?$|\s{1,}#\s{1,}.*$)/gm, "")
            (re("(\r\n\t|\n|\r\t){1,}", {reMultiLine}), "\n")
        ]).strip()

# Remove trailing slash from path string.
#
# @param  {string} s - The path.
# @return {string} - The string with trailing slash removed.
proc strip_trailing_slash*(s: string = ""): string =
    result = if s.endsWith("/"): s[0 .. ^2] else: s
