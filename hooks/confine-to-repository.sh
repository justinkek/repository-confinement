#!/usr/bin/env bash

input="$(cat)"

. "$(dirname "$0")/lib/confinement-policy-lib.sh"

field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
  else
    printf '%s' "$input" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
  fi
}

emit() {
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg d "$1" --arg r "$2" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' \
      "$1" "$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  fi
}

answer() {
  case "$1" in
    deny\ *) emit deny "${1#deny }" ;;
    ask\ *) emit ask "${1#ask }" ;;
    "") ;;
    *) emit deny "Unexpected policy output. Failing closed." ;;
  esac
}

patched_paths() {
  printf '%s\n' "$1" | sed -n \
    -e 's/^\*\*\* Add File: *//p' \
    -e 's/^\*\*\* Update File: *//p' \
    -e 's/^\*\*\* Delete File: *//p' \
    -e 's/^\*\*\* Move to: *//p' \
    -e 's|^+++ b/||p' \
    | sed 's/[[:space:]]*$//' | grep -v '^/dev/null$'
}

tool="$(field '.tool_name' tool_name)"
cwd="$(field '.cwd' cwd)"
cwd="${cwd:-$PWD}"

case "$tool" in
  Read | Grep | Glob | LS) op="read" ;;
  Edit | MultiEdit | Write | NotebookEdit | apply_patch) op="write" ;;
  *) exit 0 ;;
esac

path="$(field '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path' file_path)"
[ -n "$path" ] || path="$(field '.tool_input.notebook_path' notebook_path)"
[ -n "$path" ] || path="$(field '.tool_input.path' path)"

if [ -n "$path" ]; then
  answer "$(confinement_decision "$op" "$path" "$cwd" "$tool")"
  exit 0
fi

[ "$op" = "write" ] || exit 0

patch="$(field '.tool_input.command // .tool_input.patch // .tool_input.input' command)"
[ -n "$patch" ] || exit 0

paths="$(patched_paths "$patch")"
if [ -z "$paths" ]; then
  emit deny "Could not read which files this patch touches. Failing closed."
  exit 0
fi

strongest=""
while IFS= read -r patched; do
  [ -n "$patched" ] || continue
  decision="$(confinement_decision write "$patched" "$cwd" "$tool")"
  case "$decision" in
    deny\ *) answer "$decision"; exit 0 ;;
    ask\ *) [ -n "$strongest" ] || strongest="$decision" ;;
    "") ;;
    *) answer "$decision"; exit 0 ;;
  esac
done <<< "$paths"

answer "$strongest"
exit 0
