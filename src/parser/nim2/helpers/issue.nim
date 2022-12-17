import ../utils/[chalk]

# \033: [https://stackoverflow.com/a/10170631]

proc issue_hint*(filename: string, line: int, col: int, message: string) =
    let itype = "Hint:".chalk("green", "bold")
    let fileinfo = (filename & "(" & $line & ", " & $col & ")").chalk("bold")

    echo fileinfo & " " & itype & " " & message

proc issue_warn*(filename: string, line: int, col: int, message: string) =
    let itype = "Warning:".chalk("yellow", "bold")
    let fileinfo = (filename & "(" & $line & ", " & $col & ")").chalk("bold")

    echo fileinfo & " " & itype & " " & message

proc issue_error*(filename: string, line: int, col: int, message: string) =
    let itype = "Error:".chalk("red", "bold")
    let fileinfo = (filename & "(" & $line & ", " & $col & ")").chalk("bold")

    echo fileinfo & " " & itype & " " & message
    quit()
