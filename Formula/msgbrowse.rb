class Msgbrowse < Formula
  # Release Assets Are Served From The GitHub Mirror
  #
  # gitea.stump.rocks resolves to an RFC1918 address — public in DNS, routable
  # only from the LAN. Serving the tap from Gitea release-download URLs made
  # `brew install` hang for anyone off the network, and made the tap-bump step
  # impossible to run from a GitHub-hosted runner: it timed out at curl exit 28
  # on every tag from v0.6.0 on, so the automated bump never once succeeded and
  # every version in this file's history was pasted in by hand.
  #
  # The GitHub release is public and is where the darwin .app is actually built,
  # so it is the only copy every consumer can fetch. The source tarball is a
  # deterministic `git archive` published as a release asset rather than
  # GitHub's on-the-fly /archive/refs/tags endpoint, whose bytes have shifted
  # under projects before and would invalidate this sha256.
  #
  # @joestump 08/28/2026 - Repointed url/homepage/head at the GitHub mirror and
  # bumped to v0.8.0. This reverses the earlier "canonical Gitea assets" choice:
  # the canonical-host rule still governs where code, issues and PRs live, but a
  # tap is consumed by machines that are not on the LAN.
  #
  # @joestump 08/30/2026 - Bumped to v0.8.1.
  desc "Browse, search, and export iMessage, Signal, and WhatsApp conversations"
  homepage "https://stump-wtf.github.io/msgbrowse/"
  url "https://github.com/stump-wtf/msgbrowse/releases/download/v0.8.1/msgbrowse-v0.8.1-source.tar.gz"
  sha256 "44836d76d70be2417b5253e1cd5ef49794ab912e4a0ae556a6494f4fbf76b0e0"
  license "MIT"
  head "https://github.com/stump-wtf/msgbrowse.git", branch: "main"

  depends_on "go" => :build

  def install
    # Version/Commit/BuildDate are injected into internal/cli by the upstream
    # Makefile. Reproduced here, minus Commit/BuildDate: a release tarball has
    # no git metadata, and baking a timestamp in would make the build
    # non-reproducible.
    ldflags = "-s -w -X github.com/joestump/msgbrowse/internal/cli.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/msgbrowse"
  end

  test do
    # `version` prints the ldflags-injected version, so this asserts both that
    # the binary runs and that the stamping above actually took effect.
    assert_match "v#{version}", shell_output("#{bin}/msgbrowse version")
  end
end
