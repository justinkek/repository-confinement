#!/usr/bin/env bash

# A setting is written with a literal ~, the way a person writes it, so the
# tildes quoted below are meant to reach the policy unexpanded.
# shellcheck disable=SC2088

. "$(dirname "$0")/built.sh"

pass=0
fail=0

assert_silent() {
  local label="$1" out="$2"
  if [ -z "$out" ]; then
    printf "  OK  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  KO  %s — expected silence, got '%s'\n" "$label" "$out"
    fail=$((fail + 1))
  fi
}

assert_starts() {
  local label="$1" want="$2" out="$3"
  case "$out" in
    "$want"*) printf "  OK  %s\n" "$label"; pass=$((pass + 1)) ;;
    *) printf "  KO  %s — expected '%s …', got '%s'\n" "$label" "$want" "$out"
       fail=$((fail + 1)) ;;
  esac
}

scratch="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$scratch"; [ -z "${BUILT_ROOT-}" ] || rm -rf "$BUILT_ROOT"' EXIT

export HOME="$scratch/home"
unset REPOSITORY_CONFINEMENT_HOME
mkdir -p "$HOME/.claude" "$HOME/.claude-work" "$HOME/elsewhere" "$HOME/state/agent"

. "$BUILT_HOOKS/lib/confinement-policy-lib.sh"

REPO="$scratch/repository"
SIBLING="$scratch/sibling"
git init --quiet "$REPO"
git -C "$REPO" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m first
git -C "$REPO" worktree add --quiet "$SIBLING" 2>/dev/null
printf 'x\n' > "$REPO/README.md"

decide() { confinement_decision "$@"; }

session="$scratch/tmp/claude-501/-Users-someone-repo/1111-2222"
export REPOSITORY_CONFINEMENT_SCRATCHPAD_PATHS="$scratch/tmp/claude-*/scratchpad:$scratch/tmp/claude-*/tasks"
export REPOSITORY_CONFINEMENT_PASTED_IMAGE_PATHS="$scratch/tmp/claude-*"

printf "Test group: inside the repository is never the policy's business\n"

assert_silent "read a repository file" "$(decide read "$REPO/README.md" "$REPO" Read)"
assert_silent "write a repository file" "$(decide write "$REPO/README.md" "$REPO" Write)"
assert_silent "a relative path from the repository" "$(decide write "src/new.sh" "$REPO" Write)"
assert_silent "outside any repository, nothing is decided" \
  "$(decide write "$HOME/elsewhere/file.txt" "$HOME/elsewhere" Write)"

printf "\nTest group: the client's own directories outside the repository\n"

assert_silent "read a scratchpad file" "$(decide read "$session/scratchpad/notes.txt" "$REPO" Read)"
assert_silent "write a scratchpad file" "$(decide write "$session/scratchpad/notes.txt" "$REPO" Write)"
assert_silent "read a background task's output" "$(decide read "$session/tasks/bo6jhz4kz.output" "$REPO" Read)"
assert_silent "read the tasks directory itself" "$(decide read "$session/tasks" "$REPO" Read)"
assert_silent "read an image pasted into chat" "$(decide read "$scratch/tmp/claude-501/paste.png" "$REPO" Read)"
assert_starts "read some other temp file" "ask" "$(decide read "$scratch/tmp/claude-501/elsewhere/notes.txt" "$REPO" Read)"
assert_starts "write an image where pastes land" "deny" "$(decide write "$scratch/tmp/claude-501/paste.png" "$REPO" Write)"

printf "\nTest group: state directories are named by a setting, and hold none by default\n"

assert_starts "write a state directory nobody named" "deny" "$(decide write "$HOME/state/agent/cache.json" "$REPO" Write)"
assert_silent "write one the setting names with ~" \
  "$(REPOSITORY_CONFINEMENT_STATE_PATHS="~/state/agent" decide write "$HOME/state/agent/cache.json" "$REPO" Write)"
assert_silent "read one the setting names with \$HOME" \
  "$(REPOSITORY_CONFINEMENT_STATE_PATHS="\$HOME/state/agent" decide read "$HOME/state/agent/cache.json" "$REPO" Read)"
assert_starts "a directory beside it is not named by it" "deny" \
  "$(REPOSITORY_CONFINEMENT_STATE_PATHS="~/state/agent" decide write "$HOME/state/agent-other/x" "$REPO" Write)"

printf "\nTest group: config directories are read without asking and never written\n"

assert_silent "read ~/.claude" "$(decide read "$HOME/.claude/settings.json" "$REPO" Read)"
assert_silent "read a ~/.claude-* directory" "$(decide read "$HOME/.claude-work/settings.json" "$REPO" Read)"
assert_silent "read one written with a ~" "$(decide read "~/.claude/settings.json" "$REPO" Read)"
assert_starts "write ~/.claude" "deny" "$(decide write "$HOME/.claude/settings.json" "$REPO" Write)"
assert_starts "read a directory the setting does not name" "ask" "$(decide read "$HOME/.agents/rules.md" "$REPO" Read)"
assert_silent "read one it does name" \
  "$(REPOSITORY_CONFINEMENT_CONFIG_PATHS="~/.agents" decide read "$HOME/.agents/rules.md" "$REPO" Read)"

ln -s "$HOME/elsewhere" "$HOME/.claude-linked"
assert_silent "read through a symlinked config directory" \
  "$(decide read "$HOME/.claude-linked/file.md" "$REPO" Read)"
assert_starts "write through it" "deny" "$(decide write "$HOME/.claude-linked/file.md" "$REPO" Write)"

printf "\nTest group: the repository's other worktrees\n"

assert_silent "read a sibling worktree" "$(decide read "$SIBLING/README.md" "$REPO" Read)"
assert_starts "write a sibling worktree" "deny" "$(decide write "$SIBLING/README.md" "$REPO" Write)"
assert_starts "write the main checkout from a worktree" "deny" "$(decide write "$REPO/README.md" "$SIBLING" Write)"
assert_silent "write a sibling when the scope is the repository" \
  "$(REPOSITORY_CONFINEMENT_WRITE_SCOPE=repository decide write "$SIBLING/README.md" "$REPO" Write)"
assert_starts "and still nothing outside it" "deny" \
  "$(REPOSITORY_CONFINEMENT_WRITE_SCOPE=repository decide write "$HOME/elsewhere/x" "$REPO" Write)"
assert_starts "a scope the setting does not take falls back to the worktree" "deny" \
  "$(REPOSITORY_CONFINEMENT_WRITE_SCOPE=everywhere decide write "$SIBLING/README.md" "$REPO" Write)"

printf "\nTest group: everything else outside the repository still gates\n"

assert_starts "read elsewhere" "ask" "$(decide read "$HOME/elsewhere/file.txt" "$REPO" Read)"
assert_starts "write elsewhere" "deny" "$(decide write "$HOME/elsewhere/file.txt" "$REPO" Write)"
assert_starts "a path climbing out of the repository" "deny" "$(decide write "$REPO/../elsewhere.txt" "$REPO" Write)"

reason="$(decide write "$HOME/elsewhere/file.txt" "$REPO" Write)"
case "$reason" in
  *"$REPO"*"$HOME/elsewhere/file.txt"*) printf "  OK  the deny names the worktree and the target\n"; pass=$((pass + 1)) ;;
  *) printf "  KO  the deny names the worktree and the target — got '%s'\n" "$reason"; fail=$((fail + 1)) ;;
esac

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
