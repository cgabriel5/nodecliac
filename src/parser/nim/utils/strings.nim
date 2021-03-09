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
