#!/bin/bash

# DON'T EDIT FILE —— GENERATED: Wed Jul 15 2020 23:17:54 (1594880274)

tests=(
"nodecliac ; *uninstall*"
"nodecliac --engine=2 --; *--version *"
"nodecliac format; *format*"
"nodecliac format positional_arg; !*format*"
"nodecliac format positional_arg ; !*format*"
"nodecliac print --command=; *subl*"
"nodecliac print --command; *--command=*"
"nodecliac print --command=node; *nodecliac *"
"nodecliac print --command node; *nodecliac *"
"nodecliac print --command ; *nodecliac *"
"nodecliac print --comm; *--command*"
"nodecliac make --sou| path/to/file; *source*"
"nodecliac make --source install --print --so; !*--source*"
'nodecliac format --source command.acmap --print --indent "s:2" --; *strip-comments*'
)