# asdf demo

Structurally identical to the **mise** demo — asdf is mise's predecessor and
shares the same install-dir layout (`~/.asdf/installs/<plugin>/<version>/bin/`).
Trust property is the same: versioned but not input-addressed.

The notable difference: asdf doesn't support disabling shims the way mise does.
This demo bypasses asdf's shim layer by reading `.tool-versions`, locating the
real install directories, and prepending them to PATH directly. `agent-sbx prepare`
then resolves binaries against those paths.

## Prerequisites

- macOS
- [asdf](https://asdf-vm.com) installed
- python and nodejs plugins added: `asdf plugin add python && asdf plugin add nodejs`

## Run

```bash
./activate.sh           # installs tools, sets up PATH, runs agent-sbx prepare
../../agent-sbx/agent-sbx elevate   # kernel enforcement
```

## See also

For everything else, refer to the [mise demo](../mise/README.md) — the
behavior under the sandbox is identical.
