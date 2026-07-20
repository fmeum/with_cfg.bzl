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

# :variant_file is built with --platforms=:transitioned_platform and thus resolves to
# transitioned.txt.
if ! rlocation "with_cfg_examples/platform_filegroup_with_reset/transitioned.txt" >/dev/null; then
  echo "ERROR: transitioned.txt not found in runfiles: the platform transition wasn't applied"
  exit 1
fi

# :variant_file_reset resets --platforms to its original value and thus resolves to original.txt.
if ! rlocation "with_cfg_examples/platform_filegroup_with_reset/original.txt" >/dev/null; then
  echo "ERROR: original.txt not found in runfiles: the original settings weren't restored"
  exit 1
fi
