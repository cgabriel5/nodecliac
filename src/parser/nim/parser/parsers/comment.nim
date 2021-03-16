import ../helpers/[tree_add, types, charsets, forward, rollback]

# ------------------------------------------------------------ Parsing Breakdown
# # Comment body.
# ^-Symbol.
#  ^-Comment-Chars (All chars until newline).
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc p_comment*(S: State, inline=false) =
    let text = S.text
    var N = node(S, "COMMENT")
    N.comment.start = S.i

    if inline: N.inline = inline

    let l = S.l; var `char`: char
    while S.i < l:
        `char` = text[S.i]

        if `char` in C_NL:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        N.comment.`end` = S.i
        N.comment.value &= $`char`

        forward(S)

    add(S, N)
