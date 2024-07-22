#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

function check_runfile() {
  real_path=$(rlocation "$1" || { >&2 echo "$1 not found"; exit 1; })
  basename=$(basename "$1")
  want="name:$basename,rule_setting:rule,with_cfg_setting:with_cfg"
  if [[ $1 != bazel_tools/* && "$(cat "$real_path")" != "$want" ]]; then
    echo "Runfile content mismatch in $1: got '$(cat "$real_path")', want '$want'"
    exit 1
  fi
}

if [ "$#" -ne 11 ]; then
  echo "Unexpected number of arguments: $#, want 11"
  exit 1
fi
for arg in "$@"; do
  check_runfile "$arg"
done