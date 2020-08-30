#!/bin/bash

tests=(
# [test-suite: testapp]
'testapp --test="" ; *format*'
'testapp --test "" ; *format*'
'testapp --test="" for; *format*'
'testapp --test "" for; *format*'
'testapp --help "" for; !*format*'
"testapp --help for; *format*"
"testapp --version for; !*format*"

# [test-suite: nodecliac]
"nodecliac ; *uninstall*"
# "nodecliac --nonexistantflag ;"
# "nodecliac --engine=; *1*"
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
'nodecliac NONEXISTANTCOMMAND ; !*format*'
'nodecliac NONEXISTANTCOMMAND for; !*format*'
'nodecliac . ; !*format*'
'nodecliac . -; 1:*--version*'

# [test-suite: prettier-cli-watcher]
"prettier-cli-watcher ; command\\:+"
"prettier-cli-watcher --watcher=; *hound*"
"prettier-cli-watcher --watcher= --; !*--watcher*"
"prettier-cli-watcher --watcher=hou; *hound *"
"prettier-cli-watcher --watcher=hound; *hound *"
"prettier-cli-watcher --watcher=hound --; !*--watcher*"
"prettier-cli-watcher --watcher=hound --w; flag\\:--w+"
"prettier-cli-watcher --watcher=hound --watcher ; !*chokidar*"
"prettier-cli-watcher --watcher=hound --watcher=; !*chokidar*"
"prettier-cli-watcher --watcher=hound --; flag\\:--+\n--config \n--dir \n--dry \n--dtime \n--ignore \n--notify \n--quiet \n--setup \n--version\n"
"prettier-cli-watcher --watcher hou; *hound *"
"prettier-cli-watcher --watcher hound; *hound *"
"prettier-cli-watcher --watcher hound --; !*--watcher*"
"prettier-cli-watcher --watcher hound --w; flag\\:--w+"
"prettier-cli-watcher --watcher hound --watcher ; !*chokidar*"
"prettier-cli-watcher --watcher hound --watcher; flag\\:--watcher+"
"prettier-cli-watcher --watcher=hound --watcher=; !*chokidar*"
"prettier-cli-watcher --watcher=hound --watcher; !*chokidar*"
"prettier-cli-watcher --watcher=hound --watcher chok; !*chokidar*"

# [test-suite: yarn]
# "yarn remov ; command\\:+" # `remov` command does not exit.
"yarn remove ch; *chalk*"
"yarn ; *config*"
"yarn run; !*nocache*"
"yarn run ; *pretty*"
"yarn remove ; *prettier*"
"yarn remove prettier ; *-*"
# Completing a non existing argument should not append a trailing space.
"yarn remove nonexistantarg; command\\\\;nocache\\\\:nonexistantarg+"
"yarn add prettier-cli-watcher@* --; *--dev*"

# [test-suite: nim]
"nim compile --; *--hint...*" # Test flag collapsing.
"nim compile --app=con; *console*"
"nim compile --app:con; *console*"

# [test-suite: nimble]
"nimble install ; *a*"
"nimble uninstall ; *@*"
"nimble path ; *regex*"
)
