# ADR-0001: Release-triggered formula bumps run as a poll in the tap

Status: proposed
Date: 2026-10-20
Deciders: pending maintainer review (issue #40 left the mechanism to the implementer)
References: stump.wtf/homebrew-tap#40, stump.wtf/homebrew-tap#1, `.gitea/workflows/bump.yml`, `scripts/tap-bump.rb`

## Context

Six formulae (and one cask) in this tap pin upstream GitHub release
tarballs by `url` + `sha256`. `renovate.json` bumps dependencies inside
the formulae, but nothing bumps the pin when an upstream project —
harness, msgbrowse, reduit, switchboard, cairn, agent-trace — publishes a
release. Twice in one week a published release sat unreferenced in
`Formula/harness.rb` until someone noticed by hand and filed a report.

Issue #40 proposed a release-triggered bump (`repository_dispatch` from
each upstream's release workflow, or a cross-repo PAT/GitHub App
workflow) and explicitly left the mechanism open, including "a generic
reusable workflow" as an acceptable shape. The thread made no decision.
Constraints that shape the choice:

- The tap lives on Gitea; releases are published on the GitHub mirror
  (`github.com/stump-wtf/*`), and formula urls point there because the
  Gitea host is LAN-only.
- Six upstream repos, six different release workflows, in a different
  org's repo each — anything wired upstream is six coordinated changes
  to repos this tap does not own the release flow of.
- The bump must open reviewable PRs gated by the existing `ci.yml`
  (`brew audit --strict --online` re-downloads the artifact, so a wrong
  sha256 fails CI, not a user's machine).
- Runners are the Linux `homebrew/brew` container with git and curl but
  no node, so node-based actions are unusable (documented in `ci.yml`).

## Options considered

1. **`repository_dispatch` from each upstream release workflow.** The
   issue's first choice. Fastest signal, zero polling. Rejected as the
   sole mechanism: it is six changes in six other repos, every new tap
   entry must remember to wire one, and a missed wiring fails silently —
   the exact failure mode this ticket exists to end.
2. **Cross-repo PAT or GitHub App workflow running in the upstream org.**
   One workflow serves all upstreams, but it needs a standing credential
   that can write PRs into this repo from outside it, plus a place to
   host the cross-repo runner. Credential plus infrastructure for a
   problem this repo can solve from inside itself.
3. **Poll from this repo (chosen).** One scheduled workflow, one script,
   in the repo that owns the problem. A release is picked up within the
   poll interval; a missed bump is a bug in one file, not an unwired
   upstream repo.

## Decision

Implement the loop in this repo, and keep the dispatch door open:

- `.gitea/workflows/bump.yml` runs on a schedule (twice daily), on
  `workflow_dispatch` (with `dry_run`, `formula` and `version` inputs),
  and on `repository_dispatch` type `upstream-release`. Upstream release
  workflows may add a dispatch step later for immediate pickup; nothing
  requires them to, and a repo that never wires one still gets bumped by
  the schedule. This is option 1 as an accelerator on option 3, not a
  dependency.
- `scripts/tap-bump.rb` does the work: it derives each project's upstream
  from the formula's own GitHub url, resolves the newest non-draft
  release (prereleases only when nothing stable exists — msgbrowse marks
  every release prerelease), downloads the new artifact exactly once to
  compute `sha256`, and rewrites only the `url`, `sha256` and cask
  `version` lines. Comments, including the formulae's bump history, are
  never touched. A file already at or above the target is never rewritten
  and never downloaded, so a steady-state run costs one API call per
  project and no transfers.
- One branch and one PR per project (`bump/<name>-<tag>`, titled like the
  manual bumps: `toil(<name>): bump tap to <tag>`), so a bad artifact
  blocks one project, not the batch. An existing branch means a PR is
  already pending and the project is skipped, keeping a stale PR visible
  instead of stacking duplicates.
- Scope ships all six projects at once (the issue's "initial scope"
  question): the logic is uniform because the upstream is derived from
  each url, and the two url shapes (`archive/refs/tags` and
  `releases/download/<tag>/<asset>`) plus the cask `#{version}` template
  are all implemented and fixture-tested now. Harness-first would double
  the number of "does it fire" questions.

## Consequences

- A release is reflected in at most ~12 hours instead of within minutes.
  Acceptable: before this, the bound was "until a human notices".
- The workflow pushes and opens PRs with the run's `GITHUB_TOKEN`. That
  requires the repo's Actions token permissions to allow `contents:
  write` and `pull-requests: write`; if the instance defaults to
  read-only, the push step fails loudly and the fix is a repo setting.
- GitHub unauthenticated API rate limits apply (60 requests/hour);
  a full sweep is 6-12 requests twice a day. `GITHUB_TOKEN`, when the
  runner exports one, raises that ceiling.
- Drift is reconciled: if a formula moves and its cask does not (the
  #1-era failure), the next run bumps the lagging file too, because the
  target comes from upstream, not from the formula.
- The loop is verifiable without waiting for a release: `make test-bump`
  runs fixture tests for every rewrite rule offline, and
  `workflow_dispatch` with `dry_run=true` prints the live plan without
  pushing anything. Pinning `version` proves the full loop against a
  past tag.
- If a release ships an artifact whose name fits no recognisable version
  pattern of the previous release, the run reports the fetch as an error
  and fails the workflow run rather than guessing an url — visible and
  red, not silent.

## Revisit when

- An upstream release workflow wants immediate pickup: add the dispatch
  step there; this repo needs no change.
- The tap grows beyond projects whose releases GitHub's
  `releases`/`tags` API can enumerate: `target_tag` gains a strategy per
  repo instead of one API assumption.
