# Working in this repository

(audience: agents)

One hook reaches a session: `hooks/confine-to-repository.sh`, which runs before
every tool call. It reads the payload, works out which files the call touches
and whether it reads or writes them, and asks the policy about each one.

The policy is `hooks/confinement-policy-lib.sh`. It takes an operation, a path,
a working directory and a label, and answers `deny`, `ask` or nothing. It never
sees JSON or a tool name, and that is what lets one policy serve every client.
A client's payload shape belongs in the hook, and a decision about a path
belongs in the policy.

Nothing a client or a person names is written into the policy. A directory it
allows outside the repository is a setting in `plugin.json`, and the policy
reads it through `setting_value`.

This plugin is built by the ai-plugin-sdk. `./build` calls it: the SDK is a
checkout at `../ai-plugin-sdk`, or wherever `AI_PLUGIN_SDK` names.

## Before you push

    tests/run-tests                                 this plugin's own behaviour
    ../ai-plugin-sdk/tests/run-tests "$PWD"         the SDK's, against this plugin

CI runs both.

## Every merge is a release

An install names no ref, so what main points at is what a person gets. Every
merge raises the version, in `plugin.json` and in `package.json`, which a test
holds together. CI fails a pull request whose version matches its base.

## Where a change belongs

| Change | File |
| --- | --- |
| what is allowed, asked or denied for a path | `hooks/confinement-policy-lib.sh`, with a case in `tests/test-the-policy.sh` |
| which tools are read, and how a client names a file | `hooks/confine-to-repository.sh`, with a case in `tests/test-the-hook.sh` |
| a directory list, or its default | `plugin.json` under `settings` |
| which clients it is built for | `plugin.json` under `clients` |
| the prose around the install table | `install-page/` |
| what an install copies | nothing by hand - `distributions/` is built by `./build` |

`distributions/`, `INSTALL.md` and `COMPATIBILITY.md` are generated and
committed, because an install fetches files from the repository. Run `./build`
after changing anything it copies. The SDK's suite rebuilds and fails on any
difference.

## Across plugins

Another plugin may allow the same tool call this one denies. Which answer wins
is the SDK's rule, not this plugin's: a deny outranks an allow. See
`lib/permission.sh` in the SDK.

This plugin knows nothing of the repository it was extracted from, and a test
refuses any word that would say otherwise.
