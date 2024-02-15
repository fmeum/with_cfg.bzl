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

slow_to_run_app=$(rlocation "with_cfg_examples/opt_filegroup_with_reset/slow_to_run_app${EXE_SUFFIX}")
slow_to_build_app=$(rlocation "with_cfg_examples/opt_filegroup_with_reset/slow_to_build_app${EXE_SUFFIX}")

if [ "$(uname)" == "Darwin" ]; then
  slow_to_run_app_realpath=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$slow_to_run_app")
  slow_to_build_app_realpath=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$slow_to_build_app")
else
  slow_to_run_app_realpath=$(realpath "$slow_to_run_app")
  slow_to_build_app_realpath=$(realpath "$slow_to_build_app")
fi

if [[ "$slow_to_run_app_realpath" != *"-opt-ST-"*"/bin/opt_filegroup_with_reset/slow_to_run_app"* ]]; then
  echo "ERROR: slow_to_run_app wasn't built in opt mode: $slow_to_run_app_realpath"
  exit 1
fi

"$slow_to_run_app"

if [[ "$slow_to_build_app_realpath" != *"-fastbuild/bin/opt_filegroup_with_reset/slow_to_build_app"* ]]; then
  echo "ERROR: slow_to_build_app wasn't built in fastbuild mode: $slow_to_build_app_realpath"
  exit 1
fi

"$slow_to_build_app"
