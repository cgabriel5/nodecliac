#!/bin/bash

# DON'T EDIT FILE —— GENERATED: Tue Jul 28 2020 13:52:30 (1595969550)

tests=(
"nodecliac ;*uninstall*"
"nodecliac --engine=2 --;*--version *"
"nodecliac format;*format*"
"nodecliac format positional_arg;!*format*"
"nodecliac format positional_arg ;!*format*"
"nodecliac print --command=;*subl*"
"nodecliac print --command;*--command=*"
"nodecliac print --command=node;*nodecliac *"
"nodecliac print --command node;*nodecliac *"
"nodecliac print --command ;*nodecliac *"
"nodecliac print --comm;*--command*"
"nodecliac make --sou| path/to/file;*source*"
"nodecliac make --source install --print --so;!*--source*"
'nodecliac format --source command.acmap --print --indent "s:2" --;*strip-comments*'
'nodecliac NONEXISTANTCOMMAND ;*format*'
'nodecliac NONEXISTANTCOMMAND for;*format*'
'nodecliac . ;*format*'
'nodecliac . -;1:*--version*'
)