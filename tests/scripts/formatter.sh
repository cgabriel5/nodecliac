#!/bin/bash

# Script checks whether `nodecliac format` returns same output. If so
# the formatter is working properly.

# --------------------------------------------------------------------------VARS

ACTION="format"
OUTPUT_DIR="formatted"
HEADER="Formatter"
EXTENSION="acmap"

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# -----------------------------------------------------------------------IMPORTS

. "$__filepath/common.sh" # Import functions/variables.

# -----------------------------------------------------------------RUN-TEST-FILE

. "$__filepath/clitools.sh" # Run test.
