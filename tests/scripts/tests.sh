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

# [test-suite: alacritty]
"alacritty --hold --class; *--class=*"
"alacritty --hold --class= ; command\\:+"
"alacritty --hold --class ; flag\\:--class=+"
"alacritty --hold --title= ; command\\:+"
"alacritty --hold --title ; flag\\:--title=+"
"alacritty --hold --t= ; command\\:+"
"alacritty --hold --t ; flag\\:--t=+"
"alacritty --hold --; *--version*"

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
"nodecliac bin -; flag\\:-+"
"nodecliac bin --; flag\\:--+"

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

# [test-suite: nim, Single letter sub-command tests]
"nim c; *cc*" #
"nim c ; *@(nim)*" # 
"nim c --; *--hint...*" #
"nim c --include; *--include=*" #
"nim c --include=; *flag\\\\:--include=+@(nim)*" #

# [test-suite: nimble]
"nimble install ; *a*"
"nimble uninstall ; *@*"
"nimble path ; *regex*"

# [test-suite: op (1password)]
"op ; *get*"
"op get template ; *Social\\ Security\\ Number*"
"op get template Social\\; *Social\\ Security\\ Number*"
"op get template Social\\ ; *Social\\ Security\\ Number*"
"op get template Log; *Login*"
"op get template Login; *Login*"
"op get template \"; *\"Secure Note\"*"
"op get template \"Wireless ; *\"Wireless Router\"*"
"op get template \"Wireless Router\"; *\"Wireless Router\"*"
"op get template \"Wireless RAMDON; command\\:\"Wireless RAMDON+"
"op get template \"Wireless RAMDON\"; command\\:\"Wireless RAMDON\"+"
"op get template '; *'Secure Note'*"
"op get template 'Wireless ; *'Wireless Router'*"
# 
"op list items --category; *--category=*"
"op list items --category=; *Social\\ Security\\ Number*"
"op list items --category=Social\\; *Social\\ Security\\ Number*"
"op list items --category=Social\\ ; *Social\\ Security\\ Number*"
"op list items --category=Log; *Login*"
"op list items --category=Login; *Login*"
"op list items --category=\"; *\"Secure Note\"*"
"op list items --category=\"Wireless ; *\"Wireless Router\"*"
"op list items --category=\"Wireless Router\"; *\"Wireless Router\"*"
"op list items --category=\"Wireless RAMDON; flag\\\\;quoted\\\\;noescape\\\\:--category=\"Wireless RAMDON+"
"op list items --category=\"Wireless RAMDON\"; flag\\\\;quoted\\\\;noescape\\\\:--category=\"Wireless RAMDON\"+"
"op list items --category='; *'Secure Note'*"
"op list items --category='Wireless ; *'Wireless Router'*"
# 
"op list items --category; *--category=*"
"op list items --category ; *Social\\ Security\\ Number*"
"op list items --category Social\\; *Social\\ Security\\ Number*"
"op list items --category Social\\ ; *Social\\ Security\\ Number*"
"op list items --category Log; *Login*"
"op list items --category Login; *Login*"
"op list items --category \"; *\"Secure Note\"*"
"op list items --category \"Wireless ; *\"Wireless Router\"*"
"op list items --category \"Wireless Router\"; *\"Wireless Router\"*"
"op list items --category \"Wireless RAMDON; flag\\\\;quoted\\\\;noescape\\\\:--category=\"Wireless RAMDON+"
"op list items --category \"Wireless RAMDON\"; flag\\\\;quoted\\\\;noescape\\\\:--category=\"Wireless RAMDON\"+"
"op list items --category '; *'Secure Note'*"
"op list items --category 'Wireless ; *'Wireless Router'*"
# 
"op list items --categories; *--categories=*"
"op list items --categories ; *Social\\ Security\\ Number*"
"op list items --categories Social\\; *Social\\ Security\\ Number*"
"op list items --categories Social\\ ; *Social\\ Security\\ Number*"
"op list items --categories Log; *Login*"
"op list items --categories Login; *Login*"
"op list items --categories \"; *\"Secure Note\"*"
"op list items --categories \"Wireless ; *\"Wireless Router\"*"
"op list items --categories \"Wireless Router\"; *\"Wireless Router\"*"
"op list items --categories \"Wireless RAMDON; flag\\\\;quoted\\\\;noescape\\\\:--categories=\"Wireless RAMDON+"
"op list items --categories \"Wireless RAMDON\"; flag\\\\;quoted\\\\;noescape\\\\:--categories=\"Wireless RAMDON\"+"
"op list items --categories '; *'Secure Note'*"
"op list items --categories 'Wireless ; *'Wireless Router'*"
"op list items --categories=Outdoor\ License,; *License,Login*"
"op list items --categories=Outdoor\ License,Login; *License,Login*"
"op list items --categories=\"Outdoor License,; *\"Outdoor License,Login\"*"
"op list items --categories=\"Outdoor License,Login; *\"Outdoor License,Login\"*"
)
