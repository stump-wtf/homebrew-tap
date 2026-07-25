# stump.wtf Homebrew tap

Homebrew formulae for the [stump.wtf](https://github.com/stump-wtf) tools.

```bash
brew tap stump-wtf/tap
brew install msgbrowse
```

## Formulae

| Formula | What it is |
|---|---|
| `msgbrowse` | Browse, search, and export iMessage and Signal conversations |
| `reduit` | Cache Proton Mail locally with semantic search and a stdio MCP server |
| `harness` | Supervise long-running agent processes from a client-server TUI |

All three are Go, built from source at install time (`depends_on "go" => :build`)
rather than shipped as bottles. None require cgo.

> `reduit` is at v0.1.0 and is **not fully tested** — treat it as a preview.

## Where this lives

Origin is Gitea at
[stump.wtf/homebrew-tap](https://gitea.stump.rocks/stump.wtf/homebrew-tap);
GitHub is a mirror. The GitHub side is what makes the `brew tap stump-wtf/tap`
shorthand work — Homebrew resolves that to `github.com/stump-wtf/homebrew-tap`.

## Updating a formula for a new release

1. Tag and release upstream (`vX.Y.Z`).
2. Get the checksum of the release tarball:
   ```bash
   curl -sL https://github.com/stump-wtf/<repo>/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
   ```
3. Bump `url` and `sha256` in `Formula/<name>.rb`.
4. `brew audit --strict --online <name>` before pushing.

The `-X .../Version=` ldflag in each formula must keep matching the upstream
Makefile's `LDFLAGS`; the paths differ per project (`internal/cli.Version` for
msgbrowse and reduit, `internal/buildinfo.Version` for harness). Each formula's
`test do` block asserts the stamp actually took effect, so a drifted path fails
`brew test` rather than silently shipping an unversioned binary.
