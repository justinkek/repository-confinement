#!/usr/bin/env bash

. "$(dirname "$0")/built.sh"

HOOK="$BUILT_HOOKS/confine-to-repository.sh"

pass=0
fail=0

scratch="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$scratch"; [ -z "${BUILT_ROOT-}" ] || rm -rf "$BUILT_ROOT"' EXIT

export HOME="$scratch/home"
unset REPOSITORY_CONFINEMENT_HOME
mkdir -p "$HOME/elsewhere"

REPO="$scratch/repository"
git init --quiet "$REPO"

called() { bash "$HOOK" 2>&1; }

claude() {
  jq -nc --arg t "$1" --arg p "$2" --arg c "$REPO" \
    '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$p},cwd:$c}' | called
}

patched() {
  jq -nc --arg t "$1" --arg p "$2" --arg c "$REPO" \
    '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$p},cwd:$c}' | called
}

decision_of() { printf '%s' "$1" | jq --raw-output '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }

assert_decides() {
  local label="$1" want="$2" out="$3" got
  got="$(decision_of "$out")"
  if [ "$got" = "$want" ] && { [ -n "$want" ] || [ -z "$out" ]; }; then
    printf "  OK  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  KO  %s — expected '%s', got '%s'\n" "$label" "${want:-silence}" "$out"
    fail=$((fail + 1))
  fi
}

printf "Test group: Claude's file tools\n"

assert_decides "Read inside the repository" "" "$(claude Read "$REPO/a.txt")"
assert_decides "Write inside the repository" "" "$(claude Write "$REPO/a.txt")"
assert_decides "Read outside it asks" "ask" "$(claude Read "$HOME/elsewhere/a.txt")"
assert_decides "Write outside it is denied" "deny" "$(claude Write "$HOME/elsewhere/a.txt")"
assert_decides "Edit outside it is denied" "deny" "$(claude Edit "$HOME/elsewhere/a.txt")"
assert_decides "MultiEdit outside it is denied" "deny" "$(claude MultiEdit "$HOME/elsewhere/a.txt")"
assert_decides "Grep reads its path" "ask" \
  "$(jq -nc --arg c "$REPO" --arg p "$HOME/elsewhere" '{tool_name:"Grep",tool_input:{pattern:"x",path:$p},cwd:$c}' | called)"
assert_decides "Grep with no path searches where it stands" "" \
  "$(jq -nc --arg c "$REPO" '{tool_name:"Grep",tool_input:{pattern:"x"},cwd:$c}' | called)"
assert_decides "a notebook edit outside it is denied" "deny" \
  "$(jq -nc --arg c "$REPO" --arg p "$HOME/elsewhere/n.ipynb" '{tool_name:"NotebookEdit",tool_input:{notebook_path:$p},cwd:$c}' | called)"

deny="$(claude Write "$HOME/elsewhere/a.txt")"
printf '%s' "$deny" | jq --exit-status '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null
assert_decides "the answer names the event it is for" "deny" "$deny"

printf "\nTest group: tools it has no say over\n"

assert_decides "Bash" "" \
  "$(jq -nc --arg c "$REPO" '{tool_name:"Bash",tool_input:{command:"cat /etc/hosts"},cwd:$c}' | called)"
assert_decides "a tool from a server with a path of its own" "" \
  "$(jq -nc --arg c "$REPO" '{tool_name:"mcp__drive__read",tool_input:{path:"/etc/hosts"},cwd:$c}' | called)"

printf "\nTest group: Codex's patches\n"

inside="*** Begin Patch
*** Add File: notes.txt
+hello
*** End Patch"
outside="*** Begin Patch
*** Update File: README.md
@@
-a
+b
*** Update File: $HOME/elsewhere/a.txt
@@
-a
+b
*** End Patch"
moved="*** Begin Patch
*** Update File: README.md
*** Move to: ../elsewhere.md
*** End Patch"
unified="--- a/README.md
+++ b/README.md
@@ -1 +1 @@
-a
+b"

assert_decides "a patch inside the repository" "" "$(patched apply_patch "$inside")"
assert_decides "a patch touching one file outside it is denied whole" "deny" "$(patched apply_patch "$outside")"
assert_decides "a patch moving a file out of it is denied" "deny" "$(patched apply_patch "$moved")"
assert_decides "a unified diff inside it" "" "$(patched apply_patch "$unified")"
assert_decides "a patch sent under the Edit name is read the same" "deny" "$(patched Edit "$outside")"
assert_decides "a patch it cannot read is denied" "deny" "$(patched apply_patch "no headers here")"

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
