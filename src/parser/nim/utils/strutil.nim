from strutils import find, SkipTable, initSkipTable

# Modified version of Nim's strutils.replace function. This takes an extra
#     parameter to stop replacements after a first replace has been made.
#
# @param  {string} s - The string to use.
# @param  {string} by - The replacement string.
# @param  {boolean} once - Whether to only do a single replacement.
# @return {string} - The modified string.
proc replaceOnce*(s, sub: string, by = "", once = true): string =
    ## Replaces `sub` in `s` by the string `by`.
    ##
    ## See also:
    ## * `find proc<#find,string,string,Natural,int>`_
    ## * `replace proc<#replace,string,char,char>`_ for replacing
    ##   single characters
    ## * `replaceWord proc<#replaceWord,string,string,string>`_
    ## * `multiReplace proc<#multiReplace,string,varargs[]>`_
    result = ""
    let subLen = sub.len
    if subLen == 0:
        result = s
    elif subLen == 1:
        # when the pattern is a single char, we use a faster
        # char-based search that doesn't need a skip table:
        let c = sub[0]
        let last = s.high
        var i = 0
        while true:
            let j = find(s, c, i, last)
            if j < 0: break
            add result, substr(s, i, j - 1)
            add result, by
            i = j + subLen

            if once: break # Stop after first replacement

        # copy the rest:
        add result, substr(s, i)
    else:
        var a {.noinit.}: SkipTable
        initSkipTable(a, sub)
        let last = s.high
        var i = 0
        while true:
            let j = find(a, s, sub, i, last)
            if j < 0: break
            add result, substr(s, i, j - 1)
            add result, by
            i = j + subLen

            if once: break # Stop after first replacement

        # copy the rest:
        add result, substr(s, i)
