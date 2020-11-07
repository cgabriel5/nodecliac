#!/bin/bash

# [Bug:sink] Don't use `--gc:arc` -> [https://github.com/nim-lang/Nim/issues/15238]
# [https://github.com/juancarlospaco/webgui/blob/master/src/webgui.nim.cfg]

# --app:gui [https://stackoverflow.com/a/36346102]

nim compile \
--app:gui \
-d:nimDebugDlOpen \
--forceBuild:on \
-d:ssl \
-d:release \
-d:danger \
--tlsEmulation:off \
--debugger:off \
--debuginfo:off \
--panics:on \
--passL:"-s" \
--threads:on \
--verbosity:0 \
--passC:"-flto -ffast-math -march=native -mtune=native -fsingle-precision-constant" \
-d:noSignalHandler \
main.nim
