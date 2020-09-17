#!/bin/bash

# [Bug:sink] Don't use `--gc:arc` -> [https://github.com/nim-lang/Nim/issues/15238]
# [https://github.com/juancarlospaco/webgui/blob/master/src/webgui.nim.cfg]

nim compile \
--forceBuild:on \
-d:release \
-d:danger \
--tlsEmulation:off \
--exceptions:quirky \
--panics:on \
--passL:"-s" \
--passC:"-flto -ffast-math -march=native -mtune=native -fsingle-precision-constant" \
-d:noSignalHandler \
main.nim
