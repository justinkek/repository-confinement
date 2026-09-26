## Which version is installed

    claude plugin list

ZCode lists it in Settings, Marketplace instead, and any session can be asked:
every skill says the version it was built from.

## Where the confinement runs

The confinement is a hook that runs before a tool call. A client that runs no
hooks is not confined, so this plugin is not built for one. Codex writes files
through patches, so it is the patch's own file headers that are checked there;
a file written through a shell command is not checked on any client.

## Pointing it at your own directories

The defaults name Claude Code's own temporary directories and `~/.claude`.
Anything else an agent keeps outside the repository is named in a setting:

    REPOSITORY_CONFINEMENT_STATE_PATHS = ~/.local/state/my-agent
    REPOSITORY_CONFINEMENT_CONFIG_PATHS = ~/.claude:~/.claude-*:~/.agents

The settings skill writes them, and an environment variable of the same name
overrides the file.

## What a removal leaves behind

Nothing: the uninstall steps remove the directory the plugin keeps to itself,
`~/.repository-confinement`, along with the plugin.
