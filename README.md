# repository-confinement

(audience: humans)

Keep an agent's writes inside the worktree it was started in.

An agent started in one checkout has no business editing another. This plugin
checks every file a tool call names before the call runs:

| Where the file is | Read | Write |
| --- | --- | --- |
| inside the current worktree | allowed | allowed |
| the client's own temporary directories | allowed | allowed |
| a state directory you named | allowed | allowed |
| a config directory you named | allowed | denied |
| another worktree of the same repository | allowed | denied |
| an image pasted into chat | allowed | denied |
| anywhere else | asks you | denied |

Outside a git repository it decides nothing, and the client's own permission
rules apply as they would without it.

## Settings

| Setting | Default | What it holds |
| --- | --- | --- |
| `WRITE_SCOPE` | `worktree` | `repository` lets a write land in any worktree of the same repository |
| `SCRATCHPAD_PATHS` | Claude Code's `scratchpad` and `tasks` directories under `/tmp/claude-*` | the client's own temporary directories |
| `STATE_PATHS` | none | directories an agent keeps state in, outside the repository |
| `CONFIG_PATHS` | `~/.claude:~/.claude-*` | agent configuration, read without asking and never written |
| `PASTED_IMAGE_PATHS` | `/tmp/claude-*` | where a pasted image lands |

Each one is written with the `REPOSITORY_CONFINEMENT_` prefix. A path list is
separated by colons, may start with `~`, and may hold a glob such as
`~/.claude-*`. A config directory that is a symlink is matched by the path as
written as well as by where it leads.

## Installing

[INSTALL.md](INSTALL.md) has a page per client, and
[COMPATIBILITY.md](COMPATIBILITY.md) says what runs where.
