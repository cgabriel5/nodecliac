import ../helpers/[tree_add, types, charsets, forward, rollback]

# ------------------------------------------------------------ Parsing Breakdown
# # Comment body.
# ^-Symbol.
#  ^-Comment-Chars (All chars until newline).
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc p_comment*(S: State, inline = false) =
    let text = S.text
    var N = node(nkComment, S)
    N.comment.start = S.i

    if inline: N.inline = inline

    let l = S.l; var c: char
    while S.i < l:
        c = text[S.i]

        if c in C_NL:
            rollback(S)
            N.stop = S.i
            break # Stop at nl char.

        N.comment.stop = S.i
        N.comment.value &= $c

        forward(S)

    add(S, N)
