# stump.wtf Homebrew tap

Homebrew formulae and casks for the [stump.wtf](https://github.com/stump-wtf)
tools.

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

## Casks

| Cask | What it is |
|---|---|
| `msgbrowse-desktop` | The msgbrowse macOS `.app` — native window, bundled exporters |

```bash
brew install --cask msgbrowse-desktop
```

The formula and the cask are **different artifacts of the same project**, and
installing one does not get you the other:

- `brew install msgbrowse` builds the **CLI** from source (`cmd/msgbrowse`).
- `brew install --cask msgbrowse-desktop` downloads the prebuilt universal
  **`.app`** from the upstream GitHub Release and drops it in `/Applications`.

They coexist fine. Homebrew forbids a formula from installing an `.app` into
`/Applications`, which is why this is a cask and why it carries a separate token
rather than shadowing the formula name.

### Why the cask strips quarantine

The upstream `.app` is **ad-hoc signed** (`codesign -s -`), not notarized — a
Developer ID is not yet provisioned. Homebrew quarantines cask downloads by
default, and Gatekeeper then blocks not only the app but the exporter binaries
it spawns as subprocesses (a bundled Python runtime, `sigexport`, `wtsexporter`,
`imessage-exporter`, `syncthing`). The cask's `postflight` therefore runs
`xattr -dr com.apple.quarantine` so a plain install yields a working app.

Drop that block once upstream releases are notarized.

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

## Updating a cask for a new release

1. Tag upstream; wait for the release workflow to attach the artifact.
2. Checksum the **release asset**, not a source tarball:
   ```bash
   curl -sL https://github.com/stump-wtf/msgbrowse/releases/download/vX.Y.Z/msgbrowse-desktop_darwin_universal.zip | shasum -a 256
   ```
3. Bump `version` and `sha256` in `Casks/<name>.rb` (`url` interpolates
   `#{version}`).
4. `brew style --cask <name>` and `brew audit --cask --online <name>`.

`brew audit` reports **"vX.Y.Z is a GitHub pre-release"** for msgbrowse and will
keep doing so until notarization lands and `desktop.yml` flips `prerelease:` to
false. That one finding is expected; anything else is not.

> **`depends_on macos:` is a trap.** `brew style` autocorrects the string form
> (`">= :big_sur"`) to the bare symbol (`:big_sur`) — and for *old* symbols the
> bare form is disabled at runtime, so the autocorrected cask raises
> "Calling `depends_on macos: :high_sierra` is disabled!" on every `brew` command
> that touches it. Use a symbol Homebrew still supports; verify with
> `brew info --cask <name>`, which should print a `Required: macOS >= NN` line.
