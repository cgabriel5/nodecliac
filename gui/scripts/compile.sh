#!/bin/bash

# [https://github.com/juancarlospaco/webgui/blob/master/src/webgui.nim.cfg]

nim compile \
--forceBuild:on \
-d:release \
-d:danger \
--gc:arc \
--tlsEmulation:off \
--exceptions:quirky \
--panics:on \
--passL:"-s" \
--passC:"-flto -ffast-math -march=native -mtune=native -fsingle-precision-constant" \
-d:noSignalHandler \
main.nim

# -d:nimDebugDlOpen \
