#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

slow_app=$(rlocation "with_cfg_examples/opt_filegroup/slow_app${EXE_SUFFIX}")

if [ "$(uname)" == "Darwin" ]; then
  slow_app_realpath=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$slow_app")
else
  slow_app_realpath=$(realpath "$slow_app")
fi

if [[ "$slow_app_realpath" != *"-opt/bin/opt_filegroup/slow_app"* ]]; then
  echo "ERROR: slow_app wasn't built in opt mode"
  exit 1
fi

"$slow_app"
