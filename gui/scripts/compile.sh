#!/bin/bash

# [https://nim-lang.org/docs/nimc.html]

# [Bug:sink] Don't use `--gc:arc` -> [https://github.com/nim-lang/Nim/issues/15238]
# [https://github.com/juancarlospaco/webgui/blob/master/src/webgui.nim.cfg]

# --app:gui [https://stackoverflow.com/a/36346102]

# [https://nim-lang.org/docs/gc.html]
# --gc:orc \
# [https://forum.nim-lang.org/t/6216#38531]
# -d:useMalloc \
nim compile \
--passL:"-no-pie" \
--gc:arc \
--app:gui \
-d:useMalloc \
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

# StackTrace:
# [https://nim-lang.org/docs/estp.html]
# [https://stackoverflow.com/questions/36577570/how-to-benchmark-few-lines-of-code-in-nim]

# Nim unittest
# [https://nim-lang.org/docs/unittest.html]
# [https://github.com/technicallyagd/unpack/blob/master/tests/theTest.nim]

# # For faster compilation drop the flags:
# -d:nimDebugDlOpen \
# --panics:on \
# --hints:off \
# --debugger:native \
# --passC:"-flto -ffast-math -march=native -mtune=native -fsingle-precision-constant" \
# -d:noSignalHandler \
