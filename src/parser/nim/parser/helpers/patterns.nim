from re import re

let r_quote* = re("[\"']") # Quotes.
let r_letter* = re("[a-zA-Z]") # Letters.
let r_space* = re("[ \t]") # Whitespace.
let r_nl* = re("\\r?\\n") # Newlines.
let r_sol_char* = re("[-@a-zA-Z)\\]$;#]") # Start-of-line characters.
