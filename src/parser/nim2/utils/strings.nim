# Checks whether a string is empty it not.
#
# Note: This modifies s itself, it does not return a copy.
#
# @param  {string} s - The string to check.
# @return {bool} - Whether string is empty or not.
proc isset*(s: string): bool =
    runnableExamples:
        doAssert isset("") == false
        doAssert isset("string") == true

    s.len > 0

# Removes x amount of characters from start of string.
#
# Note: This modifies s itself, it does not return a copy.
#
# @param  {string} s - The string to modify.
# @param  {number} s - Amount of characters to remove.
# @return {void} - Nothing is returned.
proc lchop*(s: var string, count: Natural) =
    runnableExamples:
        var s: string

        s = "abc1234567890"
        s.lchop(3)
        doAssert s == "1234567890"

        s = "abc1234567890"
        s.lchop(0)
        doAssert s == "abc1234567890"

    let l = s.len

    if count > l:
        # [https://nim-lang.org/docs/system.html#Exception]
        raise newException(
            RangeDefect,
            "Trying to remove " & $count & " char(s) but string length is: " & $l
        )

    for i in countup(count, s.high):
        let `char` = s[i]
        s[i - count] = `char`
    s.setLen(l - count)

# Removes x amount of characters from end of string.
#
# Note: This modifies s itself, it does not return a copy.
#
# @param  {string} s - The string to modify.
# @param  {number} s - Amount of characters to remove.
# @return {void} - Nothing is returned.
proc rchop*(s: var string, count: Natural) =
    runnableExamples:
        var s: string

        s = "1234567890abc"
        s.rchop(3)
        doAssert s == "1234567890"

        s = "1234567890abc"
        s.rchop(0)
        doAssert s == "1234567890abc"

    let l = s.len

    if count > l:
        # [https://nim-lang.org/docs/system.html#Exception]
        raise newException(
            RangeDefect,
            "Trying to remove " & $count & " char(s) but string length is: " & $l
        )

    s.setLen(l - count)

# Adds x amount of characters to start of string.
#
# Note: This modifies s itself, it does not return a copy.
#
# @param  {string} s - The string to modify.
# @param  {number} s - Amount of characters to add.
# @return {void} - Nothing is returned.
proc prepend*(s: var string, sub: string = "") =
    runnableExamples:
        var s: string

        s = "1234567890"
        s.prepend("abc")
        doAssert s == "abc1234567890"

        s = "1234567890"
        s.prepend("")
        doAssert s == "1234567890"

    let l = s.len
    let ll = sub.len
    s.setLen(l + ll)
    for i in countdown(l - 1, 0): s[i + ll] = s[i]
    for i, c in sub: s[i] = c

# Adds x amount of characters to start of string.
#
# Note: This modifies s itself, it does not return a copy.
#
# @param  {string} s - The string to modify.
# @param  {number} s - Amount of characters to add.
# @return {void} - Nothing is returned.
proc append*(s: var string, sub: string = "") =
    runnableExamples:
        var s: string

        s = "1234567890"
        s.append("abc")
        doAssert s == "1234567890abc"

        s = "1234567890"
        s.append("")
        doAssert s == "1234567890"

    let l = s.len
    let ll = sub.len
    s.setLen(l + ll)
    for i, c in sub: s[i + l] = c

# Creates a capped ref string.
#
# @param  {number} cap - Size string should be.
# @return {ref string} - The created ref string.
#
# @{resource} [https://forum.nim-lang.org/t/707#3931]
# @{resource} [https://forum.nim-lang.org/t/735#4170]
# @{resource} [https://forum.nim-lang.org/t/4182]
# @{resource} [https://gist.github.com/Varriount/c3ba438533497bc636da]
proc newStringRefOfCap*(cap: Natural): ref string =
    runnableExamples:
        var str = newStringRefOfCap(3)
        str[].add("1")
        str[].addInt(2)
        str[].add("3")
        doAssert str[] == "123"
        doAssert str[].len == 3

        # Without `newStringRefOfCap` the following
        # can be used to create a ref string.
        var tmp: ref string = new(string)
        tmp[] = newStringOfCap(3)
        tmp[].add("1")
        tmp[].addInt(2)
        tmp[].add("3")
        doAssert tmp[].len == str[].len
        doAssert tmp[] == str[]

    new(result)
    result[] = newStringOfCap(cap)

# Creates a ref string.
#
# @param  {string} s - The string source.
# @return {ref string} - The created ref string.
#
# @{resource} [https://forum.nim-lang.org/t/707#3931]
# @{resource} [https://forum.nim-lang.org/t/735#4170]
# @{resource} [https://forum.nim-lang.org/t/4182]
# @{resource} [https://gist.github.com/Varriount/c3ba438533497bc636da]
proc newStringRef*(s = ""): ref string =
    runnableExamples:
        var a = newStringRef("abc")
        doAssert a[] == "abc"
        a[][1] = ($2)[0] # Change second character in string.
        doAssert a[] == "a2c"

        let b = newStringRef("123")
        doAssert b[] == "123"
        b[][1] = ($2)[0]
        doAssert b[] != "a2c" # String is immutable due to `let` declaration.

    new(result)
    result[] = s
