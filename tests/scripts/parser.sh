#!/bin/bash

# Script checks whether `nodecliac make` returns same output. If so
# the parser is working properly.

# --------------------------------------------------------------------------VARS

ACTION="parse"
OUTPUT_DIR="parsers"
HEADER="Parser"
EXTENSION="acdef"

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# -----------------------------------------------------------------------IMPORTS

. "$__filepath/common.sh" # Import functions/variables.

# -----------------------------------------------------------------RUN-TEST-FILE

. "$__filepath/clitools.sh" # Run test.
