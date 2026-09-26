---
name: settings
description: Change repository-confinement's settings
---

# repository-confinement settings

Settings are stored in `~/.repository-confinement/settings` with one `key = value` a line.
Blank lines and lines opening with `#` are ignored, and the last assignment of a key is the one that counts.

| Key | Default | What it does, and what to say when setting it |
| --- | --- | --- |
| `REPOSITORY_CONFINEMENT_STOP_NOTE_DIRECTORY` | `~/.repository-confinement/state/notes` | where a turn's notes are written |
| `REPOSITORY_CONFINEMENT_UPDATE_CHECK` | `on` | asks once a day whether a newer version is out |
| `REPOSITORY_CONFINEMENT_UPDATE_CHECK_DAYS` | `1` | days between those asks |
| `REPOSITORY_CONFINEMENT_VERSION_SOURCE` | `https://raw.githubusercontent.com/justinkek/repository-confinement/main/package.json` | where the update check reads the published version from |
| `REPOSITORY_CONFINEMENT_WRITE_SCOPE` | `worktree` | where a write may land: the worktree the session started in, or any worktree of the same repository |
| `REPOSITORY_CONFINEMENT_SCRATCHPAD_PATHS` | `/tmp/claude-*/scratchpad:/tmp/claude-*/tasks:/private/tmp/claude-*/scratchpad:/private/tmp/claude-*/tasks` | the client's own temporary directories, read and written freely, separated by colons |
| `REPOSITORY_CONFINEMENT_STATE_PATHS` | unset | directories outside the repository an agent keeps state in, read and written freely, separated by colons |
| `REPOSITORY_CONFINEMENT_CONFIG_PATHS` | `~/.claude:~/.claude-*` | agent configuration directories, read without asking and never written, separated by colons |
| `REPOSITORY_CONFINEMENT_PASTED_IMAGE_PATHS` | `/tmp/claude-*:/private/tmp/claude-*` | where an image pasted into chat lands, so reading one there does not ask, separated by colons |

`REPOSITORY_CONFINEMENT_HOME` moves the settings file and the state under it together.

A project can hold settings of its own in `.repository-confinement/settings` at its root, in
the same shape. The hooks read it before `~/.repository-confinement/settings`, and an
environment variable before either. Write there when the user wants a value
for everyone working in the project rather than for themselves, and say that
it is a file to commit.

## Before writing anything

Read the steps below. Where they say no hook runs, write no
file: follow them instead, since nothing would read what you wrote.

## How to update settings

Run this once per key, and edit no file yourself:

```
bash "${CLAUDE_PLUGIN_ROOT}/set-setting.sh" <key> <value>
```

It creates the file if it is not there, puts the new value where the old one
was, and leaves the rest of the file as it is, comments included. It writes
nothing and says what the setting takes when the value is one it cannot take,
so pass on what it says rather than trying again.

Where the file already holds a value for the key, say so before running it,
since the hooks read it as the default.

For the project's own file, put `--project <directory>` before the key,
naming the root of the project.

## How to apply settings

The steps below say what reads the file here, and what to do so the session
reads the new copy.

## Inform the user of their settings

Name each key the file sets, and the default above for keys that are unset / empty.

A key another setting has turned off keeps its value and says so in the parenthesis, naming the key and the value that turned it off:

| Key                                        | Value |
| ------------------------------------------ | ----- |
| `REPOSITORY_CONFINEMENT_UPDATE_CHECK` | `off` (set) |
| `REPOSITORY_CONFINEMENT_UPDATE_CHECK_DAYS` | `1` (set - n.a. because `REPOSITORY_CONFINEMENT_UPDATE_CHECK` is set to `off`) |

One pair does this. `REPOSITORY_CONFINEMENT_UPDATE_CHECK = off` asks nothing, so `REPOSITORY_CONFINEMENT_UPDATE_CHECK_DAYS` throttles nothing.

## What not to do

Do not edit what a hook prints to change a value. The hook rewrites it from
whatever is configured, every time it runs.

Do not export a variable in a shell to make a change stick: it lasts as long as
that shell. An environment variable set on a cloud environment is a different
thing, and the steps below say when it is the right one.

## The steps for this install

One install serves several clients. Read the signatures, then follow the
steps under the one that matches.

### Claude Code, on your machine

A plugin directory under `~/.claude/plugins`, and a project directory you can
write to. Everything works, and settings persist.

The hooks read the file every time they run, so a change takes effect at once.
Whatever this session was given at its start was given with the old value, so
run the reload skill to be given it again with the new one.

### ZCode

A plugin cached under `~/.zcode`, and no `~/.claude/plugins`. Everything works
as it does on Claude Code, and settings persist, but the window that installed
it is ZCode's own.

The hooks read the file every time they run, so a change takes effect at once.
Whatever this session was given at its start was given with the old value, so
run the reload skill to be given it again with the new one.

### Claude Cowork

A plugin directory under `~/.claude/plugins`, with `~/.repository-confinement/state`
written this session. Every hook runs, and the container is discarded when the
session ends.

The hooks read the file every time they run, so a change takes effect at once,
and the reload skill prints with the new value.

The file is written inside the session's container, which is discarded when the
session ends, so say the setting lasts as long as this session does.

## Note

Rendered from repository-confinement 0.1.0. Say that version when asked which one is
installed, and say it is the version this file was built from rather than one
read off disk.

Generated by the ai-plugin-sdk build. Edit the plugin's own sources instead.
