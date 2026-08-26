class Msgbrowse < Formula
  desc "Browse, search, and export iMessage, Signal, and WhatsApp conversations"
  homepage "https://gitea.stump.rocks/stump.wtf/msgbrowse"
  # Served from the canonical Gitea release assets, not the GitHub mirror —
  # the mirror lags (and has broken entirely in the past), while these
  # release-download URLs are stable and public.
  url "https://gitea.stump.rocks/stump.wtf/msgbrowse/releases/download/v0.7.0/msgbrowse-v0.7.0-source.tar.gz"
  sha256 "15e7248e2857ba690f4f85a26908cc66cabd0ecee60ee727b09f3ac4d6332d3c"
  license "MIT"
  head "https://gitea.stump.rocks/stump.wtf/msgbrowse.git", branch: "main"

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
