#!/bin/bash

last="$NODECLIAC_LAST"
pkgs=~/.nodecliac/registry/npm/db/pkgs
# [https://stackoverflow.com/a/13913220]
[[ "${#last}" -ge 3 ]] && echo -e "$(LC_ALL=C grep "^$last" "$pkgs")"
