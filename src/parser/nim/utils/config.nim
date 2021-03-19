import std/[os, strformat, tables, strutils]

let hdir = os.getEnv("HOME")
let root = fmt"{hdir}/.nodecliac"
let config = fmt"{root}/.config";
const lookup = { "status": 0, "cache": 1, "debug": 2, "singletons": 3 }.toTable

# Config settings:
# [1] status (disabled)
# [2] cache
# [3] debug
# [4] singletons

# Create config file if it's empty or does not exist yet.
#
# @return {undefined} - Nothing is returned.
proc initconfig*() =
    if not fileExists(config) or getFileSize(config) == 0:
        writeFile(config, "1101")

# Returns config setting.
#
# @param  {string} setting - The setting name.
# @return {undefined} - Nothing is returned.
proc getsetting*(setting: string): string =
    let `cstring` = readFile(config)
    return $(`cstring`[lookup[setting]])

# Sets the config setting.
#
# @param  {string} setting - The setting name.
# @param  {string} value - The setting's value.
# @return {undefined} - Nothing is returned.
proc setsetting*(setting, value: string) =
    let i = lookup[setting]
    var `cstring` = readFile(config)
    `cstring` = `cstring`.substr(0, i) & value & `cstring`.substr(i + 1)
    writeFile(config, `cstring`.strip())
