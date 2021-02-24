#!/bin/bash

# [https://nim-lang.org/docs/nimc.html]

# [Bug:sink] Don't use `--gc:arc` -> [https://github.com/nim-lang/Nim/issues/15238]
# [https://github.com/juancarlospaco/webgui/blob/master/src/webgui.nim.cfg]

# --app:gui [https://stackoverflow.com/a/36346102]

# [https://nim-lang.org/docs/gc.html]
# --gc:orc \
# -d:useMalloc \
nim compile \
--gc:arc \
--app:gui \
-d:ssl \
-d:release \
-d:danger \
--tlsEmulation:off \
--passL:"-s" \
--threads:on \
--verbosity:0 \
--opt:speed \
--checks:off \
--assertions:off \
--hints:on \
--showAllMismatches:off \
--forceBuild:off \
--stackTrace:off \
--lineTrace:off \
--deadCodeElim:on \
--linedir:off \
--profiler:off \
--panics:off \
-d:nimDebugDlOpen \
-d:noSignalHandler \
main.nim
# --debuginfo \



# # For faster compilation drop the flags:
# -d:nimDebugDlOpen \
# --panics:on \
# --hints:off \
# --debugger:native \
# --passC:"-flto -ffast-math -march=native -mtune=native -fsingle-precision-constant" \
# -d:noSignalHandler \
