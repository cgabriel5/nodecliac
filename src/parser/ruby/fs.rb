#!/usr/bin/env ruby

# Get file path information (i.e. file name and directory path).
#
# @param  {string} p - The complete file path.
# @return {object} - Object containing file path components.
def info(p)
	fileinfo = {
		"name": "",
		"dirname": "",
		"ext": "",
		"path": ""
	}

	def splitfile(p)
		# [https://stackoverflow.com/a/7576792]
		# [https://apidock.com/ruby/v2_5_5/File/split/class]
		head, tail = File.split(p)
		# [https://stackoverflow.com/a/8082521]
		ext = File.extname(tail)
		name = File.basename(tail, ext)
		return head, name, ext
	end

	(head, name, ext) = splitfile(p)

	fileinfo[:dirname] = head
	fileinfo[:path] = p

	if ext
		fileinfo[:name] = name + ext
		fileinfo[:ext] = ext[1..-1]
	else
		path_parts = p.split(File::SEPARATOR)
		name = path_parts[-1]
		name_parts = name.split('.')
		if !name_parts.empty?
			fileinfo[:name] = name
			fileinfo[:ext] = name_parts[-1]
		end
	end

	return fileinfo
end
